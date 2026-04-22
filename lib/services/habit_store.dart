import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:kultivate_new_ver/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local persistence for habits, daily completions, session name, and derived stats.
/// Replaces mock UI data until a backend API exists.
class HabitStore extends ChangeNotifier {
  HabitStore._();
  static final HabitStore instance = HabitStore._();

  static const _kHabits = 'habits_json';
  static const _kCompletions = 'completions_json';
  static const _kDisplayName = 'user_display_name';
  static const _kEmail = 'user_email';
  static const _kBestStreak = 'best_streak';

  final List<Habit> habits = [];
  final Map<String, Set<String>> _completionsByHabit = {};
  String displayName = 'there';
  String? email;
  int bestStreakRecorded = 0;

  bool _loaded = false;
  bool get isLoaded => _loaded;

  static final RegExp _mongoIdRe = RegExp(r'^[a-f0-9]{24}$', caseSensitive: false);

  bool _looksLikeMongoId(String id) => _mongoIdRe.hasMatch(id);

  Map<String, String> _authHeaders(String token) => {
        'content-type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  Uri _habitsUri(String path) => Uri.parse('${AuthService.baseurl}/api/habits$path');

  void _applyRemoteState(Map<String, dynamic> data) {
    final list = data['habits'] as List<dynamic>? ?? [];
    habits
      ..clear()
      ..addAll(
        list.map((e) {
          final m = e as Map<String, dynamic>;
          final rawNotes = m['notes'];
          String? parsedNotes;
          if (rawNotes != null) {
            final s = rawNotes.toString().trim();
            if (s.isNotEmpty) parsedNotes = s;
          }
          return Habit(
            id: '${m['id']}',
            title: '${m['title']}',
            category: '${m['category'] ?? 'focus'}',
            notes: parsedNotes,
            frequency: _normalizeFrequency('${m['frequency'] ?? 'daily'}'),
          );
        }),
      );
    _completionsByHabit.clear();
    final comp = data['completions'] as Map<String, dynamic>? ?? {};
    comp.forEach((hid, days) {
      _completionsByHabit[hid] =
          (days as List<dynamic>).map((e) => e.toString()).toSet();
    });
  }

  Future<void> _syncWithServerIfLoggedIn() async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) return;

    try {
      final res = await http.get(
        _habitsUri('/state'),
        headers: _authHeaders(token),
      );
      if (res.statusCode == 401) {
        await AuthService.saveToken(null);
        return;
      }
      if (res.statusCode != 200) return;

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final remoteList = data['habits'] as List<dynamic>? ?? [];

      if (remoteList.isEmpty && habits.isNotEmpty) {
        final habitPayload = habits
            .map((h) => {
                  'tempId': h.id,
                  'title': h.title,
                  'category': h.category,
                  if (h.notes != null && h.notes!.trim().isNotEmpty) 'notes': h.notes!.trim(),
                  'frequency': _normalizeFrequency(h.frequency),
                })
            .toList();
        final compPayload = <String, dynamic>{};
        _completionsByHabit.forEach((id, set) {
          compPayload[id] = set.toList();
        });
        final boot = await http.post(
          _habitsUri('/bootstrap'),
          headers: _authHeaders(token),
          body: jsonEncode({
            'habits': habitPayload,
            'completions': compPayload,
          }),
        );
        if (boot.statusCode == 201) {
          final merged = jsonDecode(boot.body) as Map<String, dynamic>;
          _applyRemoteState(merged);
          await _persist();
        }
        return;
      }

      _applyRemoteState(data);
      await _persist();
    } catch (e, st) {
      debugPrint('habit sync: $e\n$st');
    }
  }

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    await load();
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    displayName = p.getString(_kDisplayName) ?? displayName;
    email = p.getString(_kEmail);
    bestStreakRecorded = p.getInt(_kBestStreak) ?? 0;

    final habitsRaw = p.getString(_kHabits);
    if (habitsRaw != null && habitsRaw.isNotEmpty) {
      final list = jsonDecode(habitsRaw) as List<dynamic>;
      habits
        ..clear()
        ..addAll(list.map((e) => Habit.fromJson(e as Map<String, dynamic>)));
    }

    final compRaw = p.getString(_kCompletions);
    _completionsByHabit.clear();
    if (compRaw != null && compRaw.isNotEmpty) {
      final map = jsonDecode(compRaw) as Map<String, dynamic>;
      map.forEach((habitId, dates) {
        _completionsByHabit[habitId] = (dates as List<dynamic>).map((e) => e.toString()).toSet();
      });
    }

    await _syncWithServerIfLoggedIn();
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kHabits, jsonEncode(habits.map((h) => h.toJson()).toList()));
    final compMap = <String, dynamic>{};
    _completionsByHabit.forEach((id, set) {
      compMap[id] = set.toList();
    });
    await p.setString(_kCompletions, jsonEncode(compMap));
    await p.setString(_kDisplayName, displayName);
    if (email != null) await p.setString(_kEmail, email!);
    await p.setInt(_kBestStreak, bestStreakRecorded);
  }

  Future<void> setSession({required String displayName, String? email}) async {
    this.displayName = displayName.trim().isEmpty ? 'there' : displayName.trim();
    this.email = email;
    await _persist();
    notifyListeners();
  }

  /// Call after successful sign-up (saves the name users typed).
  Future<void> registerProfile({required String displayName, required String email}) async {
    this.displayName = displayName.trim().isEmpty ? 'there' : displayName.trim();
    this.email = email.trim();
    await _persist();
    notifyListeners();
  }

  /// Call after login: keeps stored name if same account, otherwise uses email prefix.
  Future<void> applyLogin({required String email}) async {
    await load();
    final e = email.trim();
    if (this.email == e) {
      this.email = e;
      await _persist();
      notifyListeners();
      return;
    }
    this.email = e;
    displayName = e.contains('@') ? e.split('@').first : e;
    await _persist();
    notifyListeners();
  }

  double _avgCompletionBetween(int oldestDayOffset, int newestDayOffset) {
    if (habits.isEmpty) return 0;
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    var sum = 0.0;
    var n = 0;
    for (var o = oldestDayOffset; o <= newestDayOffset; o++) {
      final d = today.subtract(Duration(days: o));
      sum += countCompletedOn(d) / habits.length;
      n++;
    }
    return n == 0 ? 0.0 : sum / n;
  }

  /// Recent 7 days vs the 7 days before that (for stats subtitle).
  String trendLabel() {
    if (habits.isEmpty) return 'Add habits to see weekly trends';
    final recent = _avgCompletionBetween(0, 6);
    final prev = _avgCompletionBetween(7, 13);
    if (prev < 0.001 && recent < 0.001) return 'Log a completion to start';
    if (prev < 0.001) return 'Strong start this week';
    final ch = ((recent - prev) / prev * 100).round();
    if (ch >= 0) return '+$ch% vs prior week';
    return '$ch% vs prior week';
  }

  double get avgDailyCompletionLast7 {
    if (habits.isEmpty) return 0;
    final v = last7DayIntensity();
    return v.reduce((a, b) => a + b) / v.length;
  }

  String insightNudgeBody() {
    if (habits.isEmpty) {
      return 'Tap + for the activity wheel, or Custom to add a habit by hand (name, notes, repeat, category). Completions power stats, calendar, and your score.';
    }
    final left = habits.where((h) => !isCompletedOn(h.id, DateTime.now())).length;
    if (left == 0) {
      return 'All habits checked off today. Come back tomorrow or add another habit.';
    }
    return 'Finish $left more habit${left == 1 ? '' : 's'} today to max out your daily completion.';
  }

  String _dateKey(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  bool isCompletedOn(String habitId, DateTime day) {
    return _completionsByHabit[habitId]?.contains(_dateKey(day)) ?? false;
  }

  int countCompletedOn(DateTime day) {
    final k = _dateKey(day);
    var n = 0;
    for (final h in habits) {
      if (_completionsByHabit[h.id]?.contains(k) ?? false) n++;
    }
    return n;
  }

  bool _anyCompletionOn(DateTime day) => countCompletedOn(day) > 0;

  /// Consecutive days with ≥1 completion, counting backward from today (today can extend streak).
  int get currentStreak {
    if (habits.isEmpty) return 0;
    var streak = 0;
    var d = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    while (_anyCompletionOn(d)) {
      streak++;
      d = d.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// Consecutive days this specific habit was completed (including today).
  int habitStreak(String habitId) {
    var d = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    var n = 0;
    while (isCompletedOn(habitId, d)) {
      n++;
      d = d.subtract(const Duration(days: 1));
    }
    return n;
  }

  Future<void> _updateBestStreak() async {
    final c = currentStreak;
    if (c > bestStreakRecorded) {
      bestStreakRecorded = c;
      await _persist();
    }
  }

  int get totalCompletionDays {
    final allDates = <String>{};
    for (final set in _completionsByHabit.values) {
      allDates.addAll(set);
    }
    return allDates.length;
  }

  int get totalCompletions {
    var n = 0;
    for (final set in _completionsByHabit.values) {
      n += set.length;
    }
    return n;
  }

  /// Points for leaderboard / gamification (local).
  int get totalPoints => totalCompletions * 25 + currentStreak * 15;

  int get level => 1 + (totalPoints ~/ 500);

  /// 0–1 for bond / evolution style bars.
  double get bondProgress {
    if (totalCompletions == 0) return 0.0;
    return (totalCompletions / 40).clamp(0.0, 1.0);
  }

  static const int _companionCompletionsPerLevel = 40;
  static const int _companionMaxLevel = 4;

  /// Companion evolution level: 1 baby, 2 teen, 3 adult, 4 monster.
  int get companionLevel {
    final rawLevel = 1 + (totalCompletions ~/ _companionCompletionsPerLevel);
    return rawLevel.clamp(1, _companionMaxLevel);
  }

  /// Progress inside the current companion level (0–1).
  /// Once level 4 is reached, the bar stays full.
  double get companionBondProgress {
    if (companionLevel >= _companionMaxLevel) return 1.0;
    final inLevel = totalCompletions % _companionCompletionsPerLevel;
    return inLevel / _companionCompletionsPerLevel;
  }

  String get companionFormName {
    switch (companionLevel) {
      case 2:
        return 'Teen Dragon';
      case 3:
        return 'Adult Dragon';
      case 4:
        return 'Monster Dragon';
      default:
        return 'Baby Dragon';
    }
  }

  String get companionStageLabel {
    switch (companionLevel) {
      case 2:
        return 'Adolescent';
      case 3:
        return 'Mature';
      case 4:
        return 'Titan';
      default:
        return 'Hatchling';
    }
  }

  double get todayProgressFraction {
    if (habits.isEmpty) return 0.0;
    final t = DateTime.now();
    var done = 0;
    for (final h in habits) {
      if (isCompletedOn(h.id, t)) done++;
    }
    return done / habits.length;
  }

  int get completedTodayCount => countCompletedOn(DateTime.now());

  /// Rough focus minutes from completed habits today (25 min each).
  int get estimatedFocusMinutesToday {
    return countCompletedOn(DateTime.now()) * 25;
  }

  List<double> last7DayIntensity() {
    final out = <double>[];
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    for (var i = 6; i >= 0; i--) {
      final d = today.subtract(Duration(days: i));
      if (habits.isEmpty) {
        out.add(0);
        continue;
      }
      out.add((countCompletedOn(d) / habits.length).clamp(0.0, 1.0));
    }
    return out;
  }

  /// Raw check-ins per day for the last 7 days, oldest -> newest.
  List<int> last7DayCheckinCounts() {
    final out = <int>[];
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    for (var i = 6; i >= 0; i--) {
      final d = today.subtract(Duration(days: i));
      out.add(countCompletedOn(d));
    }
    return out;
  }

  /// Category ids used for the stats split (unknown → [other]).
  static const List<String> habitCategoryKeys = [
    'focus',
    'move',
    'mind',
    'learn',
    'gym',
    'nutrition',
    'sleep',
    'social',
    'creative',
    'other',
  ];

  Map<String, double> categoryFractions() {
    const keys = habitCategoryKeys;
    if (habits.isEmpty) {
      return {for (final k in keys) k: 0.0};
    }
    final counts = <String, int>{for (final k in keys) k: 0};
    for (final h in habits) {
      final c = keys.contains(h.category) ? h.category : 'other';
      counts[c] = (counts[c] ?? 0) + 1;
    }
    final total = habits.length;
    return {for (final k in keys) k: (counts[k] ?? 0) / total};
  }

  /// Share of check-ins by category (across all recorded completions).
  Map<String, double> categoryCompletionFractions() {
    const keys = habitCategoryKeys;
    final counts = <String, int>{for (final k in keys) k: 0};
    var total = 0;
    for (final h in habits) {
      final c = keys.contains(h.category) ? h.category : 'other';
      final n = _completionsByHabit[h.id]?.length ?? 0;
      counts[c] = (counts[c] ?? 0) + n;
      total += n;
    }
    if (total == 0) {
      return {for (final k in keys) k: 0.0};
    }
    return {for (final k in keys) k: (counts[k] ?? 0) / total};
  }

  /// Share of check-ins by category for the trailing 7 days.
  Map<String, double> categoryCompletionFractionsLast7() {
    const keys = habitCategoryKeys;
    final counts = <String, int>{for (final k in keys) k: 0};
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final startKey = _dateKey(today.subtract(const Duration(days: 6)));
    final endKey = _dateKey(today);
    var total = 0;
    for (final h in habits) {
      final c = keys.contains(h.category) ? h.category : 'other';
      final set = _completionsByHabit[h.id];
      if (set == null || set.isEmpty) continue;
      for (final k in set) {
        if (k.compareTo(startKey) >= 0 && k.compareTo(endKey) <= 0) {
          counts[c] = (counts[c] ?? 0) + 1;
          total++;
        }
      }
    }
    if (total == 0) {
      return {for (final k in keys) k: 0.0};
    }
    return {for (final k in keys) k: (counts[k] ?? 0) / total};
  }

  int focusScore() {
    if (habits.isEmpty) return 0;
    final streakPart = (currentStreak * 4).clamp(0, 40);
    final todayPart = (todayProgressFraction * 40).round();
    final volumePart = (totalCompletions * 0.5).round().clamp(0, 20);
    return (streakPart + todayPart + volumePart).clamp(0, 100);
  }

  List<String> dayLabels(DateTime day) {
    final k = _dateKey(day);
    final lines = <String>[];
    for (final h in habits) {
      if (_completionsByHabit[h.id]?.contains(k) ?? false) {
        lines.add('Done · ${h.title}');
      }
    }
    return lines;
  }

  Future<void> addHabit({
    required String title,
    required String category,
    String? notes,
    String frequency = 'daily',
  }) async {
    final t = title.trim();
    if (t.isEmpty) return;

    final n = notes?.trim();
    final noteStr = n != null && n.isEmpty ? null : n;
    final freq = _normalizeFrequency(frequency);

    final token = await AuthService.getToken();
    if (token != null && token.isNotEmpty) {
      try {
        final res = await http.post(
          _habitsUri(''),
          headers: _authHeaders(token),
          body: jsonEncode({
            'title': t,
            'category': category,
            'notes': noteStr ?? '',
            'frequency': freq,
          }),
        );
        if (res.statusCode == 201) {
          final map = jsonDecode(res.body) as Map<String, dynamic>;
          final hb = map['habit'] as Map<String, dynamic>;
          final rawN = hb['notes'];
          String? mergedNotes = noteStr;
          if (rawN != null) {
            final s = rawN.toString().trim();
            mergedNotes = s.isEmpty ? null : s;
          }
          final h = Habit(
            id: '${hb['id']}',
            title: '${hb['title']}',
            category: '${hb['category'] ?? 'focus'}',
            notes: mergedNotes,
            frequency: _normalizeFrequency('${hb['frequency'] ?? freq}'),
          );
          habits.add(h);
          _completionsByHabit[h.id] ??= {};
          await _persist();
          await _updateBestStreak();
          notifyListeners();
          return;
        }
        if (res.statusCode == 401) await AuthService.saveToken(null);
      } catch (e, st) {
        debugPrint('addHabit api: $e\n$st');
      }
    }

    final h = Habit(
      id: '${DateTime.now().millisecondsSinceEpoch}',
      title: t,
      category: category,
      notes: noteStr,
      frequency: freq,
    );
    habits.add(h);
    _completionsByHabit[h.id] ??= {};
    await _persist();
    await _updateBestStreak();
    notifyListeners();
  }

  Future<void> toggleCompleteToday(String habitId) async {
    final t = DateTime.now();
    final k = _dateKey(t);

    final token = await AuthService.getToken();
    if (token != null &&
        token.isNotEmpty &&
        _looksLikeMongoId(habitId)) {
      try {
        final res = await http.post(
          _habitsUri('/$habitId/toggle'),
          headers: _authHeaders(token),
          body: jsonEncode({'day': k}),
        );
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          _applyRemoteState(data);
          await _persist();
          await _updateBestStreak();
          notifyListeners();
          return;
        }
        if (res.statusCode == 401) await AuthService.saveToken(null);
      } catch (e, st) {
        debugPrint('toggle api: $e\n$st');
      }
    }

    _completionsByHabit.putIfAbsent(habitId, () => {});
    final set = _completionsByHabit[habitId]!;
    if (set.contains(k)) {
      set.remove(k);
    } else {
      set.add(k);
    }
    await _persist();
    await _updateBestStreak();
    notifyListeners();
  }

  Future<void> removeHabit(String habitId) async {
    final token = await AuthService.getToken();
    if (token != null &&
        token.isNotEmpty &&
        _looksLikeMongoId(habitId)) {
      try {
        final res = await http.delete(
          _habitsUri('/$habitId'),
          headers: _authHeaders(token),
        );
        if (res.statusCode == 200) {
          habits.removeWhere((h) => h.id == habitId);
          _completionsByHabit.remove(habitId);
          await _persist();
          notifyListeners();
          return;
        }
        if (res.statusCode == 401) await AuthService.saveToken(null);
      } catch (e, st) {
        debugPrint('removeHabit api: $e\n$st');
      }
    }

    habits.removeWhere((h) => h.id == habitId);
    _completionsByHabit.remove(habitId);
    await _persist();
    notifyListeners();
  }

  /// Repeat field; persisted on server when logged in.
  static String _normalizeFrequency(String f) {
    switch (f) {
      case 'weekdays':
        return 'weekdays';
      case 'weekly':
        return 'weekly';
      default:
        return 'daily';
    }
  }
}

class Habit {
  Habit({
    required this.id,
    required this.title,
    required this.category,
    this.notes,
    this.frequency = 'daily',
  });

  final String id;
  final String title;
  final String category;
  final String? notes;
  /// `daily` | `weekdays` | `weekly` — synced when using the habits API.
  final String frequency;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
        if (frequency != 'daily') 'frequency': frequency,
      };

  factory Habit.fromJson(Map<String, dynamic> j) {
    return Habit(
      id: j['id'] as String,
      title: j['title'] as String,
      category: j['category'] as String? ?? 'focus',
      notes: j['notes'] as String?,
      frequency: j['frequency'] as String? ?? 'daily',
    );
  }
}
