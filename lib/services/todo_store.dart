import 'dart:async';
import 'dart:convert';
import 'dart:math' show Random;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:kultivate_new_ver/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _dateKey(DateTime d) {
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// One-off task; [completedDayKey] matches [TodoStore.todayKey] when done today.
class TodoTask {
  const TodoTask({
    required this.id,
    required this.title,
    this.completedDayKey,
  });

  final String id;
  final String title;
  final String? completedDayKey;

  bool isDoneOn(String dayKey) => completedDayKey == dayKey;

  TodoTask copyWith({String? completedDayKey, bool clearCompleted = false}) {
    return TodoTask(
      id: id,
      title: title,
      completedDayKey: clearCompleted ? null : (completedDayKey ?? this.completedDayKey),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        if (completedDayKey != null) 'completedDayKey': completedDayKey,
      };

  factory TodoTask.fromJson(Map<String, dynamic> j) {
    return TodoTask(
      id: (j['id'] ?? '').toString(),
      title: (j['title'] ?? '').toString(),
      completedDayKey: j['completedDayKey']?.toString(),
    );
  }
}

/// One-off todos for the home “To-Do list”. Local cache + MongoDB when logged in (see `/api/todos`).
class TodoStore extends ChangeNotifier {
  TodoStore._();
  static final TodoStore instance = TodoStore._();

  static const _kTasks = 'standalone_todos_json';

  static final RegExp _mongoIdRe = RegExp(r'^[a-f0-9]{24}$', caseSensitive: false);

  final List<TodoTask> tasks = [];
  bool _loaded = false;
  bool get isLoaded => _loaded;

  Timer? _dayRolloverTimer;
  String? _lastKnownDayKey;

  String get todayKey => _dateKey(DateTime.now());

  bool _looksLikeMongoId(String id) => _mongoIdRe.hasMatch(id);

  Uri _todosUri(String path) => Uri.parse('${AuthService.baseurl}/api/todos$path');

  Map<String, String> _authHeaders(String token) => {
        'content-type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  void _applyRemoteState(Map<String, dynamic> data) {
    final list = data['tasks'] as List<dynamic>? ?? [];
    tasks
      ..clear()
      ..addAll(
        list.map((e) {
          final m = e as Map<String, dynamic>;
          final rawC = m['completedDayKey'];
          String? cdk;
          if (rawC != null) {
            final s = rawC.toString().trim();
            if (s.isNotEmpty) cdk = s;
          }
          return TodoTask(
            id: '${m['id']}',
            title: '${m['title']}',
            completedDayKey: cdk,
          );
        }),
      );
  }

  Future<void> _syncWithServerIfLoggedIn() async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) return;

    try {
      final res = await http.get(
        _todosUri('/state'),
        headers: _authHeaders(token),
      );
      if (res.statusCode == 401) {
        await AuthService.saveToken(null);
        return;
      }
      if (res.statusCode == 404) {
        debugPrint(
          'GET /api/todos/state → 404. Deploy backend with routes/todos.js or fix API_BASE_URL.',
        );
        return;
      }
      if (res.statusCode != 200) {
        debugPrint('GET /api/todos/state → HTTP ${res.statusCode}: ${res.body}');
        return;
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final remoteList = data['tasks'] as List<dynamic>? ?? [];

      if (remoteList.isEmpty && tasks.isNotEmpty) {
        final boot = await http.post(
          _todosUri('/bootstrap'),
          headers: _authHeaders(token),
          body: jsonEncode({
            'tasks': tasks
                .map(
                  (t) => {
                    'tempId': t.id,
                    'title': t.title,
                    if (t.completedDayKey != null) 'completedDayKey': t.completedDayKey,
                  },
                )
                .toList(),
          }),
        );
        if (boot.statusCode == 401) {
          await AuthService.saveToken(null);
          return;
        }
        if (boot.statusCode == 201) {
          final merged = jsonDecode(boot.body) as Map<String, dynamic>;
          _applyRemoteState(merged);
          await _persist();
          final n = (merged['tasks'] as List<dynamic>?)?.length ?? 0;
          debugPrint('Todo bootstrap: uploaded to server, $n task(s) in MongoDB.');
        } else {
          debugPrint(
            'Todo bootstrap failed HTTP ${boot.statusCode}: ${boot.body}',
          );
        }
        return;
      }

      _applyRemoteState(data);
      await _persist();
    } catch (e, st) {
      debugPrint('todo sync: $e\n$st');
    }
  }

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    await load();
  }

  /// Call after login/register when the JWT is saved. Re-runs cloud sync so offline
  /// todos bootstrap to MongoDB and ids upgrade from local-only to server ids.
  Future<void> resyncAfterAuth() async {
    if (!_loaded) {
      await load();
      return;
    }
    await _syncWithServerIfLoggedIn();
    notifyListeners();
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kTasks);
    tasks.clear();
    if (raw != null && raw.isNotEmpty) {
      final list = jsonDecode(raw) as List<dynamic>;
      tasks.addAll(
        list.map((e) => TodoTask.fromJson(e as Map<String, dynamic>)),
      );
    }

    await _syncWithServerIfLoggedIn();

    _lastKnownDayKey = todayKey;
    _startDayRolloverTimer();
    _loaded = true;
    notifyListeners();
  }

  void _startDayRolloverTimer() {
    _dayRolloverTimer?.cancel();
    _dayRolloverTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      final k = todayKey;
      if (_lastKnownDayKey == null) {
        _lastKnownDayKey = k;
        return;
      }
      if (k != _lastKnownDayKey) {
        _lastKnownDayKey = k;
        notifyListeners();
      }
    });
  }

  Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kTasks, jsonEncode(tasks.map((t) => t.toJson()).toList()));
  }

  Future<void> addTask(String rawTitle) async {
    final title = rawTitle.trim();
    if (title.isEmpty) return;

    final token = await AuthService.getToken();
    if (token != null && token.isNotEmpty) {
      try {
        final res = await http.post(
          _todosUri(''),
          headers: _authHeaders(token),
          body: jsonEncode({'title': title}),
        );
        if (res.statusCode == 201) {
          final map = jsonDecode(res.body) as Map<String, dynamic>;
          final tb = map['task'] as Map<String, dynamic>;
          final rawC = tb['completedDayKey'];
          String? cdk;
          if (rawC != null) {
            final s = rawC.toString().trim();
            if (s.isNotEmpty) cdk = s;
          }
          tasks.add(
            TodoTask(
              id: '${tb['id']}',
              title: '${tb['title']}',
              completedDayKey: cdk,
            ),
          );
          await _persist();
          notifyListeners();
          return;
        }
        if (res.statusCode == 401) await AuthService.saveToken(null);
        if (res.statusCode != 201) {
          debugPrint('add todo HTTP ${res.statusCode}: ${res.body}');
        }
      } catch (e, st) {
        debugPrint('add todo api: $e\n$st');
      }
    }

    final id =
        '${DateTime.now().microsecondsSinceEpoch}${Random().nextInt(0x7fffffff)}';
    tasks.add(TodoTask(id: id, title: title));
    await _persist();
    notifyListeners();
  }

  Future<void> toggleDone(String id) async {
    final i = tasks.indexWhere((t) => t.id == id);
    if (i < 0) return;
    final t = tasks[i];
    final k = todayKey;
    final newTask = t.completedDayKey == k
        ? t.copyWith(clearCompleted: true)
        : t.copyWith(completedDayKey: k);
    tasks[i] = newTask;
    notifyListeners();
    unawaited(_persist());

    final token = await AuthService.getToken();
    if (token != null && token.isNotEmpty && _looksLikeMongoId(id)) {
      try {
        final res = await http.patch(
          _todosUri('/$id'),
          headers: _authHeaders(token),
          body: jsonEncode({'completedDayKey': newTask.completedDayKey}),
        );
        if (res.statusCode == 200) {
          final map = jsonDecode(res.body) as Map<String, dynamic>;
          final tb = map['task'] as Map<String, dynamic>;
          final idx = tasks.indexWhere((x) => x.id == id);
          if (idx >= 0) {
            final rawC = tb['completedDayKey'];
            String? cdk;
            if (rawC != null) {
              final s = rawC.toString().trim();
              if (s.isNotEmpty) cdk = s;
            }
            tasks[idx] = TodoTask(
              id: '${tb['id']}',
              title: '${tb['title']}',
              completedDayKey: cdk,
            );
            await _persist();
            notifyListeners();
          }
          return;
        }
        if (res.statusCode == 401) await AuthService.saveToken(null);
      } catch (e, st) {
        debugPrint('todo toggle api: $e\n$st');
      }
    }
  }

  Future<void> removeTask(String id) async {
    final token = await AuthService.getToken();
    if (token != null && token.isNotEmpty && _looksLikeMongoId(id)) {
      try {
        final res = await http.delete(
          _todosUri('/$id'),
          headers: _authHeaders(token),
        );
        if (res.statusCode == 200) {
          tasks.removeWhere((t) => t.id == id);
          await _persist();
          notifyListeners();
          return;
        }
        if (res.statusCode == 401) await AuthService.saveToken(null);
      } catch (e, st) {
        debugPrint('remove todo api: $e\n$st');
      }
    }

    tasks.removeWhere((t) => t.id == id);
    await _persist();
    notifyListeners();
  }
}
