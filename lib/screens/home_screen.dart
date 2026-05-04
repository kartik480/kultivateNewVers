import 'package:app_settings/app_settings.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'dart:math' as math;
import 'package:video_player/video_player.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kultivate_new_ver/services/auth_service.dart';
import 'package:kultivate_new_ver/services/habit_store.dart';
import 'package:kultivate_new_ver/services/reminder_alarm_service.dart';
import 'package:kultivate_new_ver/services/todo_store.dart';

String _categoryForRadialLabel(String label) {
  switch (label) {
    case 'Yoga':
    case 'Meditation':
      return 'mind';
    case 'Running':
    case 'Cycling':
    case 'Walking':
      return 'move';
    case 'Reading':
      return 'learn';
    case 'Gym':
    case 'Strength':
    case 'Strength training':
      return 'gym';
    case 'Hydration':
    case 'Meal prep':
      return 'nutrition';
    case 'Sleep routine':
    case 'Wind-down':
      return 'sleep';
    case 'Social time':
    case 'Call a friend':
      return 'social';
    case 'Creative hour':
      return 'creative';
    default:
      return 'focus';
  }
}

IconData _iconForHabitCategory(String cat) {
  switch (cat) {
    case 'mind':
      return Icons.self_improvement;
    case 'move':
      return Icons.directions_run;
    case 'learn':
      return Icons.menu_book;
    case 'gym':
      return Icons.fitness_center;
    case 'nutrition':
      return Icons.restaurant_menu;
    case 'sleep':
      return Icons.bedtime_outlined;
    case 'social':
      return Icons.groups_outlined;
    case 'creative':
      return Icons.palette_outlined;
    case 'other':
      return Icons.category_outlined;
    default:
      return Icons.center_focus_strong;
  }
}

Color _accentForHabitCategory(String cat) {
  switch (cat) {
    case 'learn':
      return const Color(0xFF1ED7D5);
    case 'gym':
    case 'move':
      return const Color(0xFFFF8A1E);
    case 'mind':
      return const Color(0xFFB05CFF);
    case 'nutrition':
      return const Color(0xFF63D471);
    case 'sleep':
      return const Color(0xFF7C8CFF);
    case 'social':
      return const Color(0xFFFF6FAE);
    case 'creative':
      return const Color(0xFFFFB347);
    default:
      return const Color(0xFF00D9FF);
  }
}

/// Home shell ([Scaffold]) — deep navy base.
const Color _kHomeShellBg = Color(0xFF0F1023);

/// Top header + bottom nav: tonal lift from [_kHomeShellBg], biased cyan to pair with the accent.
const Color _kHomeNavChromeBg = Color(0xFF10182E);

/// Shared between the habit creation panel and the radial FAB picker.
const List<(String label, IconData icon)> _kActivityPresets = [
  ('Yoga', Icons.self_improvement),
  ('Running', Icons.directions_run),
  ('Reading', Icons.menu_book),
  ('Meditation', Icons.spa_outlined),
  ('Cycling', Icons.pedal_bike),
  ('Walking', Icons.directions_walk),
  ('Gym', Icons.fitness_center),
  ('Strength', Icons.sports_gymnastics),
  ('Hydration', Icons.water_drop_outlined),
  ('Meal prep', Icons.restaurant_menu),
  ('Sleep routine', Icons.bedtime_outlined),
  ('Wind-down', Icons.nightlight_round),
  ('Social time', Icons.groups_outlined),
  ('Call a friend', Icons.call_outlined),
  ('Creative hour', Icons.palette_outlined),
];

class _ManualReminder {
  const _ManualReminder({
    required this.alarmId,
    required this.habitId,
    required this.habitTitle,
    required this.time,
    required this.createdAt,
    this.note,
  });

  final int alarmId;
  final String habitId;
  final String habitTitle;
  final TimeOfDay time;
  final DateTime createdAt;
  final String? note;

  Map<String, dynamic> toJson() => {
    'alarmId': alarmId,
    'habitId': habitId,
    'habitTitle': habitTitle,
    'timeHour': time.hour,
    'timeMinute': time.minute,
    'createdAt': createdAt.toIso8601String(),
    if (note != null && note!.trim().isNotEmpty) 'note': note!.trim(),
  };

  factory _ManualReminder.fromJson(Map<String, dynamic> j) {
    return _ManualReminder(
      alarmId: (j['alarmId'] as num?)?.toInt() ?? 0,
      habitId: (j['habitId'] ?? '').toString(),
      habitTitle: (j['habitTitle'] ?? '').toString(),
      time: TimeOfDay(
        hour: (j['timeHour'] as num?)?.toInt() ?? 7,
        minute: (j['timeMinute'] as num?)?.toInt() ?? 0,
      ),
      createdAt:
          DateTime.tryParse((j['createdAt'] ?? '').toString()) ??
          DateTime.now(),
      note: j['note']?.toString(),
    );
  }
}

class _ReminderHistoryEntry {
  const _ReminderHistoryEntry({
    required this.title,
    required this.detail,
    required this.createdAt,
  });

  final String title;
  final String detail;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'title': title,
    'detail': detail,
    'createdAt': createdAt.toIso8601String(),
  };

  factory _ReminderHistoryEntry.fromJson(Map<String, dynamic> j) {
    return _ReminderHistoryEntry(
      title: (j['title'] ?? '').toString(),
      detail: (j['detail'] ?? '').toString(),
      createdAt:
          DateTime.tryParse((j['createdAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}

/// Drives the reminder carousel clock at 1 Hz instead of tying it to
/// [_waveController] (~60 ticks/s), which was a major source of jank.
class _ReminderLensClockTicker extends StatefulWidget {
  const _ReminderLensClockTicker({
    required this.buildAnalog,
    required this.formatDigital,
  });

  final Widget Function(DateTime now) buildAnalog;
  final String Function(DateTime now) formatDigital;

  @override
  State<_ReminderLensClockTicker> createState() =>
      _ReminderLensClockTickerState();
}

class _ReminderLensClockTickerState extends State<_ReminderLensClockTicker> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
      child: Column(
        children: [
          widget.buildAnalog(now),
          const SizedBox(height: 6),
          Text(
            widget.formatDigital(now),
            style: const TextStyle(
              color: Color(0xFF00D9FF),
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Reminder clock',
            style: TextStyle(
              color: Colors.white.withOpacity(0.62),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

// Added TickerProviderStateMixin for the wave animation
class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  static const String _defaultCompanionAsset = 'companions/babydragon.mp4';
  static const String _kManualReminders = 'manual_reminders_json';
  static const String _kReminderHistory = 'manual_reminder_history_json';
  static const int _kTodoPreviewLimit = 2;
  static const int _kMomentumPreviewLimit = 10;
  double _navBarHeight = 120.0;
  final double _minHeight = 120.0;

  /// Filled when user picks a radial preset; consumed when the overlay [onClose] runs.
  (String title, String category)? _pendingRadialHabitForm;

  late final PageController _statsPageController;
  int _statsPageIndex = 0;

  late AnimationController _waveController;
  late VideoPlayerController _babyDragonController;

  /// Separate controller so the carousel lens can show the same clip without
  /// attaching two [VideoPlayer]s to one controller (which breaks rendering).
  late VideoPlayerController _companionLensController;
  String _activeCompanionAsset = _defaultCompanionAsset;
  bool _isSwitchingCompanionVideo = false;
  bool _wasCompanionsExpanded = false;
  bool _isSocialTemporarilyLocked = true;
  bool _isRadialMenuOpen = false;
  bool _momentumHabitListExpanded = false;
  bool _showAllHomeHabits = false;
  Habit? _selectedManualReminderHabit;
  TimeOfDay _manualReminderTime = const TimeOfDay(hour: 7, minute: 0);
  final TextEditingController _manualReminderHabitCtrl =
      TextEditingController();
  final TextEditingController _manualReminderNoteCtrl = TextEditingController();
  final TextEditingController _newTodoCtrl = TextEditingController();
  final List<_ManualReminder> _manualReminders = [];
  final List<_ReminderHistoryEntry> _reminderHistory = [];

  int _alarmIdForReminder({
    required DateTime createdAt,
    required String habitTitle,
    required TimeOfDay time,
  }) {
    final base = createdAt.microsecondsSinceEpoch.abs();
    final salt = (habitTitle.length * 97) + (time.hour * 60) + time.minute;
    return ((base + salt) % 2147483646).toInt() + 1;
  }

  Future<void> _rescheduleReminderAlarms() async {
    await ReminderAlarmService.instance.ensureInitialized();
    await ReminderAlarmService.instance.cancelAll();
    for (final reminder in _manualReminders) {
      await ReminderAlarmService.instance.scheduleDailyReminder(
        alarmId: reminder.alarmId,
        title: reminder.habitTitle,
        time: reminder.time,
        body: reminder.note,
      );
    }
  }

  void _onBabyDragonVideoTick() {
    final c = _babyDragonController;
    if (!mounted || !c.value.isInitialized) return;
    if (c.value.isCompleted) {
      c.seekTo(Duration.zero).then((_) {
        if (mounted) c.play();
      });
    }
  }

  void _resumeBabyDragonVideo() {
    final c = _babyDragonController;
    if (!c.value.isInitialized) return;
    c.setLooping(true);
    if (!c.value.isPlaying) {
      c.play();
    }
  }

  String _companionAssetForLevel(int level) {
    switch (level) {
      case 2:
        return 'companions/teen_dragon_web.mp4';
      case 3:
        return 'companions/adult_dragon_web.mp4';
      case 4:
        return 'companions/monster_dragon_web.mp4';
      default:
        return _defaultCompanionAsset;
    }
  }

  VideoPlayerController _buildCompanionController(String assetPath) {
    return VideoPlayerController.asset(assetPath)
      ..setLooping(true)
      ..setVolume(0);
  }

  void _onHabitStoreChanged() {
    _refreshCompanionVideoForLevel();
  }

  Future<void> _loadRemindersState() async {
    await ReminderAlarmService.instance.ensureInitialized();
    final p = await SharedPreferences.getInstance();
    final remindersRaw = p.getString(_kManualReminders);
    final historyRaw = p.getString(_kReminderHistory);

    final loadedReminders = <_ManualReminder>[];
    final loadedHistory = <_ReminderHistoryEntry>[];

    if (remindersRaw != null && remindersRaw.isNotEmpty) {
      try {
        final list = jsonDecode(remindersRaw) as List<dynamic>;
        loadedReminders.addAll(
          list.map((e) => _ManualReminder.fromJson(e as Map<String, dynamic>)),
        );
      } catch (_) {}
    }
    if (historyRaw != null && historyRaw.isNotEmpty) {
      try {
        final list = jsonDecode(historyRaw) as List<dynamic>;
        loadedHistory.addAll(
          list.map(
            (e) => _ReminderHistoryEntry.fromJson(e as Map<String, dynamic>),
          ),
        );
      } catch (_) {}
    }

    if (mounted) {
      final normalized = loadedReminders
          .map(
            (r) => r.alarmId > 0
                ? r
                : _ManualReminder(
                    alarmId: _alarmIdForReminder(
                      createdAt: r.createdAt,
                      habitTitle: r.habitTitle,
                      time: r.time,
                    ),
                    habitId: r.habitId,
                    habitTitle: r.habitTitle,
                    time: r.time,
                    createdAt: r.createdAt,
                    note: r.note,
                  ),
          )
          .toList();
      setState(() {
        _manualReminders
          ..clear()
          ..addAll(normalized);
        _reminderHistory
          ..clear()
          ..addAll(loadedHistory);
      });
    }

    await _rescheduleReminderAlarms();
    await _syncRemindersFromServer();
  }

  Future<void> _persistRemindersState() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _kManualReminders,
      jsonEncode(_manualReminders.map((r) => r.toJson()).toList()),
    );
    await p.setString(
      _kReminderHistory,
      jsonEncode(_reminderHistory.map((h) => h.toJson()).toList()),
    );
  }

  Future<void> _syncRemindersFromServer() async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) return;
    try {
      final res = await http.get(
        Uri.parse('${AuthService.baseurl}/api/reminders'),
        headers: {
          'content-type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (res.statusCode == 401) {
        await AuthService.saveToken(null);
        return;
      }
      if (res.statusCode != 200) return;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final list = body['reminders'] as List<dynamic>? ?? const [];
      // Never replace local reminders with an empty server list — that would
      // cancel all pending notification alarms via _rescheduleReminderAlarms.
      if (list.isEmpty && _manualReminders.isNotEmpty) {
        debugPrint(
          'reminder sync: server returned 0 reminders; keeping local list',
        );
        return;
      }
      final remote = list.map((e) {
        final m = e as Map<String, dynamic>;
        final parsedAt =
            DateTime.tryParse((m['createdAt'] ?? '').toString()) ??
            DateTime.now();
        final txt = (m['time'] ?? '').toString().trim();
        final tod = _parseTimeLabel(txt) ?? _manualReminderTime;
        final fallbackAlarmId = _alarmIdForReminder(
          createdAt: parsedAt,
          habitTitle: (m['habitTitle'] ?? '').toString(),
          time: tod,
        );
        return _ManualReminder(
          alarmId: (m['alarmId'] as num?)?.toInt() ?? fallbackAlarmId,
          habitId: (m['habitId'] ?? '').toString(),
          habitTitle: (m['habitTitle'] ?? '').toString(),
          time: tod,
          note: m['note']?.toString(),
          createdAt: parsedAt,
        );
      }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (!mounted) return;
      setState(() {
        _manualReminders
          ..clear()
          ..addAll(remote);
      });
      await _rescheduleReminderAlarms();
      unawaited(_persistRemindersState());
    } catch (e, st) {
      debugPrint('reminder sync: $e\n$st');
    }
  }

  Future<bool> _saveReminderToServer(_ManualReminder reminder) async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) return false;
    try {
      final res = await http.post(
        Uri.parse('${AuthService.baseurl}/api/reminders'),
        headers: {
          'content-type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'alarmId': reminder.alarmId,
          'habitId': reminder.habitId,
          'habitTitle': reminder.habitTitle,
          'time': _formatTimeOfDay(reminder.time),
          'note': reminder.note ?? '',
          'createdAt': reminder.createdAt.toIso8601String(),
        }),
      );
      if (res.statusCode == 401) {
        await AuthService.saveToken(null);
        return false;
      }
      return res.statusCode == 201;
    } catch (e, st) {
      debugPrint('reminder save: $e\n$st');
      return false;
    }
  }

  TimeOfDay? _parseTimeLabel(String label) {
    final m = RegExp(
      r'^(\d{1,2}):(\d{2})\s*([AP]M)$',
      caseSensitive: false,
    ).firstMatch(label.trim());
    if (m == null) return null;
    var hour = int.tryParse(m.group(1) ?? '');
    final min = int.tryParse(m.group(2) ?? '');
    final ap = (m.group(3) ?? '').toUpperCase();
    if (hour == null || min == null) return null;
    hour = hour.clamp(1, 12).toInt();
    if (ap == 'AM') {
      if (hour == 12) hour = 0;
    } else {
      if (hour != 12) hour += 12;
    }
    return TimeOfDay(hour: hour, minute: min.clamp(0, 59).toInt());
  }

  void _scheduleCompanionVideoResyncIfNeeded() {
    if (_isSwitchingCompanionVideo || !mounted) return;
    final targetAsset = _companionAssetForLevel(
      HabitStore.instance.companionLevel,
    );
    if (targetAsset == _activeCompanionAsset) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _refreshCompanionVideoForLevel();
      }
    });
  }

  Future<void> _refreshCompanionVideoForLevel() async {
    if (_isSwitchingCompanionVideo) return;
    final targetAsset = _companionAssetForLevel(
      HabitStore.instance.companionLevel,
    );
    if (targetAsset == _activeCompanionAsset) return;
    _isSwitchingCompanionVideo = true;

    final previousMain = _babyDragonController;
    final previousLens = _companionLensController;

    final nextMain = _buildCompanionController(targetAsset);
    nextMain.addListener(_onBabyDragonVideoTick);

    final nextLens = _buildCompanionController(targetAsset);

    try {
      await Future.wait([
        nextMain.initialize().timeout(const Duration(seconds: 12)),
        nextLens.initialize().timeout(const Duration(seconds: 12)),
      ]);
    } catch (e, st) {
      debugPrint('companion video load: $e\n$st');
      nextMain.removeListener(_onBabyDragonVideoTick);
      await nextMain.dispose();
      await nextLens.dispose();
      _isSwitchingCompanionVideo = false;
      return;
    }

    if (!mounted) {
      nextMain.removeListener(_onBabyDragonVideoTick);
      await nextMain.dispose();
      await nextLens.dispose();
      _isSwitchingCompanionVideo = false;
      return;
    }

    setState(() {
      _babyDragonController = nextMain;
      _companionLensController = nextLens;
      _activeCompanionAsset = targetAsset;
    });

    _babyDragonController.setLooping(true);
    _babyDragonController.play();
    if (_statsPageIndex == 2) {
      _companionLensController.play();
    }

    previousMain.removeListener(_onBabyDragonVideoTick);
    await previousMain.dispose();
    await previousLens.dispose();
    _isSwitchingCompanionVideo = false;
  }

  @override
  void initState() {
    super.initState();
    HabitStore.instance.addListener(_onHabitStoreChanged);
    HabitStore.instance.ensureLoaded();
    TodoStore.instance.ensureLoaded();
    unawaited(_loadRemindersState());
    // Animation controller that runs infinitely
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _activeCompanionAsset = _companionAssetForLevel(
      HabitStore.instance.companionLevel,
    );

    _babyDragonController = _buildCompanionController(_activeCompanionAsset);
    _babyDragonController.addListener(_onBabyDragonVideoTick);
    _babyDragonController
        .initialize()
        .then((_) {
          if (mounted) {
            setState(() {});
            _babyDragonController.setLooping(true);
            _babyDragonController.play();
          }
        })
        .catchError((e, st) {
          debugPrint('companion main init: $e\n$st');
        });

    _companionLensController = _buildCompanionController(_activeCompanionAsset);
    _companionLensController
        .initialize()
        .then((_) {
          if (!mounted) return;
          setState(() {});
          if (_statsPageIndex == 2) {
            _companionLensController.play();
          }
        })
        .catchError((e, st) {
          debugPrint('companion lens init: $e\n$st');
        });

    _statsPageController = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshCompanionVideoForLevel();
      unawaited(_resyncTodosIfLoggedIn());
    });
    unawaited(
      GoogleFonts.pendingFonts(<TextStyle>[
        GoogleFonts.greatVibes(fontSize: 20, color: Colors.white, height: 1.05),
        GoogleFonts.greatVibes(fontSize: 24, color: Colors.white, height: 1.05),
      ]),
    );
  }

  @override
  void dispose() {
    HabitStore.instance.removeListener(_onHabitStoreChanged);
    _babyDragonController.removeListener(_onBabyDragonVideoTick);
    _waveController.dispose();
    _babyDragonController.dispose();
    _companionLensController.dispose();
    _statsPageController.dispose();
    _manualReminderHabitCtrl.dispose();
    _manualReminderNoteCtrl.dispose();
    _newTodoCtrl.dispose();
    super.dispose();
  }

  /// Runs todo Mongo sync again when a JWT exists (handles logged-in sessions after cold start).
  Future<void> _resyncTodosIfLoggedIn() async {
    final t = await AuthService.getToken();
    if (t == null || t.isEmpty) return;
    await TodoStore.instance.resyncAfterAuth();
  }

  double _calculateOpacity(double maxHeight) {
    double opacity =
        1.0 - ((_navBarHeight - _minHeight) / (maxHeight * 0.6 - _minHeight));
    return opacity.clamp(0.0, 1.0);
  }

  double _getIconOpacity() {
    double fade = 1.0 - ((_navBarHeight - _minHeight) / 30);
    return fade.clamp(0.0, 1.0);
  }

  /// Bottom inset for the main scroll so the last cards stay above the docked
  /// FAB + frosted nav (varies by screen height, text scale, and system bars).
  double _homeScrollBottomPadding(BuildContext context) {
    final safe = MediaQuery.viewPaddingOf(context).bottom;
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    const baseReserve =
        188.0; // centerDocked FAB + translated FAB + frosted nav row + margins
    final largeTextExtra =
        textScale > 1.0 ? 44.0 * (textScale - 1.0).clamp(0.0, 0.85) : 0.0;
    return math.max(252.0, safe + baseReserve + largeTextExtra);
  }

  void _onPanelVerticalDragUpdate(DragUpdateDetails details) {
    final maxH = MediaQuery.sizeOf(context).height;
    setState(() {
      _navBarHeight = (_navBarHeight + details.delta.dy).clamp(
        _minHeight,
        maxH,
      );
    });
  }

  void _onPanelVerticalDragEnd(DragEndDetails details) {
    final screenH = MediaQuery.sizeOf(context).height;
    final maxH = screenH;
    final vy = details.velocity.pixelsPerSecond.dy;
    setState(() {
      // Flick open / closed (lower threshold so slow drags still register).
      if (vy > 280) {
        _navBarHeight = maxH;
        return;
      }
      if (vy < -280) {
        _navBarHeight = _minHeight;
        return;
      }
      // No strong flick: snap to whichever height is closer (avoids “stuck”
      // between min and a tiny drag that used to always snap closed).
      final distMin = (_navBarHeight - _minHeight).abs();
      final distMax = (_navBarHeight - maxH).abs();
      _navBarHeight = distMin < distMax ? _minHeight : maxH;
    });
  }

  /// FAB layout matches [Scaffold] + [Transform.translate] on the + button (no GlobalKey — avoids
  /// web/hot-reload issues where `GlobalKey.currentContext` can be undefined in JS).
  (Offset, Size) _fabTopLeftAndSize() {
    const fabSize = Size(70, 70);
    const fabTranslateY = 27.0;
    final mq = MediaQuery.of(context);
    final sz = mq.size;
    final pad = mq.padding;
    // Same as bottom nav: Padding.all(16) + height 80
    const navBlock = 16.0 * 2 + 80.0;
    final contentBottom = sz.height - pad.bottom - navBlock;
    final top = contentBottom - fabSize.height / 2 + fabTranslateY;
    final left = (sz.width - fabSize.width) / 2;
    return (Offset(left, top), fabSize);
  }

  void _showHabitCreatePanel({String? initialTitle, String? initialCategory}) {
    final fromPreset =
        initialTitle != null &&
        initialTitle.isNotEmpty &&
        initialCategory != null &&
        initialCategory.isNotEmpty;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final bottomInset = MediaQuery.paddingOf(sheetContext).bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: DraggableScrollableSheet(
            initialChildSize: fromPreset ? 0.74 : 0.66,
            minChildSize: 0.36,
            maxChildSize: 0.92,
            expand: false,
            builder: (context, scrollController) {
              return _HabitCreateSheet(
                scrollController: scrollController,
                initialTitle: initialTitle,
                initialCategory: initialCategory,
                onOpenActivityWheel: () {
                  Navigator.of(sheetContext).pop();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    _openActivityRadialMenu();
                  });
                },
              );
            },
          ),
        );
      },
    );
  }

  void _showHabitTeacherBotPanel() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final bottomInset = MediaQuery.paddingOf(sheetContext).bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: DraggableScrollableSheet(
            initialChildSize: 0.74,
            minChildSize: 0.45,
            maxChildSize: 0.94,
            expand: false,
            builder: (context, scrollController) {
              return _HabitTeacherBotSheet(
                scrollController: scrollController,
                onOpenHabitCreator: () {
                  Navigator.of(sheetContext).pop();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    _showHabitCreatePanel();
                  });
                },
              );
            },
          ),
        );
      },
    );
  }

  void _openActivityRadialMenu() {
    _pendingRadialHabitForm = null;
    final (topLeft, fabSize) = _fabTopLeftAndSize();
    if (mounted) {
      setState(() => _isRadialMenuOpen = true);
    }

    showGeneralDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.transparent,
      transitionDuration: Duration.zero,
      pageBuilder: (dialogContext, _, __) {
        return RadialActivityPickerOverlay(
          fabTopLeft: topLeft,
          fabSize: fabSize,
          onClose: () {
            final payload = _pendingRadialHabitForm;
            _pendingRadialHabitForm = null;
            Navigator.of(dialogContext).pop();
            if (payload != null && mounted) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                _showHabitCreatePanel(
                  initialTitle: payload.$1,
                  initialCategory: payload.$2,
                );
              });
            }
          },
          onPresetChosen: (title, category) {
            _pendingRadialHabitForm = (title, category);
          },
          onAfterCustomHabit: () async {
            if (!mounted) return;
            _showHabitCreatePanel();
          },
        );
      },
    ).whenComplete(() {
      if (!mounted) return;
      setState(() => _isRadialMenuOpen = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double maxHeight = screenHeight;
    // After SafeArea reserves the status bar, inner height would be
    // `_navBarHeight - topInset` unless we extend the outer height.
    final double topInset = MediaQuery.paddingOf(context).top;
    final double outerPanelHeight = math.min(
      screenHeight,
      _navBarHeight + topInset,
    );
    // Visible gap between the bottom of the top panel and the greeting block.
    const double gapBelowTopNav = 28;
    final double scrollTopPadding = math.min(
      outerPanelHeight + gapBelowTopNav,
      screenHeight * 0.32,
    );
    final bool companionsExpanded = _navBarHeight > 250;
    if (companionsExpanded && !_wasCompanionsExpanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _resumeBabyDragonVideo();
      });
    }
    _wasCompanionsExpanded = companionsExpanded;

    return ListenableBuilder(
      listenable: HabitStore.instance,
      builder: (context, _) {
        if (!HabitStore.instance.isLoaded) {
          return const Scaffold(
            backgroundColor: _kHomeShellBg,
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF00D9FF)),
            ),
          );
        }
        return Scaffold(
          backgroundColor: _kHomeShellBg,
          extendBody: true,
          bottomNavigationBar: _buildBottomNavBar(),
          floatingActionButton: Transform.translate(
            offset: const Offset(0, 27),
            child: Container(
              height: 70,
              width: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF00D9FF), Color(0xFF00D8FF)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.6),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.add, color: Colors.white, size: 32),
                onPressed: _openActivityRadialMenu,
              ),
            ),
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerDocked,
          body: Stack(
            children: [
              Positioned.fill(
                child: Opacity(
                  opacity: _calculateOpacity(maxHeight),
                  child: SingleChildScrollView(
                    primary: false,
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: EdgeInsets.only(
                      top: scrollTopPadding,
                      left: 16,
                      right: 16,
                      bottom: _homeScrollBottomPadding(context),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        _buildStatsCarousel(),
                        const SizedBox(height: 38),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: _buildStatsSwapTransition,
                          child: Column(
                            key: ValueKey<int>(_statsPageIndex),
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _statsPanelSectionTitle(),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _statsPanelSectionSubtitle(),
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.25,
                                  color: Colors.white.withOpacity(0.58),
                                ),
                              ),
                              const SizedBox(height: 12),
                              ..._buildHabitSectionForStatsPage(
                                context,
                                _statsPageIndex,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              if (_navBarHeight > _minHeight)
                Positioned.fill(
                  child: IgnorePointer(
                    child: RepaintBoundary(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(
                          // Full-screen blur is expensive on GPU; cap sigma for smoother scrolling.
                          sigmaX: (1.0 - _calculateOpacity(maxHeight)) * 8,
                          sigmaY: (1.0 - _calculateOpacity(maxHeight)) * 8,
                        ),
                        child: Container(
                          color: Colors.black.withOpacity(
                            0.2 * (1.0 - _calculateOpacity(maxHeight)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: outerPanelHeight,
                child: Container(
                  decoration: BoxDecoration(
                    color: _kHomeNavChromeBg,
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(
                        _navBarHeight >= maxHeight ? 0 : 30,
                      ),
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onVerticalDragUpdate: _navBarHeight < maxHeight
                              ? _onPanelVerticalDragUpdate
                              : null,
                          onVerticalDragEnd: _navBarHeight < maxHeight
                              ? _onPanelVerticalDragEnd
                              : null,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12.0,
                            ),
                            child: SizedBox(height: 12, width: double.infinity),
                          ),
                        ),

                        if (_navBarHeight > 250)
                          Expanded(
                            child: NotificationListener<ScrollNotification>(
                              onNotification: (ScrollNotification n) {
                                if (n is OverscrollNotification &&
                                    n.metrics.axis == Axis.vertical &&
                                    n.metrics.pixels <=
                                        n.metrics.minScrollExtent &&
                                    n.overscroll < 0) {
                                  // When companion content is already at top, a pull-down gesture
                                  // should collapse the panel itself.
                                  setState(() {
                                    _navBarHeight =
                                        (_navBarHeight - n.overscroll).clamp(
                                          _minHeight,
                                          maxHeight,
                                        );
                                  });
                                  // Don't consume the notification; consuming here can make the
                                  // first touch feel "stuck" in the inner scroll view.
                                  return false;
                                }
                                if (n is ScrollEndNotification) {
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    if (mounted) _resumeBabyDragonVideo();
                                  });
                                }
                                return false;
                              },
                              child: SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(
                                  24,
                                  10,
                                  24,
                                  140,
                                ),
                                child: Column(
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.keyboard_arrow_up,
                                        color: Colors.white,
                                        size: 30,
                                      ),
                                      onPressed: () => setState(
                                        () => _navBarHeight = _minHeight,
                                      ),
                                    ),
                                    const Text(
                                      "My Companions",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    _buildCompanionVideoFrame(),
                                    const SizedBox(height: 20),

                                    // statistical progressive bar
                                    ListenableBuilder(
                                      listenable: HabitStore.instance,
                                      builder: (context, _) {
                                        final progressPct =
                                            (HabitStore
                                                        .instance
                                                        .companionBondProgress *
                                                    100)
                                                .round();
                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                const Text(
                                                  "Bond level",
                                                  style: TextStyle(
                                                    color: Colors.white70,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                const Spacer(),
                                                Text(
                                                  '$progressPct%',
                                                  style: const TextStyle(
                                                    color: Color(0xFF00D9FF),
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              child: LinearProgressIndicator(
                                                value: HabitStore
                                                    .instance
                                                    .companionBondProgress,
                                                minHeight: 12,
                                                backgroundColor: Colors.white10,
                                                color: const Color(0xFF00D9FF),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 25),
                                    _menuItem(
                                      Icons.favorite,
                                      "Companion Status",
                                      "Get new skins and accessories",
                                      onTap: () =>
                                          _showCompanionStatusSheet(context),
                                    ),
                                    const SizedBox(height: 12),
                                    _buildGamificationSection(),
                                  ],
                                ),
                              ),
                            ),
                          )
                        else
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onVerticalDragUpdate: _navBarHeight < maxHeight
                                  ? _onPanelVerticalDragUpdate
                                  : null,
                              onVerticalDragEnd: _navBarHeight < maxHeight
                                  ? _onPanelVerticalDragEnd
                                  : null,
                              child: const ColoredBox(
                                color: Colors.transparent,
                              ),
                            ),
                          ),

                        GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onVerticalDragUpdate: _navBarHeight < maxHeight
                              ? _onPanelVerticalDragUpdate
                              : null,
                          onVerticalDragEnd: _navBarHeight < maxHeight
                              ? _onPanelVerticalDragEnd
                              : null,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Opacity(
                                  opacity: _getIconOpacity(),
                                  child: IgnorePointer(
                                    ignoring: _navBarHeight > _minHeight + 10,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                            Icons.smart_toy_outlined,
                                            color: Color(0xFF00D9FF),
                                            size: 22,
                                          ),
                                          onPressed: _showHabitTeacherBotPanel,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_navBarHeight < maxHeight)
                          GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onVerticalDragUpdate: _onPanelVerticalDragUpdate,
                            onVerticalDragEnd: _onPanelVerticalDragEnd,
                            child: SizedBox(
                              height: 52,
                              width: double.infinity,
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: Container(
                                  height: 9,
                                  width: 112,
                                  margin: const EdgeInsets.only(top: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00D9FF),
                                    borderRadius: BorderRadius.circular(50),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- PROGRESS BAR WITH WAVE ANIMATION ---

  Widget _buildStatsSwapTransition(Widget child, Animation<double> animation) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final fade = Tween<double>(begin: 0.0, end: 1.0).animate(curved);
    return FadeTransition(opacity: fade, child: child);
  }

  Widget _buildVerticalStat(
    String title,
    String value,
    double progress,
    Color color, {
    String unit = '',
    double barWidth = 50,
    double maxHeight = 92,
    double titleFontSize = 11,
    double valueFontSize = 14,
    double unitFontSize = 11,
  }) {
    final targetProgress = progress.clamp(0.0, 1.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white70,
            fontSize: titleFontSize,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 520),
          curve: Curves.easeOutCubic,
          tween: Tween<double>(begin: targetProgress, end: targetProgress),
          builder: (context, animatedProgress, _) {
            return Stack(
              alignment: Alignment.bottomCenter,
              children: [
                // Background track
                Container(
                  height: maxHeight,
                  width: barWidth,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                // Wave Animated Progress
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: RepaintBoundary(
                    child: AnimatedBuilder(
                      animation: _waveController,
                      builder: (context, child) {
                        return CustomPaint(
                          size: Size(barWidth, maxHeight),
                          painter: WavePainter(
                            color: color,
                            progress: animatedProgress,
                            waveValue: _waveController.value,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: valueFontSize,
              ),
            ),
            if (unit.isNotEmpty) ...[
              const SizedBox(width: 2),
              Text(
                unit,
                style: TextStyle(
                  color: color.withOpacity(0.85),
                  fontWeight: FontWeight.w600,
                  fontSize: unitFontSize,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  // --- REST OF HELPERS ---

  static const int _statsPageCount = 3;

  /// Carousel lenses: streak momentum, reminders, and My companion.
  Widget _buildStatsCarousel() {
    final s = HabitStore.instance;
    final tp = s.todayProgressFraction;
    final fm = s.estimatedFocusMinutesToday;
    final focusVal = fm <= 0
        ? '0'
        : (fm < 60 ? '$fm' : (fm / 60).toStringAsFixed(fm >= 600 ? 0 : 1));
    final focusUnit = fm >= 60 ? 'h' : 'm';
    final curProg = s.habits.isEmpty
        ? 0.0
        : (s.currentStreak / 30.0).clamp(0.0, 1.0);
    final bestProg = s.bestStreakRecorded == 0
        ? 0.0
        : (s.bestStreakRecorded / 60.0).clamp(0.0, 1.0);
    const cyan = Color(0xFF00D9FF);

    final mq = MediaQuery.sizeOf(context);
    final carouselPageHeight = (mq.height * 0.22).clamp(172.0, 200.0);

    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: carouselPageHeight,
              child: PageView.builder(
                controller: _statsPageController,
                itemCount: _statsPageCount,
                // Default drag start so vertical drags can still drive the outer
                // [SingleChildScrollView] when the gesture begins on the carousel.
                physics: const PageScrollPhysics(),
                padEnds: false,
                onPageChanged: (i) {
                  setState(() => _statsPageIndex = i);
                  _syncCompanionLensPlayback(i);
                },
                itemBuilder: (context, i) {
                  if (i == 1) {
                    return _buildReminderLensClockSummary();
                  }
                  if (i == 2) {
                    return _buildCompanionLensSummary();
                  }
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildVerticalStat(
                          "current\nStreak",
                          '${s.currentStreak}',
                          curProg,
                          Colors.orange,
                        ),
                        _buildVerticalStat(
                          "Today's\nProgress",
                          '${(tp * 100).round()}%',
                          tp.clamp(0.0, 1.0),
                          Colors.orange,
                        ),
                        _buildVerticalStat(
                          "Focus\nTime",
                          focusVal,
                          (fm / 120.0).clamp(0.0, 1.0),
                          Colors.orange,
                          unit: focusUnit,
                        ),
                        _buildVerticalStat(
                          "Best\nStreak",
                          '${s.bestStreakRecorded}',
                          bestProg,
                          Colors.orange,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'Swipe · ${_statsSwipeLensLabel(_statsPageIndex)}',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.42),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_statsPageCount, (i) {
                  final on = i == _statsPageIndex;
                  return GestureDetector(
                    onTap: () {
                      _statsPageController.animateToPage(
                        i,
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeOutCubic,
                      );
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: on ? 22 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(99),
                        color: on ? cyan : Colors.white.withOpacity(0.22),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderLensClockSummary() {
    return _ReminderLensClockTicker(
      buildAnalog: (now) => _buildAnalogReminderClock(now, size: 108),
      formatDigital: _formatReminderClock,
    );
  }

  void _syncCompanionLensPlayback(int pageIndex) {
    final c = _companionLensController;
    if (!c.value.isInitialized) return;
    if (pageIndex == 2) {
      c.play();
    } else {
      c.pause();
    }
  }

  Widget _unsupportedVideoFallback({required bool compact}) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.video_file_outlined,
              color: const Color(0xFF00D9FF).withOpacity(0.9),
              size: compact ? 20 : 30,
            ),
            SizedBox(height: compact ? 6 : 8),
            Text(
              'Video format not supported by browser',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.78),
                fontSize: compact ? 9.5 : 11.5,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Uses [_companionLensController] so the main companion [VideoPlayer] is unchanged.
  Widget _buildCompanionLensSummary() {
    _scheduleCompanionVideoResyncIfNeeded();
    const cyan = Color(0xFF00D9FF);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: ListenableBuilder(
        listenable: HabitStore.instance,
        builder: (context, _) {
          final store = HabitStore.instance;
          final bond = (store.companionBondProgress * 100).round();
          return Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 100,
                  height: 100,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: const LinearGradient(
                        colors: [cyan, Color(0xFF6A5CFF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: ColoredBox(
                        color: const Color(0xFF10142B),
                        child: AnimatedBuilder(
                          animation: _companionLensController,
                          builder: (context, _) {
                            if (_companionLensController.value.hasError) {
                              return _unsupportedVideoFallback(compact: true);
                            }
                            final ready =
                                _companionLensController.value.isInitialized;
                            if (!ready) {
                              return const Center(
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: cyan,
                                  ),
                                ),
                              );
                            }
                            return FittedBox(
                              fit: BoxFit.cover,
                              alignment: Alignment.center,
                              child: SizedBox(
                                width:
                                    _companionLensController.value.size.width,
                                height:
                                    _companionLensController.value.size.height,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Positioned.fill(
                                      child: IgnorePointer(
                                        ignoring: true,
                                        child: VideoPlayer(
                                          _companionLensController,
                                        ),
                                      ),
                                    ),
                                    Positioned.fill(
                                      child: Listener(
                                        behavior: HitTestBehavior.translucent,
                                        child: const SizedBox.expand(),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store.companionFormName,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.92),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$bond% bond',
                      style: const TextStyle(
                        color: cyan,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Grows with check-ins',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.55),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _statsSwipeLensLabel(int i) {
    switch (i) {
      case 0:
        return 'streak momentum';
      case 1:
        return 'reminders';
      case 2:
        return 'my companion';
      default:
        return 'streak momentum';
    }
  }

  String _statsPanelSectionTitle() {
    switch (_statsPageIndex) {
      case 0:
        return 'Streak momentum';
      case 1:
        return 'Reminders';
      case 2:
        return 'My companion';
      default:
        return 'Streak momentum';
    }
  }

  String _statsPanelSectionSubtitle() {
    switch (_statsPageIndex) {
      case 0:
        return 'Tap a card to log today and grow the chain.';
      case 1:
        return 'Quick nudges for habits still pending today — tap to check in from here.';
      case 2:
        return 'Meet your companion, track bond, and open status for skins and progress.';
      default:
        return '';
    }
  }

  List<Widget> _buildHabitSectionForStatsPage(BuildContext context, int page) {
    final store = HabitStore.instance;
    if (store.habits.isEmpty) {
      if (page == 0) {
        return [
          ..._buildHabitSection(context),
          _buildStreakTodoListHeadingSection(context),
        ];
      }
      return _buildHabitSection(context);
    }
    switch (page) {
      case 0:
        return [
          _buildTodoListSection(context, store.habits),
          _buildStreakTodoListHeadingSection(context),
        ];
      case 1:
        return _buildReminderSection(context);
      case 2:
        return _buildCompanionHomeSection(context);
    }
    return [
      _buildTodoListSection(context, store.habits),
      _buildStreakTodoListHeadingSection(context),
    ];
  }

  Widget _buildTodoListSection(BuildContext context, List<Habit> habits) {
    const accent = Color(0xFF00D9FF);
    final canExpand = habits.length > _kMomentumPreviewLimit;
    final expanded = _momentumHabitListExpanded && canExpand;
    final visibleCount = expanded || !canExpand
        ? habits.length
        : _kMomentumPreviewLimit;
    final visibleHabits = habits.take(visibleCount).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _habitGrid(context, visibleHabits),
        if (canExpand) ...[
          const SizedBox(height: 6),
          Center(
            child: TextButton(
              onPressed: () {
                setState(() {
                  _momentumHabitListExpanded = !_momentumHabitListExpanded;
                });
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 1,
                ),
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              child: Text(
                _momentumHabitListExpanded ? 'Show less' : 'View more',
                style: TextStyle(
                  color: accent.withOpacity(0.95),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Shown under streak momentum habits — matches [AnimatedSwitcher] streak heading styles.
  Widget _buildStreakTodoListHeadingSection(BuildContext context) {
    const accent = Color(0xFF00D9FF);
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'To-Do list',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'One-off tasks for today — separate from your streak habits.',
            style: TextStyle(
              fontSize: 13,
              height: 1.25,
              color: Colors.white.withOpacity(0.58),
            ),
          ),
          const SizedBox(height: 14),
          ListenableBuilder(
            listenable: TodoStore.instance,
            builder: (context, _) {
              final todoStore = TodoStore.instance;
              final dayKey = todoStore.todayKey;
              void submitNew() {
                final text = _newTodoCtrl.text;
                unawaited(todoStore.addTask(text));
                _newTodoCtrl.clear();
                FocusScope.of(context).unfocus();
              }

              return Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _newTodoCtrl,
                            maxLength: 160,
                            maxLines: 1,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.92),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            cursorColor: accent,
                            decoration: InputDecoration(
                              isDense: true,
                              counterText: '',
                              hintText: 'Add a task…',
                              hintStyle: TextStyle(
                                color: Colors.white.withOpacity(0.38),
                                fontWeight: FontWeight.w500,
                              ),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.05),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                  color: Colors.white.withOpacity(0.12),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                  color: Colors.white.withOpacity(0.12),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: accent,
                                  width: 1.2,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => submitNew(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: submitNew,
                          style: TextButton.styleFrom(
                            foregroundColor: accent,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          child: const Text('Add'),
                        ),
                      ],
                    ),
                    if (todoStore.tasks.isEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'No tasks yet — add quick errands or one-offs that are not part of your streak loop.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.55),
                          fontSize: 12,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 12),
                      ...todoStore.tasks.map((task) {
                        final done = task.isDoneOn(dayKey);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => unawaited(todoStore.toggleDone(task.id)),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.04),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.08),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(top: 1),
                                      child: SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: Checkbox(
                                          value: done,
                                          activeColor: accent,
                                          checkColor: const Color(0xFF0F1023),
                                          side: BorderSide(
                                            color: Colors.white.withOpacity(0.35),
                                            width: 1.5,
                                          ),
                                          materialTapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                          visualDensity: VisualDensity.compact,
                                          onChanged: (_) => unawaited(
                                            todoStore.toggleDone(task.id),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        task.title,
                                        style: TextStyle(
                                          color: done
                                              ? Colors.white.withOpacity(0.45)
                                              : Colors.white.withOpacity(0.9),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          height: 1.3,
                                          decoration: done
                                              ? TextDecoration.lineThrough
                                              : TextDecoration.none,
                                          decorationColor: done
                                              ? Colors.white.withOpacity(0.55)
                                              : null,
                                          decorationThickness: done ? 2 : null,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () =>
                                          unawaited(todoStore.removeTask(task.id)),
                                      icon: Icon(
                                        Icons.close_rounded,
                                        size: 20,
                                        color: Colors.white.withOpacity(0.45),
                                      ),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 32,
                                        minHeight: 32,
                                      ),
                                      tooltip: 'Remove',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _buildReminderSection(BuildContext context) {
    final store = HabitStore.instance;
    final now = DateTime.now();
    final pending =
        store.habits.where((h) => !store.isCompletedOn(h.id, now)).toList()
          ..sort(
            (a, b) =>
                store.habitStreak(a.id).compareTo(store.habitStreak(b.id)),
          );

    final selectedHabitStillPending = pending.any(
      (h) => h.id == _selectedManualReminderHabit?.id,
    );
    if (!selectedHabitStillPending) {
      _selectedManualReminderHabit = null;
    }

    return [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.alarm_add_rounded,
                  color: Color(0xFF00D9FF),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Manual reminder setup',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.92),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  _formatReminderClock(now),
                  style: const TextStyle(
                    color: Color(0xFF00D9FF),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Type a pending habit name, set a time, then save the reminder.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.62),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _requestReminderPermissions(context),
                icon: const Icon(Icons.lock_open_rounded, size: 16),
                label: const Text('Enable reminder permissions'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF00D9FF),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _manualReminderHabitCtrl,
              onChanged: (_) {
                _selectedManualReminderHabit = _resolveManualReminderHabit(
                  pending,
                  _manualReminderHabitCtrl.text,
                );
              },
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Habit',
                labelStyle: TextStyle(color: Colors.white.withOpacity(0.74)),
                hintText: pending.isEmpty
                    ? 'No pending habits'
                    : 'e.g. ${pending.first.title}',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.45)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.14)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.14)),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide(color: Color(0xFF00D9FF), width: 1.1),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _manualReminderTime,
                        helpText: 'Pick reminder time',
                        builder: (ctx, child) {
                          return Theme(
                            data: Theme.of(ctx).copyWith(
                              colorScheme: Theme.of(ctx).colorScheme.copyWith(
                                primary: const Color(0xFF00D9FF),
                              ),
                            ),
                            child: child ?? const SizedBox.shrink(),
                          );
                        },
                      );
                      if (picked != null && mounted) {
                        setState(() => _manualReminderTime = picked);
                      }
                    },
                    icon: const Icon(Icons.schedule_rounded, size: 18),
                    label: Text(_formatTimeOfDay(_manualReminderTime)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white.withOpacity(0.9),
                      side: BorderSide(color: Colors.white.withOpacity(0.2)),
                      backgroundColor: Colors.white.withOpacity(0.04),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _saveManualReminder(
                      context,
                      selected: _resolveManualReminderHabit(
                        pending,
                        _manualReminderHabitCtrl.text,
                      ),
                    ),
                    icon: const Icon(
                      Icons.notifications_active_outlined,
                      size: 18,
                    ),
                    label: const Text('Set reminder'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(
                        0xFF00D9FF,
                      ).withOpacity(0.24),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.white.withOpacity(0.08),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: const Color(0xFF00D9FF).withOpacity(0.42),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _manualReminderNoteCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Note (optional): e.g. quick walk after tea',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.44)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.04),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.14)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.14)),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide(color: Color(0xFF00D9FF), width: 1.1),
                ),
              ),
            ),
            if (_manualReminders.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Upcoming manual reminders',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.78),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              for (final reminder in _manualReminders.take(3))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.alarm,
                        color: Color(0xFF00D9FF),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_formatTimeOfDay(reminder.time)} · ${reminder.habitTitle}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              reminder.note?.isNotEmpty == true
                                  ? reminder.note!
                                  : 'Added ${_formatHistoryStamp(reminder.createdAt)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.56),
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 14),
      _reminderHistoryCard(),
    ];
  }

  List<Widget> _buildCompanionHomeSection(BuildContext context) {
    return [
      ListenableBuilder(
        listenable: HabitStore.instance,
        builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Bond level',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const Spacer(),
                Text(
                  '${(HabitStore.instance.companionBondProgress * 100).round()}%',
                  style: const TextStyle(
                    color: Color(0xFF00D9FF),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: HabitStore.instance.companionBondProgress,
                minHeight: 12,
                backgroundColor: Colors.white10,
                color: const Color(0xFF00D9FF),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      _buildCompanionStrengthPanel(),
    ];
  }

  Widget _buildCompanionStrengthPanel() {
    final s = HabitStore.instance;
    final bondPct = (s.companionBondProgress * 100).round();
    final streakPower = ((s.currentStreak / 30) * 100)
        .clamp(0.0, 100.0)
        .round();
    final syncScore = ((s.totalCompletions / 500) * 100)
        .clamp(0.0, 100.0)
        .round();
    final strengthScore =
        ((bondPct * 0.6) + (streakPower * 0.25) + (syncScore * 0.15)).round();
    final tier = strengthScore >= 80
        ? 'Elite'
        : strengthScore >= 60
        ? 'Advanced'
        : strengthScore >= 35
        ? 'Rising'
        : 'Starter';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.shield_moon_rounded,
                color: Color(0xFF00D9FF),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Companion strength',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.92),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                tier,
                style: const TextStyle(
                  color: Color(0xFF00D9FF),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Strength builds from bond, streak consistency, and total habit sync.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.58),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _companionStrengthMetric(
                  icon: Icons.bolt_rounded,
                  label: 'Strength',
                  value: '$strengthScore%',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _companionStrengthMetric(
                  icon: Icons.local_fire_department_rounded,
                  label: 'Streak power',
                  value: '$streakPower%',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _companionStrengthMetric(
                  icon: Icons.sync_rounded,
                  label: 'Sync score',
                  value: '$syncScore%',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _companionStrengthMetric({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF00D9FF), size: 18),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _saveManualReminder(BuildContext context, {required Habit? selected}) {
    final habit = selected;
    final typedTitle = _manualReminderHabitCtrl.text.trim();
    if (habit == null && typedTitle.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Type a habit name first.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final habitId = habit?.id ?? '';
    final habitTitle = habit?.title ?? typedTitle;
    final note = _manualReminderNoteCtrl.text.trim();
    final now = DateTime.now();
    final reminder = _ManualReminder(
      alarmId: _alarmIdForReminder(
        createdAt: now,
        habitTitle: habitTitle,
        time: _manualReminderTime,
      ),
      habitId: habitId,
      habitTitle: habitTitle,
      time: _manualReminderTime,
      note: note.isEmpty ? null : note,
      createdAt: now,
    );
    setState(() {
      _manualReminders.insert(0, reminder);
      _reminderHistory.insert(
        0,
        _ReminderHistoryEntry(
          title: 'Manual reminder set',
          detail: '$habitTitle at ${_formatTimeOfDay(_manualReminderTime)}',
          createdAt: now,
        ),
      );
      if (_reminderHistory.length > 12) {
        _reminderHistory.removeRange(12, _reminderHistory.length);
      }
      _manualReminderHabitCtrl.clear();
      _selectedManualReminderHabit = null;
      _manualReminderNoteCtrl.clear();
    });
    unawaited(_persistRemindersState());
    unawaited(() async {
      await ReminderAlarmService.instance.requestReminderPermissions();
      final alarmOk = await ReminderAlarmService.instance.scheduleDailyReminder(
        alarmId: reminder.alarmId,
        title: reminder.habitTitle,
        time: reminder.time,
        body: reminder.note,
      );
      if (!mounted) return;
      var failDetail =
          'Open Settings → Notifications for this app and allow alerts. On Android 12+, also allow Alarms & reminders if prompted.';
      if (!alarmOk && defaultTargetPlatform == TargetPlatform.android) {
        final notifOff = await ReminderAlarmService.instance
            .androidNotificationsBlocked();
        if (notifOff) {
          failDetail =
              'Notifications are off for this app. Turn them on, then save the reminder again.';
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            alarmOk
                ? 'Reminder alarm set for $habitTitle (${_formatTimeOfDay(_manualReminderTime)})'
                : 'Reminder saved locally, but no OS alarm was scheduled. $failDetail',
          ),
          behavior: SnackBarBehavior.floating,
          action: alarmOk
              ? null
              : SnackBarAction(
                  label: 'Settings',
                  onPressed: () {
                    unawaited(
                      AppSettings.openAppSettings(
                        type: AppSettingsType.notification,
                      ),
                    );
                  },
                ),
        ),
      );
      final ok = await _saveReminderToServer(reminder);
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Saved locally, but server sync failed. Check backend/login.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        await _syncRemindersFromServer();
      }
    }());
  }

  Future<void> _requestReminderPermissions(BuildContext context) async {
    final granted = await ReminderAlarmService.instance
        .requestReminderPermissions();
    if (!context.mounted) return;
    if (!granted) {
      await AppSettings.openAppSettings(type: AppSettingsType.notification);
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          granted
              ? 'Reminder permissions enabled. Alarms can ring on time.'
              : 'Opened notification settings — enable alerts for this app, then try Set reminder again.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Habit? _resolveManualReminderHabit(List<Habit> pending, String rawInput) {
    final typed = rawInput.trim().toLowerCase();
    if (typed.isEmpty) return null;
    for (final h in pending) {
      if (h.title.trim().toLowerCase() == typed) return h;
    }
    for (final h in pending) {
      if (h.title.trim().toLowerCase().startsWith(typed)) return h;
    }
    for (final h in pending) {
      if (h.title.trim().toLowerCase().contains(typed)) return h;
    }
    return null;
  }

  Widget _reminderHistoryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.history_rounded,
                color: Color(0xFF00D9FF),
                size: 18,
              ),
              const SizedBox(width: 7),
              Text(
                'Reminder history',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_reminderHistory.isEmpty)
            Text(
              'No reminder history yet. Set or complete a reminder to see activity here.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.62),
                fontSize: 12,
              ),
            )
          else
            for (final item in _reminderHistory.take(6))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(top: 6),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF00D9FF),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            '${item.detail} · ${_formatHistoryStamp(item.createdAt)}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.58),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  String _formatReminderClock(DateTime dt) {
    final h24 = dt.hour;
    final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
    final mm = dt.minute.toString().padLeft(2, '0');
    final mer = h24 >= 12 ? 'PM' : 'AM';
    return '$h12:$mm $mer';
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final now = DateTime.now();
    return _formatReminderClock(
      DateTime(now.year, now.month, now.day, time.hour, time.minute),
    );
  }

  String _formatHistoryStamp(DateTime dt) {
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final month = months[dt.month - 1];
    return '$month ${dt.day}, ${_formatReminderClock(dt)}';
  }

  Widget _menuItem(
    IconData icon,
    String title,
    String subtitle, {
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          leading: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF00D9FF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: const Color(0xFF00D9FF)),
          ),
          title: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(color: Colors.white60),
          ),
          trailing: onTap != null
              ? const Icon(Icons.chevron_right, color: Colors.white38)
              : null,
        ),
      ),
    );
  }

  void _showCompanionStatusSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final bottomInset = MediaQuery.paddingOf(ctx).bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: DraggableScrollableSheet(
            initialChildSize: 0.72,
            minChildSize: 0.45,
            maxChildSize: 0.94,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF1A1B3A),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 24,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Companion Status',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white70,
                            ),
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                        children: [
                          _companionStatusMainBox(),
                          const SizedBox(height: 20),
                          _companionStatusSectionTitle('Vitals'),
                          const SizedBox(height: 10),
                          _companionStatusVitalsRow(),
                          const SizedBox(height: 22),
                          _companionStatusSectionTitle('Skins & accessories'),
                          const SizedBox(height: 10),
                          _companionStatusAccessoryGrid(),
                          const SizedBox(height: 20),
                          _companionStatusSectionTitle('Next unlocks'),
                          const SizedBox(height: 10),
                          _companionStatusUnlocksList(),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _companionStatusSectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _companionStatusMainBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF00D9FF).withOpacity(0.15),
            const Color(0xFF6A5CFF).withOpacity(0.12),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xFF00D9FF).withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF00D9FF).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.pets,
                  color: Color(0xFF00D9FF),
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      HabitStore.instance.companionFormName,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Stage · ${HabitStore.instance.companionStageLabel}',
                      style: TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF00D9FF).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Lv. ${HabitStore.instance.companionLevel}',
                  style: const TextStyle(
                    color: Color(0xFF00D9FF),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Bond level',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: HabitStore.instance.companionBondProgress,
              minHeight: 10,
              backgroundColor: Colors.white10,
              color: const Color(0xFF00D9FF),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(HabitStore.instance.companionBondProgress * 100).round()}% bond · grows with check-ins',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _companionStatusVitalsRow() {
    Widget chip(String label, String value, IconData icon) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            children: [
              Icon(icon, color: const Color(0xFF00D9FF), size: 22),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        chip('Mood', 'Happy', Icons.sentiment_satisfied_alt_outlined),
        const SizedBox(width: 10),
        chip('Energy', '82%', Icons.bolt_outlined),
        const SizedBox(width: 10),
        chip('XP today', '+120', Icons.stars_outlined),
      ],
    );
  }

  Widget _buildAnalogReminderClock(DateTime now, {double size = 128}) {
    final minuteAngle =
        (2 * math.pi) * ((now.minute + now.second / 60.0) / 60.0);
    final hourAngle =
        (2 * math.pi) * (((now.hour % 12) + now.minute / 60.0) / 12.0);
    final secondAngle = (2 * math.pi) * (now.second / 60.0);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            const Color(0xFF00D9FF).withOpacity(0.18),
            const Color(0xFF0F1023).withOpacity(0.92),
          ],
          stops: const [0.18, 1.0],
        ),
        border: Border.all(
          color: const Color(0xFF00D9FF).withOpacity(0.55),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00D9FF).withOpacity(0.25),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (var i = 0; i < 12; i++)
            Transform.rotate(
              angle: (2 * math.pi * i) / 12,
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  margin: EdgeInsets.only(top: size * 0.08),
                  width: 2,
                  height: i % 3 == 0 ? 9 : 6,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(i % 3 == 0 ? 0.9 : 0.55),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ),
          _clockHand(
            angle: hourAngle,
            length: size * 0.24,
            thickness: 3.2,
            color: Colors.white,
          ),
          _clockHand(
            angle: minuteAngle,
            length: size * 0.34,
            thickness: 2.4,
            color: const Color(0xFF9FEFFF),
          ),
          _clockHand(
            angle: secondAngle,
            length: size * 0.38,
            thickness: 1.3,
            color: const Color(0xFFFFB74D),
          ),
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF00D9FF),
            ),
          ),
        ],
      ),
    );
  }

  Widget _clockHand({
    required double angle,
    required double length,
    required double thickness,
    required Color color,
  }) {
    return Transform.rotate(
      angle: angle - math.pi / 2,
      child: Align(
        alignment: Alignment.center,
        child: Container(
          width: length,
          height: thickness,
          margin: EdgeInsets.only(left: length * 0.18),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      ),
    );
  }

  Widget _companionStatusAccessoryGrid() {
    final items = [
      ('Crown', Icons.emoji_events_outlined, true),
      ('Wings', Icons.flutter_dash, false),
      ('Aura', Icons.blur_circular_outlined, false),
      ('Collar', Icons.circle_outlined, true),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileW = math.max(0.0, (constraints.maxWidth - 10) / 2);
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: items.map((e) {
            final unlocked = e.$3;
            return SizedBox(
              width: tileW,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: unlocked
                        ? const Color(0xFF00D9FF).withOpacity(0.4)
                        : Colors.white12,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      e.$2,
                      color: unlocked
                          ? const Color(0xFF00D9FF)
                          : Colors.white30,
                      size: 26,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.$1,
                            style: TextStyle(
                              color: unlocked ? Colors.white : Colors.white38,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            unlocked ? 'Equipped' : 'Locked · 500 pts',
                            style: TextStyle(
                              color: unlocked ? Colors.white54 : Colors.white30,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _companionStatusUnlocksList() {
    final rows = [
      ('Teen Dragon form', 'Reach companion Lv. 2'),
      ('Adult Dragon form', 'Reach companion Lv. 3'),
      ('Monster Dragon form', 'Reach companion Lv. 4'),
    ];
    return Column(
      children: rows.map((r) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.lock_open_outlined,
                  color: Color(0xFF00D9FF),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.$1,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        r.$2,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCompanionVideoFrame({bool showLiveVideo = true}) {
    _scheduleCompanionVideoResyncIfNeeded();
    const cyan = Color(0xFF00D9FF);
    return Center(
      child: Container(
        width: 220,
        height: 220,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [cyan, Color(0xFF6A5CFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: cyan.withOpacity(0.25),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Container(
            color: const Color(0xFF10142B),
            child: !showLiveVideo
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'Video plays in the companion panel above while it’s open.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.62),
                          fontSize: 12,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                : _babyDragonController.value.hasError
                ? _unsupportedVideoFallback(compact: false)
                : _babyDragonController.value.isInitialized
                ? AspectRatio(
                    aspectRatio: _babyDragonController.value.aspectRatio,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Positioned.fill(
                          child: IgnorePointer(
                            ignoring: true,
                            child: _isRadialMenuOpen
                                ? Container(
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF10142B,
                                      ).withOpacity(0.82),
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Colors.white.withOpacity(0.04),
                                          Colors.black.withOpacity(0.18),
                                        ],
                                      ),
                                    ),
                                  )
                                : VideoPlayer(_babyDragonController),
                          ),
                        ),
                        // Opaque to hit-testing so the parent scroll view receives drags
                        // (IgnorePointer on the texture alone can leave "nothing" to hit).
                        Positioned.fill(
                          child: Listener(
                            behavior: HitTestBehavior.translucent,
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ],
                    ),
                  )
                : const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: cyan,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildGamificationSection() {
    return ListenableBuilder(
      listenable: HabitStore.instance,
      builder: (context, _) {
        final s = HabitStore.instance;
        final pts = s.totalPoints;
        final lvl = s.level;
        final activeHabits = s.habits.length;
        final totalCheckIns = s.totalCompletions;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Your progress",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Points & level from your latest check-ins.",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF00D9FF).withOpacity(0.2),
                      ),
                      child: const Icon(
                        Icons.person,
                        size: 20,
                        color: Color(0xFF00D9FF),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$activeHabits active habit${activeHabits == 1 ? '' : 's'} · $totalCheckIns total check-ins',
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$pts pts',
                          style: const TextStyle(
                            color: Color(0xFF00D9FF),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Level $lvl',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildHabitSection(BuildContext context) {
    final store = HabitStore.instance;
    if (store.habits.isEmpty) {
      return [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'No habits yet',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap + for the activity wheel — pick a preset or tap Custom to type your habit (name, category, notes, repeat). Tap a card to mark today done.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.65),
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              TextButton.icon(
                onPressed: _openActivityRadialMenu,
                icon: const Icon(
                  Icons.add_circle_outline,
                  color: Color(0xFF00D9FF),
                ),
                label: const Text(
                  'Add habit',
                  style: TextStyle(
                    color: Color(0xFF00D9FF),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ];
    }
    final canExpand = store.habits.length > _kTodoPreviewLimit;
    final visibleCount = _showAllHomeHabits || !canExpand
        ? store.habits.length
        : _kTodoPreviewLimit;
    final visibleHabits = store.habits
        .take(visibleCount)
        .toList(growable: false);

    return [
      _habitGrid(context, visibleHabits),
      if (canExpand) ...[
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              setState(() => _showAllHomeHabits = !_showAllHomeHabits);
            },
            child: Text(
              _showAllHomeHabits ? 'Show less' : 'View more',
              style: const TextStyle(
                color: Color(0xFF00D9FF),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    ];
  }

  /// Habit list on the home panel — full-width row cards (not a grid).
  Widget _habitGrid(BuildContext context, List<Habit> habits) {
    return ListView.separated(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: habits.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) => _habitTile(context, habits[index]),
    );
  }

  static const Color _kHabitCardTeal = Color(0xFF2DD4BF);

  Widget _habitTile(BuildContext context, Habit h) {
    final store = HabitStore.instance;
    final done = store.isCompletedOn(h.id, DateTime.now());
    final streak = store.habitStreak(h.id);
    final icon = _iconForHabitCategory(h.category);
    final categoryTint = _accentForHabitCategory(h.category);
    const radius = 22.0;
    const pad = 18.0;
    const stripeW = 14.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: () => store.toggleCompleteToday(h.id),
        onLongPress: () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF1A1B3A),
              title: const Text(
                'Remove habit?',
                style: TextStyle(color: Colors.white),
              ),
              content: Text(
                'Delete “${h.title}” and its history?',
                style: TextStyle(color: Colors.white.withOpacity(0.8)),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Delete'),
                ),
              ],
            ),
          );
          if (ok == true) await store.removeHabit(h.id);
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.45),
                blurRadius: 20,
                offset: const Offset(0, 10),
                spreadRadius: -4,
              ),
              if (done)
                BoxShadow(
                  color: _kHabitCardTeal.withOpacity(0.22),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                  spreadRadius: -2,
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0F1628),
                    Color(0xFF121C32),
                    Color(0xFF152A45),
                  ],
                  stops: [0.0, 0.45, 1.0],
                ),
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 16, 8, 16),
                      child: Container(
                        width: stripeW,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(stripeW / 2),
                          color: done ? null : const Color(0xFF05070C),
                          gradient: done
                              ? LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color.lerp(
                                      categoryTint,
                                      Colors.white,
                                      0.42,
                                    )!,
                                    categoryTint,
                                    Color.lerp(
                                      categoryTint,
                                      Colors.black,
                                      0.38,
                                    )!,
                                  ],
                                )
                              : null,
                          boxShadow: done
                              ? [
                                  BoxShadow(
                                    color: categoryTint.withOpacity(0.42),
                                    blurRadius: 14,
                                    spreadRadius: -2,
                                    offset: const Offset(2, 0),
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(pad, pad, 14, pad),
                        child: Row(
                          children: [
                            Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    categoryTint.withOpacity(0.32),
                                    categoryTint.withOpacity(0.14),
                                    const Color(0xFF0D2830).withOpacity(0.85),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: categoryTint.withOpacity(0.72),
                                  width: 1.75,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: categoryTint.withOpacity(0.28),
                                    blurRadius: 16,
                                    offset: const Offset(0, 5),
                                  ),
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.35),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Icon(
                                icon,
                                color: Color.lerp(
                                  Colors.white,
                                  categoryTint,
                                  0.15,
                                ),
                                size: 32,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    h.title,
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      height: 1.2,
                                      letterSpacing: -0.2,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Streak: $streak days',
                                    style: GoogleFonts.inter(
                                      color: Colors.white.withOpacity(0.48),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      height: 1.2,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 48,
                              height: 48,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: done ? categoryTint : Colors.transparent,
                                border: Border.all(
                                  color: categoryTint,
                                  width: 2.5,
                                ),
                                boxShadow: done
                                    ? [
                                        BoxShadow(
                                          color: categoryTint.withOpacity(0.45),
                                          blurRadius: 12,
                                          spreadRadius: 0,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: done
                                  ? const Icon(
                                      Icons.check_rounded,
                                      color: Colors.white,
                                      size: 26,
                                    )
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showStatsPanel() {
    unawaited(_refreshStatsCacheOnServer());
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.74,
          minChildSize: 0.42,
          maxChildSize: 0.94,
          expand: false,
          builder: (context, controller) {
            return _StatsInsightSheet(scrollController: controller);
          },
        );
      },
    );
  }

  Future<void> _refreshStatsCacheOnServer() async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) return;
    try {
      await http.get(
        Uri.parse('${AuthService.baseurl}/api/me/stats-cache?refresh=1'),
        headers: {
          'content-type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
    } catch (e, st) {
      debugPrint('stats refresh: $e\n$st');
    }
  }

  void _showCalendarPanel() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.76,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, controller) {
            return _CalendarOrbitSheet(scrollController: controller);
          },
        );
      },
    );
  }

  void _showSocialPanel() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.76,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, controller) {
            return _SocialArenaSheet(scrollController: controller);
          },
        );
      },
    );
  }

  void _onSocialNavTap() {
    if (_isSocialTemporarilyLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Social is temporarily locked')),
      );
      return;
    }
    _showSocialPanel();
  }

  Widget _buildBottomNavBar() {
    final isSocialLocked = _isSocialTemporarilyLocked;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    const navRadius = 30.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(navRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            constraints: const BoxConstraints(minHeight: 72, maxHeight: 96),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(navRadius),
              border: Border.all(
                width: 1,
                color: Colors.white.withValues(alpha: 0.14),
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.14),
                  _kHomeNavChromeBg.withValues(alpha: 0.5),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF000000).withValues(alpha: 0.45),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _navItem(Icons.home, "Home", true),
                  _navItem(
                    Icons.pie_chart,
                    "stats",
                    false,
                    onTap: _showStatsPanel,
                  ),
                  const SizedBox(width: 50),
                  _navItem(
                    Icons.calendar_today,
                    "Calendar",
                    false,
                    onTap: _showCalendarPanel,
                  ),
                  _navItem(
                    isSocialLocked
                        ? Icons.lock_outline_rounded
                        : Icons.groups_rounded,
                    "Social",
                    false,
                    onTap: _onSocialNavTap,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(
    IconData icon,
    String label,
    bool isActive, {
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isActive ? const Color(0xFF00D9FF) : Colors.white,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isActive ? const Color(0xFF00D9FF) : Colors.white,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- CALENDAR ORBIT (modal sheet) ---

class _CalendarOrbitSheet extends StatefulWidget {
  const _CalendarOrbitSheet({required this.scrollController});

  final ScrollController scrollController;

  @override
  State<_CalendarOrbitSheet> createState() => _CalendarOrbitSheetState();
}

class _CalendarOrbitSheetState extends State<_CalendarOrbitSheet> {
  late DateTime _visibleMonth;
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month, 1);
    _selectedDay = DateTime(now.year, now.month, now.day);
    HabitStore.instance.addListener(_onStore);
  }

  void _onStore() => setState(() {});

  @override
  void dispose() {
    HabitStore.instance.removeListener(_onStore);
    super.dispose();
  }

  void _changeMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(
        _visibleMonth.year,
        _visibleMonth.month + delta,
        1,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF00D9FF);
    final monthLabel = _monthName(_visibleMonth.month);
    final firstWeekday = _visibleMonth.weekday; // Mon=1
    final leading = firstWeekday - 1;
    final daysInMonth = DateUtils.getDaysInMonth(
      _visibleMonth.year,
      _visibleMonth.month,
    );
    final totalCells = ((leading + daysInMonth + 6) ~/ 7) * 7;
    final selectedEvents = _selectedDay == null
        ? const <String>[]
        : HabitStore.instance.dayLabels(_selectedDay!);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF131830),
            const Color(0xFF0B1021),
            const Color(0xFF070B15),
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        border: Border.all(color: accent.withOpacity(0.22)),
      ),
      child: ListView(
        controller: widget.scrollController,
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
        children: [
          Center(
            child: Container(
              width: 52,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Calendar Orbit',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  border: Border.all(color: accent.withOpacity(0.5)),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Plan+Track',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                colors: [Color(0xFF1B2742), Color(0xFF142035)],
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => _changeMonth(-1),
                      icon: const Icon(Icons.chevron_left, color: Colors.white),
                    ),
                    Expanded(
                      child: Text(
                        '$monthLabel ${_visibleMonth.year}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => _changeMonth(1),
                      icon: const Icon(
                        Icons.chevron_right,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    _WeekTag('M'),
                    _WeekTag('T'),
                    _WeekTag('W'),
                    _WeekTag('T'),
                    _WeekTag('F'),
                    _WeekTag('S'),
                    _WeekTag('S'),
                  ],
                ),
                const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: totalCells,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 6,
                  ),
                  itemBuilder: (context, i) {
                    final dayNum = i - leading + 1;
                    if (dayNum < 1 || dayNum > daysInMonth) {
                      return const SizedBox.shrink();
                    }
                    final day = DateTime(
                      _visibleMonth.year,
                      _visibleMonth.month,
                      dayNum,
                    );
                    final isToday = DateUtils.isSameDay(day, DateTime.now());
                    final isSelected =
                        _selectedDay != null &&
                        DateUtils.isSameDay(_selectedDay!, day);
                    final hasEvent =
                        HabitStore.instance.countCompletedOn(day) > 0;
                    return InkWell(
                      borderRadius: BorderRadius.circular(11),
                      onTap: () => setState(() => _selectedDay = day),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(11),
                          color: isSelected
                              ? accent.withOpacity(0.2)
                              : Colors.white.withOpacity(0.04),
                          border: Border.all(
                            color: isSelected
                                ? accent
                                : (isToday
                                      ? const Color(0xFFFF8A00).withOpacity(0.7)
                                      : Colors.white10),
                          ),
                        ),
                        child: Stack(
                          children: [
                            Center(
                              child: Text(
                                '$dayNum',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.95),
                                  fontWeight: isSelected
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                ),
                              ),
                            ),
                            if (hasEvent)
                              Positioned(
                                bottom: 4,
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: Container(
                                    width: 5,
                                    height: 5,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF00D9FF),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF121A2C),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedDay == null
                      ? 'Selected Day'
                      : '${_selectedDay!.day} ${_monthName(_selectedDay!.month)} ${_selectedDay!.year}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                if (selectedEvents.isEmpty)
                  Text(
                    'No habit check-ins logged this day. Complete habits from Home — they appear here.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.62),
                      fontSize: 12,
                    ),
                  )
                else
                  ...selectedEvents.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 5),
                            child: Icon(
                              Icons.fiber_manual_record,
                              size: 8,
                              color: Color(0xFF00D9FF),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              e,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.88),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekTag extends StatelessWidget {
  const _WeekTag(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white.withOpacity(0.5),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String _monthName(int m) {
  const names = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return names[(m - 1).clamp(0, 11)];
}

// --- STATS INSIGHT (modal sheet) — holographic “pulse observatory” ---

class _StatsInsightSheet extends StatefulWidget {
  const _StatsInsightSheet({required this.scrollController});

  final ScrollController scrollController;

  @override
  State<_StatsInsightSheet> createState() => _StatsInsightSheetState();
}

class _StatsInsightSheetState extends State<_StatsInsightSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep;

  static const _mint = Color(0xFF5DFFC4);
  static const _violet = Color(0xFF9D7DFF);
  static const _deep = Color(0xFF0A1220);

  @override
  void initState() {
    super.initState();
    _sweep = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    HabitStore.instance.addListener(_onHabits);
  }

  void _onHabits() => setState(() {});

  @override
  void dispose() {
    HabitStore.instance.removeListener(_onHabits);
    _sweep.dispose();
    super.dispose();
  }

  void _showPulseHistory() {
    final s = HabitStore.instance;
    final counts = s.last7DayCheckinCounts();
    final avgPerDay = counts.isEmpty
        ? 0.0
        : counts.reduce((a, b) => a + b) / counts.length;
    final now = DateTime.now();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0C1426),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: _mint.withOpacity(0.22)),
          ),
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'My pulse history',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Previous 7 days snapshot',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 14),
              ...List<Widget>.generate(7, (i) {
                final day = now.subtract(Duration(days: 6 - i));
                final c = counts[i];
                final percent = s.habits.isEmpty
                    ? 0
                    : ((c / s.habits.length) * 100).round();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 44,
                          child: Text(
                            '${day.day}/${day.month}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$percent% completion',
                            style: TextStyle(
                              color: _mint.withOpacity(0.9),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          '$c hits',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.75),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 4),
              Text(
                'Avg ${avgPerDay.toStringAsFixed(avgPerDay >= 10 ? 0 : 1)} check-ins/day · Current streak ${s.currentStreak} days',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.62),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = HabitStore.instance;
    final score = (s.todayProgressFraction * 100).round();
    final ringProgress = (score / 100.0).clamp(0.0, 1.0);
    final completedToday = s.completedTodayCount;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [const Color(0xFF0E1A32), _deep, const Color(0xFF060A12)],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: _mint.withOpacity(0.22)),
        boxShadow: [
          BoxShadow(
            color: _violet.withOpacity(0.15),
            blurRadius: 40,
            offset: const Offset(0, -12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -60,
            right: -40,
            child: IgnorePointer(
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [_mint.withOpacity(0.12), Colors.transparent],
                  ),
                ),
              ),
            ),
          ),
          ListView(
            controller: widget.scrollController,
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 36),
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'INSIGHT LAB',
                          style: TextStyle(
                            color: _mint.withOpacity(0.85),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ShaderMask(
                          blendMode: BlendMode.srcIn,
                          shaderCallback: (b) => const LinearGradient(
                            colors: [Color(0xFFE8F4FF), _mint],
                          ).createShader(b),
                          child: const Text(
                            'Your pulse',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              height: 1.05,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: _showPulseHistory,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.12),
                        ),
                        color: const Color(0xFF152238).withOpacity(0.9),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.history_rounded,
                            size: 16,
                            color: _violet.withOpacity(0.9),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'My history',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Center(
                child: SizedBox(
                  height: 200,
                  width: 200,
                  child: AnimatedBuilder(
                    animation: _sweep,
                    builder: (context, _) {
                      return CustomPaint(
                        painter: _StatsPulseRingPainter(
                          sweep: _sweep.value,
                          progress: ringProgress,
                          accent: _mint,
                          secondary: _violet,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$score',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.95),
                                  fontSize: 48,
                                  fontWeight: FontWeight.w200,
                                  height: 1,
                                  shadows: [
                                    Shadow(
                                      color: _mint.withOpacity(0.5),
                                      blurRadius: 24,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'TODAY COMPLETION',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.45),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                s.trendLabel(),
                                style: TextStyle(
                                  color: _mint.withOpacity(0.9),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _statGlassTile(
                      'Streak',
                      '${s.currentStreak}',
                      'days',
                      Icons.local_fire_department,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _statGlassTile(
                      'Done today',
                      '$completedToday',
                      'hits',
                      Icons.check_circle_outline,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _statGlassTile(
                      'Check-ins',
                      '${s.totalCompletions}',
                      'all',
                      Icons.hourglass_top,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _sectionLabel('MOMENTUM', Icons.show_chart),
              const SizedBox(height: 10),
              _momentumStrip(),
              const SizedBox(height: 22),
              _sectionLabel('RHYTHM MAP', Icons.grid_on),
              const SizedBox(height: 10),
              _heatWeekRow(),
              const SizedBox(height: 8),
              Text(
                'Green = lighter day   ·   Red = you did more',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.42),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 22),
              _sectionLabel('SPLIT', Icons.pie_chart_outline),
              const SizedBox(height: 10),
              _categorySplit(),
              const SizedBox(height: 20),
              _insightNudge(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: _violet.withOpacity(0.85)),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: Colors.white.withOpacity(0.75),
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  Widget _statGlassTile(
    String label,
    String value,
    String unit,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1A2A44).withOpacity(0.95),
            const Color(0xFF0F1828).withOpacity(0.98),
          ],
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: _mint.withOpacity(0.75), size: 18),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                unit,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.45),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.45),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  String _weekdayCompact(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'M';
      case DateTime.tuesday:
        return 'T';
      case DateTime.wednesday:
        return 'W';
      case DateTime.thursday:
        return 'Th';
      case DateTime.friday:
        return 'F';
      case DateTime.saturday:
        return 'Sa';
      case DateTime.sunday:
        return 'Su';
      default:
        return '-';
    }
  }

  Widget _momentumStrip() {
    final counts = HabitStore.instance.last7DayCheckinCounts();
    final maxCount = counts.fold<int>(0, (m, v) => v > m ? v : m);
    final avgPerDay = counts.isEmpty
        ? 0.0
        : counts.reduce((a, b) => a + b) / counts.length;
    final today = DateTime.now();
    final labels = List<String>.generate(7, (i) {
      final d = today.subtract(Duration(days: 6 - i));
      return _weekdayCompact(d.weekday);
    });
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0xFF111C30).withOpacity(0.85),
        border: Border.all(color: _violet.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Daily completion',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 11,
                ),
              ),
              Text(
                'avg ${avgPerDay.toStringAsFixed(avgPerDay >= 10 ? 0 : 1)} check-ins/day',
                style: TextStyle(
                  color: _mint.withOpacity(0.9),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(7, (i) {
              final normalized = maxCount == 0
                  ? 0.0
                  : (counts[i] / maxCount).clamp(0.0, 1.0);
              final h = counts[i] == 0 ? 2.0 : math.max(8.0, 56.0 * normalized);
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        height: h,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              _violet.withOpacity(0.25 + 0.35 * normalized),
                              _mint.withOpacity(0.45 + 0.35 * normalized),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _mint.withOpacity(0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        labels[i],
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _heatWeekRow() {
    // 0 = little done (bright green) → 1 = a lot done (bright red)
    final counts = HabitStore.instance.last7DayCheckinCounts();
    final maxCount = counts.fold<int>(0, (m, v) => v > m ? v : m);
    const brightGreen = Color(0xFF00FF88);
    const brightRed = Color(0xFFFF3355);
    return Row(
      children: List.generate(7, (i) {
        final t = maxCount == 0 ? 0.0 : (counts[i] / maxCount).clamp(0.0, 1.0);
        final hub = Color.lerp(brightGreen, brightRed, t)!;
        final glow = 0.35 + 0.55 * t;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: hub.withOpacity(0.35 + 0.25 * t)),
                  gradient: RadialGradient(
                    colors: [hub.withOpacity(glow), const Color(0xFF0D1526)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: hub.withOpacity(0.12 + 0.2 * t),
                      blurRadius: 10,
                      spreadRadius: 0,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _categorySplit() {
    final fr = HabitStore.instance.categoryCompletionFractionsLast7();
    final items = <(String, IconData, double, Color)>[
      (
        'Focus',
        Icons.center_focus_strong,
        fr['focus'] ?? 0,
        const Color(0xFF5DFFC4),
      ),
      ('Move', Icons.directions_run, fr['move'] ?? 0, const Color(0xFF7AB6FF)),
      ('Mind', Icons.spa_outlined, fr['mind'] ?? 0, const Color(0xFF9D7DFF)),
      ('Learn', Icons.menu_book, fr['learn'] ?? 0, const Color(0xFFFFB86A)),
      ('Gym', Icons.fitness_center, fr['gym'] ?? 0, const Color(0xFFFF6B8A)),
      (
        'Nutrition',
        Icons.restaurant_menu,
        fr['nutrition'] ?? 0,
        const Color(0xFF6BCB77),
      ),
      (
        'Sleep',
        Icons.bedtime_outlined,
        fr['sleep'] ?? 0,
        const Color(0xFFB388FF),
      ),
      (
        'Social',
        Icons.groups_outlined,
        fr['social'] ?? 0,
        const Color(0xFFFFAB40),
      ),
      (
        'Creative',
        Icons.palette_outlined,
        fr['creative'] ?? 0,
        const Color(0xFFFF7AD9),
      ),
    ];
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'Based on last 7 days of check-ins',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 11,
              ),
            ),
          ),
        ),
        for (final (name, icon, pct, col) in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Icon(icon, color: col.withOpacity(0.9), size: 20),
                const SizedBox(width: 8),
                SizedBox(
                  width: 68,
                  child: Text(
                    name,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.82),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        height: 10,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(99),
                          color: Colors.white.withOpacity(0.06),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: pct,
                        child: Container(
                          height: 10,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(99),
                            gradient: LinearGradient(
                              colors: [col.withOpacity(0.2), col],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: col.withOpacity(0.35),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 40,
                  child: Text(
                    '${(pct * 100).round()}%',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _insightNudge() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _mint.withOpacity(0.25)),
        gradient: LinearGradient(
          colors: [_mint.withOpacity(0.08), _violet.withOpacity(0.06)],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _violet.withOpacity(0.2),
            ),
            child: Icon(
              Icons.auto_awesome,
              color: _mint.withOpacity(0.95),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Next win',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.45),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  HabitStore.instance.insightNudgeBody(),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.82),
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsPulseRingPainter extends CustomPainter {
  _StatsPulseRingPainter({
    required this.sweep,
    required this.progress,
    required this.accent,
    required this.secondary,
  });

  final double sweep;
  final double progress;
  final Color accent;
  final Color secondary;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 10;

    final bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..color = Colors.white.withOpacity(0.06);

    canvas.drawCircle(c, r, bg);

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: 3 * math.pi / 2,
        colors: [secondary, accent, secondary],
        stops: const [0.0, 0.5, 1.0],
        transform: GradientRotation(sweep * 2 * math.pi),
      ).createShader(Rect.fromCircle(center: c, radius: r));

    final p = progress.clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      2 * math.pi * p,
      false,
      arcPaint,
    );

    final tick = -math.pi / 2 + 2 * math.pi * p * sweep;
    final dot = Offset(c.dx + r * math.cos(tick), c.dy + r * math.sin(tick));
    canvas.drawCircle(dot, 7, Paint()..color = accent.withOpacity(0.95));
    canvas.drawCircle(
      dot,
      12,
      Paint()
        ..color = accent.withOpacity(0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _StatsPulseRingPainter oldDelegate) {
    return oldDelegate.sweep != sweep || oldDelegate.progress != progress;
  }
}

// --- SOCIAL ARENA (modal sheet) — high-energy “glitch rave” layout ---

class _SocialArenaSheet extends StatefulWidget {
  const _SocialArenaSheet({required this.scrollController});

  final ScrollController scrollController;

  @override
  State<_SocialArenaSheet> createState() => _SocialArenaSheetState();
}

class _SocialArenaSheetState extends State<_SocialArenaSheet>
    with TickerProviderStateMixin {
  late final AnimationController _pulse;
  late final AnimationController _blink;

  static const _magenta = Color(0xFFFF00C8);
  static const _cyan = Color(0xFF00F5FF);
  static const _lime = Color(0xFFBFFF00);
  static const _voidBg = Color(0xFF070014);

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
    _blink = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    )..repeat(reverse: true);
    HabitStore.instance.addListener(_onHabitData);
  }

  void _onHabitData() => setState(() {});

  String _formatPts(int p) {
    if (p >= 1000) return '${(p / 1000).toStringAsFixed(1)}K';
    return '$p';
  }

  @override
  void dispose() {
    HabitStore.instance.removeListener(_onHabitData);
    _pulse.dispose();
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final habit = HabitStore.instance;
    final leaderboardRows = <({String name, int points})>[
      (name: habit.displayName, points: habit.totalPoints),
    ];
    return ClipPath(
      clipper: const _SocialArenaTopClipper(),
      child: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: _magenta.withOpacity(0.25),
              blurRadius: 40,
              spreadRadius: -4,
              offset: const Offset(-6, -4),
            ),
            BoxShadow(
              color: _cyan.withOpacity(0.2),
              blurRadius: 36,
              spreadRadius: -6,
              offset: const Offset(8, 0),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF120028), _voidBg, Color(0xFF0A1628)],
                  stops: [0.0, 0.45, 1.0],
                ),
              ),
            ),
            Positioned(
              top: -80,
              right: -60,
              child: IgnorePointer(
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [_magenta.withOpacity(0.35), Colors.transparent],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 120,
              left: -100,
              child: IgnorePointer(
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [_cyan.withOpacity(0.22), Colors.transparent],
                    ),
                  ),
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) {
                return Positioned.fill(
                  child: CustomPaint(
                    painter: _ArenaGridPainter(phase: _pulse.value),
                  ),
                );
              },
            ),
            ListView(
              controller: widget.scrollController,
              padding: const EdgeInsets.fromLTRB(16, 34, 16, 32),
              children: [
                Center(
                  child: Container(
                    width: 120,
                    height: 6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      gradient: LinearGradient(
                        colors: [
                          _magenta.withOpacity(0.9),
                          _cyan.withOpacity(0.9),
                          _lime.withOpacity(0.85),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _cyan.withOpacity(0.5),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Transform.rotate(
                        angle: -0.035,
                        alignment: Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _glitchTitle('SOCIAL'),
                            Transform.translate(
                              offset: const Offset(18, -6),
                              child: ShaderMask(
                                blendMode: BlendMode.srcIn,
                                shaderCallback: (bounds) =>
                                    const LinearGradient(
                                      colors: [_lime, _cyan],
                                    ).createShader(bounds),
                                child: const Text(
                                  'ARENA',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 36,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2,
                                    height: 0.9,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'STREAKS • DUELS • SQUAD MAYHEM',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.55),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    AnimatedBuilder(
                      animation: _blink,
                      builder: (context, _) {
                        final o = 0.35 + 0.65 * _blink.value;
                        return Opacity(
                          opacity: o,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withOpacity(0.22),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: Colors.redAccent.withOpacity(0.85),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.redAccent.withOpacity(0.45),
                                  blurRadius: 14,
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.fiber_manual_record,
                                  color: Colors.redAccent,
                                  size: 10,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'LIVE',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 11,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _riotTag('@nova_hustle'),
                      _riotTag('TEAM: VOLT'),
                      _riotTag('CHALLENGE #882'),
                      _riotTag('XP x2 BOOST'),
                      _riotTag('RIVAL: KAI'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: _skewStat('#1', 'RANK', _magenta)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _skewStat(
                        _formatPts(habit.totalPoints),
                        'POINTS',
                        _cyan,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _skewStat(
                        '${habit.totalCompletions}',
                        'DONE',
                        _lime,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _ticketChallengeCard(),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Container(width: 4, height: 22, color: _lime),
                    const SizedBox(width: 10),
                    const Text(
                      'SQUAD BATTLES',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _battleRow(
                  'Morning Movers',
                  'You vs 4 • focus sprint',
                  '2H',
                  Icons.directions_run,
                  0,
                ),
                _battleRow(
                  'Mindful Crew',
                  'Meditation relay',
                  'TONIGHT',
                  Icons.spa_outlined,
                  1,
                ),
                _battleRow(
                  'Readers Club',
                  'Pages gauntlet',
                  'WKND',
                  Icons.menu_book,
                  2,
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Container(width: 4, height: 22, color: _cyan),
                    const SizedBox(width: 10),
                    const Icon(Icons.leaderboard, color: _lime, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'LEADERBOARD',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Your score from habits on this device. Multiplayer ranks when you add an API.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.45),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 12),
                ...List<Widget>.generate(leaderboardRows.length, (i) {
                  final row = leaderboardRows[i];
                  return _leaderboardRow(
                    rank: i + 1,
                    name: row.name,
                    points: row.points,
                  );
                }),
                const SizedBox(height: 20),
                const Text(
                  'DEPLOY',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: const [
                    _ArenaDeployChip(icon: Icons.group_add, label: 'INVITE'),
                    _ArenaDeployChip(icon: Icons.emoji_events, label: 'DUEL'),
                    _ArenaDeployChip(
                      icon: Icons.chat_bubble_outline,
                      label: 'SQUAD CHAT',
                    ),
                    _ArenaDeployChip(
                      icon: Icons.flag_outlined,
                      label: 'SET GOAL',
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _glitchTitle(String text) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 2,
          top: 1,
          child: Text(
            text,
            style: _titleStyle.copyWith(color: _magenta.withOpacity(0.65)),
          ),
        ),
        Positioned(
          left: -2,
          top: -1,
          child: Text(
            text,
            style: _titleStyle.copyWith(color: _cyan.withOpacity(0.7)),
          ),
        ),
        Text(text, style: _titleStyle),
      ],
    );
  }

  static const TextStyle _titleStyle = TextStyle(
    color: Colors.white,
    fontSize: 36,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.5,
    height: 0.9,
    shadows: [
      Shadow(color: Colors.black87, blurRadius: 8, offset: Offset(0, 2)),
    ],
  );

  Widget _riotTag(String label) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A0F2E),
        border: Border.all(color: _cyan.withOpacity(0.35)),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _skewStat(String value, String label, Color accent) {
    return Transform(
      transform: Matrix4.skewX(-0.12)..translate(-4.0, 0.0),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1E1038).withOpacity(0.95),
              const Color(0xFF0D0818).withOpacity(0.98),
            ],
          ),
          border: Border(
            left: BorderSide(color: accent, width: 3),
            top: BorderSide(color: Colors.white.withOpacity(0.08)),
            bottom: BorderSide(color: Colors.white.withOpacity(0.06)),
          ),
        ),
        child: Column(
          children: [
            Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: accent,
                fontSize: 17,
                fontWeight: FontWeight.w900,
                shadows: [
                  Shadow(color: accent.withOpacity(0.5), blurRadius: 10),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ticketChallengeCard() {
    final s = HabitStore.instance;
    final tp = s.todayProgressFraction.clamp(0.0, 1.0);
    final left = s.habits
        .where((h) => !s.isCompletedOn(h.id, DateTime.now()))
        .length;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xE6160A24),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(22),
          bottomLeft: Radius.circular(22),
          bottomRight: Radius.circular(4),
        ),
        border: Border.all(color: _magenta.withOpacity(0.45), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: _magenta.withOpacity(0.2),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _TicketPerforationPainter(
                color: Colors.white.withOpacity(0.12),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.bolt, color: _lime, size: 22),
                    const SizedBox(width: 8),
                    ShaderMask(
                      blendMode: BlendMode.srcIn,
                      shaderCallback: (b) => LinearGradient(
                        colors: [_lime, _cyan],
                      ).createShader(b),
                      child: const Text(
                        'TODAY',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Resets midnight',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.45),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  s.habits.isEmpty
                      ? 'Add habits from Home, then check them off to build your score.'
                      : 'Complete every habit today for a perfect day. $left habit${left == 1 ? '' : 's'} left.',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: Stack(
                    children: [
                      Container(
                        height: 10,
                        color: Colors.black.withOpacity(0.45),
                      ),
                      FractionallySizedBox(
                        widthFactor: tp,
                        child: Container(
                          height: 10,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [_magenta, _cyan, _lime],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _cyan.withOpacity(0.6),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${(tp * 100).round()}% of today\'s habits done',
                  style: TextStyle(
                    color: _cyan.withOpacity(0.85),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _leaderboardRow({
    required int rank,
    required String name,
    required int points,
  }) {
    Color rankAccent;
    if (rank == 1) {
      rankAccent = const Color(0xFFFFD54F);
    } else if (rank == 2) {
      rankAccent = const Color(0xFFB0BEC5);
    } else if (rank == 3) {
      rankAccent = const Color(0xFFFF8A65);
    } else {
      rankAccent = _cyan.withOpacity(0.65);
    }
    final ptsLabel = points >= 1000
        ? '${(points / 1000).toStringAsFixed(1)}K'
        : '$points';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1A0F2E).withOpacity(0.9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text(
                '#$rank',
                style: TextStyle(
                  color: rankAccent,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  shadows: [
                    Shadow(color: rankAccent.withOpacity(0.4), blurRadius: 8),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _magenta.withOpacity(0.12),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: _magenta.withOpacity(0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bolt, color: _lime, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    ptsLabel,
                    style: const TextStyle(
                      color: _lime,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _battleRow(
    String title,
    String subtitle,
    String badge,
    IconData icon,
    int index,
  ) {
    final tilt = index.isEven ? 0.018 : -0.018;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Transform.rotate(
        angle: tilt,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF22143C).withOpacity(0.92),
                const Color(0xFF0C0A18).withOpacity(0.95),
              ],
            ),
            borderRadius: BorderRadius.circular(6),
            border: Border(
              left: BorderSide(
                color: index == 0
                    ? _magenta
                    : index == 1
                    ? _cyan
                    : _lime,
                width: 4,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(4, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white.withOpacity(0.15)),
                  borderRadius: BorderRadius.circular(4),
                  color: Colors.black.withOpacity(0.35),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.55),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Transform.rotate(
                angle: math.pi / 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  color: _lime.withOpacity(0.15),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: _lime,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArenaDeployChip extends StatelessWidget {
  const _ArenaDeployChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    const magenta = Color(0xFFFF00C8);
    const cyan = Color(0xFF00F5FF);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(2),
        child: Ink(
          decoration: BoxDecoration(
            color: const Color(0xFF14082A),
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: cyan.withOpacity(0.4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                offset: const Offset(3, 4),
                blurRadius: 0,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 17, color: magenta),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SocialArenaTopClipper extends CustomClipper<Path> {
  const _SocialArenaTopClipper();

  @override
  Path getClip(Size size) {
    final p = Path();
    p.moveTo(0, 28);
    p.lineTo(size.width * 0.12, 14);
    p.lineTo(size.width * 0.28, 26);
    p.lineTo(size.width * 0.44, 10);
    p.lineTo(size.width * 0.62, 24);
    p.lineTo(size.width * 0.78, 12);
    p.lineTo(size.width * 0.92, 22);
    p.lineTo(size.width, 16);
    p.lineTo(size.width, size.height);
    p.lineTo(0, size.height);
    p.close();
    return p;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _ArenaGridPainter extends CustomPainter {
  _ArenaGridPainter({required this.phase});

  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final c1 = Color.lerp(
      const Color(0x33FF00C8),
      const Color(0x3300F5FF),
      phase,
    )!;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (double x = -size.height; x < size.width + size.height; x += 32) {
      paint.color = c1.withOpacity(0.08 + 0.06 * phase);
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height * 0.85, size.height),
        paint,
      );
    }
    for (double y = 0; y < size.height; y += 40) {
      paint.color = const Color(0x22FFFFFF);
      canvas.drawLine(
        Offset(0, y + phase * 20),
        Offset(size.width, y + phase * 20),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ArenaGridPainter oldDelegate) =>
      oldDelegate.phase != phase;
}

class _TicketPerforationPainter extends CustomPainter {
  _TicketPerforationPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const step = 10.0;
    for (double y = 12; y < size.height - 12; y += step) {
      canvas.drawCircle(Offset(0, y), 2.2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TicketPerforationPainter oldDelegate) =>
      oldDelegate.color != color;
}

String _habitTeacherReply(String userMessage) {
  final s = userMessage.toLowerCase().trim();
  if (s.isEmpty) {
    return "Say what’s on your mind—I’m here to help you shape better habits.";
  }
  if (s.contains('streak') || s.contains('chain') || s.contains('daily')) {
    return "Streaks reward showing up, not being perfect. If you miss a day, restart the next day with a "
        "smaller version of the habit so it still feels easy to win.";
  }
  if (s.contains('motivat') ||
      s.contains('lazy') ||
      s.contains("can't") ||
      s.contains('hard')) {
    return "Motivation is unreliable—build a cue instead. After something you already do every day "
        "(coffee, brushing teeth), stack your new habit. Start so small it feels silly to skip.";
  }
  if (s.contains('start') || s.contains('begin') || s.contains('new habit')) {
    return "One habit at a time. Name it clearly, pick a category (Focus, Move, Gym, Nutrition, Sleep, Social, Creative, …), "
        "and add it in Kultivate. Use the **Open habit creator** chip below when you’re ready to lock it in.";
  }
  if (s.contains('time') || s.contains('busy') || s.contains('schedule')) {
    return "Shrink the commitment: two minutes still counts. One page, one lap, one minute of breath—"
        "consistency beats intensity early on.";
  }
  if (s.contains('thank')) {
    return "Anytime. Small steps, repeated, change everything. Come back when you want another nudge.";
  }
  if (s.contains('hello') || s.contains('hi') || s.contains('hey')) {
    return "Hey! I’m your habit teacher. Ask about streaks, motivation, or starting small—or open the habit creator to add something new.";
  }
  return "I coach on starting small, staying consistent, and bouncing back after misses. "
      "Try asking about streaks, motivation, or a busy schedule—or tap **Open habit creator** to add a habit.";
}

class _HabitTeacherBotSheet extends StatefulWidget {
  const _HabitTeacherBotSheet({
    required this.scrollController,
    required this.onOpenHabitCreator,
  });

  final ScrollController scrollController;
  final VoidCallback onOpenHabitCreator;

  @override
  State<_HabitTeacherBotSheet> createState() => _HabitTeacherBotSheetState();
}

class _BotChatLine {
  _BotChatLine({required this.fromUser, required this.text});
  final bool fromUser;
  final String text;
}

class _HabitTeacherBotSheetState extends State<_HabitTeacherBotSheet> {
  final TextEditingController _input = TextEditingController();
  final List<_BotChatLine> _lines = [];
  bool _botTyping = false;

  static const _welcome =
      "Hi—I’m your **Habit Teacher** bot. I’ll help you think through routines, streaks, and getting started. "
      "Type a question or tap a shortcut below. When you’re ready, open the habit creator to add it in the app.";

  @override
  void initState() {
    super.initState();
    _lines.add(_BotChatLine(fromUser: false, text: _welcome));
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!widget.scrollController.hasClients) return;
      widget.scrollController.animateTo(
        widget.scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _sendUserText(String text) async {
    final t = text.trim();
    if (t.isEmpty || _botTyping) return;
    setState(() {
      _lines.add(_BotChatLine(fromUser: true, text: t));
      _botTyping = true;
    });
    _input.clear();
    _scrollToEnd();
    await Future<void>.delayed(const Duration(milliseconds: 420));
    if (!mounted) return;
    setState(() {
      _lines.add(_BotChatLine(fromUser: false, text: _habitTeacherReply(t)));
      _botTyping = false;
    });
    _scrollToEnd();
  }

  Widget _bubble(_BotChatLine line) {
    const cyan = Color(0xFF00D9FF);
    final isUser = line.fromUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
          color: isUser ? cyan.withOpacity(0.22) : const Color(0xFF0F1023),
          border: Border.all(
            color: isUser
                ? cyan.withOpacity(0.35)
                : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Text(
          line.text.replaceAll('**', ''),
          style: TextStyle(
            color: Colors.white.withOpacity(isUser ? 0.95 : 0.9),
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const cyan = Color(0xFF00D9FF);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1B3A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 24,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cyan.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.smart_toy_rounded,
                    color: cyan,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Habit Teacher',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Coaching bot · tips & nudges',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: widget.scrollController,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              children: [
                ..._lines.map(_bubble),
                if (_botTyping)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: cyan.withOpacity(0.85),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Teacher is thinking…',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.45),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ActionChip(
                    label: const Text('How to start?'),
                    labelStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    backgroundColor: const Color(0xFF0F1023),
                    side: BorderSide(color: Colors.white.withOpacity(0.14)),
                    onPressed: () =>
                        _sendUserText('How do I start a new habit?'),
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    label: const Text('Streaks'),
                    labelStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    backgroundColor: const Color(0xFF0F1023),
                    side: BorderSide(color: Colors.white.withOpacity(0.14)),
                    onPressed: () => _sendUserText('Tell me about streaks'),
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    label: const Text('Motivation'),
                    labelStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    backgroundColor: const Color(0xFF0F1023),
                    side: BorderSide(color: Colors.white.withOpacity(0.14)),
                    onPressed: () =>
                        _sendUserText('I struggle with motivation'),
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: const Icon(
                      Icons.add_circle_outline,
                      color: cyan,
                      size: 18,
                    ),
                    label: const Text('Open habit creator'),
                    labelStyle: const TextStyle(
                      color: cyan,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    backgroundColor: cyan.withOpacity(0.12),
                    side: BorderSide(color: cyan.withOpacity(0.4)),
                    onPressed: widget.onOpenHabitCreator,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    style: const TextStyle(color: Colors.white),
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Ask your habit teacher…',
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.35),
                      ),
                      filled: true,
                      fillColor: const Color(0xFF0F1023),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.12),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.12),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: cyan, width: 1.2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: _sendUserText,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: cyan,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => _sendUserText(_input.text),
                  icon: const Icon(Icons.send_rounded, size: 22),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HabitCreateSheet extends StatefulWidget {
  const _HabitCreateSheet({
    required this.scrollController,
    required this.onOpenActivityWheel,
    this.initialTitle,
    this.initialCategory,
  });

  final ScrollController scrollController;
  final VoidCallback onOpenActivityWheel;
  final String? initialTitle;
  final String? initialCategory;

  @override
  State<_HabitCreateSheet> createState() => _HabitCreateSheetState();
}

List<(String label, IconData icon)> _activityPresetsForCategory(String cat) {
  return _kActivityPresets
      .where((e) => _categoryForRadialLabel(e.$1) == cat)
      .toList();
}

class _HabitCreateSheetState extends State<_HabitCreateSheet> {
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();
  final TextEditingController _learnTopicCtrl = TextEditingController();
  String _category = 'focus';
  String _frequency = 'daily';
  bool _saving = false;

  /// Focus playbook
  String? _focusWorkMode;
  int? _focusMinutes;
  String? _focusCue;

  /// Move playbook
  String? _moveKind;
  int? _moveMinutes;
  String? _moveIntensity;

  /// Mind playbook
  String? _mindKind;
  int? _mindMinutes;
  String? _mindSlot;

  /// Learn playbook
  String? _learnFormat;
  int? _learnMinutes;

  /// Gym playbook
  String? _gymSplit;
  int? _gymMinutes;
  String? _gymStyle;

  /// Nutrition playbook
  String? _nutritionFocus;
  String? _nutritionMeal;
  String? _nutritionExtra;

  /// Sleep playbook
  String? _sleepTarget;
  String? _sleepHabit;

  /// Social playbook
  String? _socialType;
  String? _socialCadence;

  /// Creative playbook
  String? _creativeMedium;
  int? _creativeMinutes;

  static const List<(String id, String label, String blurb)> _categoryCards = [
    ('focus', 'Focus', 'Deep work & attention'),
    ('move', 'Move', 'Body & energy'),
    ('mind', 'Mind', 'Calm & reflection'),
    ('learn', 'Learn', 'Skills & knowledge'),
    ('gym', 'Gym', 'Weights & training'),
    ('nutrition', 'Nutrition', 'Food & hydration'),
    ('sleep', 'Sleep', 'Rest & recovery'),
    ('social', 'Social', 'People & connection'),
    ('creative', 'Creative', 'Art & hobbies'),
  ];

  static bool _isKnownCategoryId(String id) =>
      _categoryCards.any((c) => c.$1 == id);

  @override
  void initState() {
    super.initState();
    final t = widget.initialTitle?.trim();
    if (t != null && t.isNotEmpty) {
      _titleCtrl.text = t;
    }
    final c = widget.initialCategory?.trim();
    if (c != null && c.isNotEmpty && _isKnownCategoryId(c)) {
      _category = c;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    _learnTopicCtrl.dispose();
    super.dispose();
  }

  String _titleSuffixFromPlaybook() {
    final parts = <String>[];
    switch (_category) {
      case 'focus':
        final rawName = _titleCtrl.text.trim();
        final implicit = rawName.isNotEmpty ? null : _defaultTitleIfNameEmpty();
        if (_focusWorkMode != null &&
            _focusWorkMode != rawName &&
            _focusWorkMode != implicit) {
          parts.add(_focusWorkMode!);
        }
        if (_focusMinutes != null) {
          final minutesOnlyName =
              rawName.isEmpty && _focusWorkMode == null && _focusCue == null;
          if (!minutesOnlyName) parts.add('${_focusMinutes}m block');
        }
        if (_focusCue != null) {
          final cueOnlyName =
              rawName.isEmpty &&
              _focusWorkMode == null &&
              _focusMinutes == null;
          if (!cueOnlyName) parts.add(_focusCue!);
        }
        break;
      case 'move':
        final rawName = _titleCtrl.text.trim();
        final implicit = rawName.isNotEmpty ? null : _defaultTitleIfNameEmpty();
        if (_moveKind != null &&
            _moveKind != rawName &&
            _moveKind != implicit) {
          parts.add(_moveKind!);
        }
        if (_moveMinutes != null) {
          final minutesOnlyName =
              rawName.isEmpty && _moveKind == null && _moveIntensity == null;
          if (!minutesOnlyName) parts.add('${_moveMinutes}m');
        }
        if (_moveIntensity != null &&
            _moveIntensity != rawName &&
            _moveIntensity != implicit) {
          parts.add(_moveIntensity!);
        }
        break;
      case 'mind':
        final rawName = _titleCtrl.text.trim();
        final implicit = rawName.isNotEmpty ? null : _defaultTitleIfNameEmpty();
        if (_mindKind != null &&
            _mindKind != rawName &&
            _mindKind != implicit) {
          parts.add(_mindKind!);
        }
        if (_mindMinutes != null) {
          final minutesOnlyName =
              rawName.isEmpty && _mindKind == null && _mindSlot == null;
          if (!minutesOnlyName) parts.add('${_mindMinutes}m');
        }
        if (_mindSlot != null) {
          final slotOnlyName =
              rawName.isEmpty && _mindKind == null && _mindMinutes == null;
          if (!slotOnlyName) parts.add(_mindSlot!);
        }
        break;
      case 'learn':
        final rawName = _titleCtrl.text.trim();
        final topic = _learnTopicCtrl.text.trim();
        final usingAsName = rawName.isNotEmpty
            ? rawName
            : (topic.isNotEmpty ? topic : _learnFormat);
        if (_learnFormat != null && _learnFormat != usingAsName) {
          parts.add(_learnFormat!);
        }
        if (_learnMinutes != null) parts.add('${_learnMinutes}m sessions');
        if (topic.isNotEmpty && rawName.isNotEmpty) parts.add(topic);
        break;
      case 'gym':
        final rawName = _titleCtrl.text.trim();
        final implicit = rawName.isNotEmpty ? null : _defaultTitleIfNameEmpty();
        if (_gymSplit != null &&
            _gymSplit != rawName &&
            _gymSplit != implicit) {
          parts.add(_gymSplit!);
        }
        if (_gymMinutes != null) {
          final minutesOnly =
              rawName.isEmpty && _gymSplit == null && _gymStyle == null;
          if (!minutesOnly) parts.add('${_gymMinutes}m');
        }
        if (_gymStyle != null &&
            _gymStyle != rawName &&
            _gymStyle != implicit) {
          parts.add(_gymStyle!);
        }
        break;
      case 'nutrition':
        final rawName = _titleCtrl.text.trim();
        final implicit = rawName.isNotEmpty ? null : _defaultTitleIfNameEmpty();
        if (_nutritionFocus != null &&
            _nutritionFocus != rawName &&
            _nutritionFocus != implicit) {
          parts.add(_nutritionFocus!);
        }
        if (_nutritionMeal != null &&
            _nutritionMeal != rawName &&
            _nutritionMeal != implicit) {
          parts.add(_nutritionMeal!);
        }
        if (_nutritionExtra != null &&
            _nutritionExtra != rawName &&
            _nutritionExtra != implicit) {
          parts.add(_nutritionExtra!);
        }
        break;
      case 'sleep':
        final rawName = _titleCtrl.text.trim();
        final implicit = rawName.isNotEmpty ? null : _defaultTitleIfNameEmpty();
        if (_sleepTarget != null &&
            _sleepTarget != rawName &&
            _sleepTarget != implicit) {
          parts.add(_sleepTarget!);
        }
        if (_sleepHabit != null &&
            _sleepHabit != rawName &&
            _sleepHabit != implicit) {
          parts.add(_sleepHabit!);
        }
        break;
      case 'social':
        final rawName = _titleCtrl.text.trim();
        final implicit = rawName.isNotEmpty ? null : _defaultTitleIfNameEmpty();
        if (_socialType != null &&
            _socialType != rawName &&
            _socialType != implicit) {
          parts.add(_socialType!);
        }
        if (_socialCadence != null &&
            _socialCadence != rawName &&
            _socialCadence != implicit) {
          parts.add(_socialCadence!);
        }
        break;
      case 'creative':
        final rawName = _titleCtrl.text.trim();
        final implicit = rawName.isNotEmpty ? null : _defaultTitleIfNameEmpty();
        if (_creativeMedium != null &&
            _creativeMedium != rawName &&
            _creativeMedium != implicit) {
          parts.add(_creativeMedium!);
        }
        if (_creativeMinutes != null) {
          final minutesOnly = rawName.isEmpty && _creativeMedium == null;
          if (!minutesOnly) parts.add('${_creativeMinutes}m');
        }
        break;
    }
    if (parts.isEmpty) return '';
    return ' · ${parts.join(' · ')}';
  }

  String? _defaultTitleIfNameEmpty() {
    switch (_category) {
      case 'focus':
        if (_focusWorkMode != null) return _focusWorkMode;
        if (_focusMinutes != null) return '${_focusMinutes}m focus';
        if (_focusCue != null) return 'Focus · ${_focusCue!}';
        return null;
      case 'move':
        if (_moveKind != null) return _moveKind;
        if (_moveMinutes != null) return '${_moveMinutes}m movement';
        if (_moveIntensity != null) return _moveIntensity;
        return null;
      case 'mind':
        if (_mindKind != null) return _mindKind;
        if (_mindMinutes != null) return '${_mindMinutes}m mindful';
        if (_mindSlot != null) return _mindSlot;
        return null;
      case 'learn':
        final t = _learnTopicCtrl.text.trim();
        if (t.isNotEmpty) return t;
        return _learnFormat;
      case 'gym':
        if (_gymSplit != null) return _gymSplit;
        if (_gymMinutes != null) return '${_gymMinutes}m gym';
        if (_gymStyle != null) return 'Gym · ${_gymStyle!}';
        return null;
      case 'nutrition':
        if (_nutritionFocus != null) return _nutritionFocus;
        if (_nutritionMeal != null) return _nutritionMeal;
        if (_nutritionExtra != null) return _nutritionExtra;
        return null;
      case 'sleep':
        if (_sleepTarget != null) return _sleepTarget;
        if (_sleepHabit != null) return _sleepHabit;
        return null;
      case 'social':
        if (_socialType != null) return _socialType;
        if (_socialCadence != null) return _socialCadence;
        return null;
      case 'creative':
        if (_creativeMedium != null) return _creativeMedium;
        if (_creativeMinutes != null) return '${_creativeMinutes}m creative';
        return null;
      default:
        return null;
    }
  }

  bool get _canSubmit {
    if (_saving) return false;
    return _titleCtrl.text.trim().isNotEmpty;
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    var t = _titleCtrl.text.trim();
    final suffix = _titleSuffixFromPlaybook();
    if (suffix.isNotEmpty) t = '$t$suffix';
    final notesRaw = _notesCtrl.text.trim();
    setState(() => _saving = true);
    await HabitStore.instance.addHabit(
      title: t,
      category: _category,
      notes: notesRaw.isEmpty ? null : notesRaw,
      frequency: _frequency,
    );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  void _applyTemplate(String label) {
    setState(() {
      _titleCtrl.text = label;
      _titleCtrl.selection = TextSelection.collapsed(offset: label.length);
      _category = _categoryForRadialLabel(label);
    });
  }

  void _setCategory(String id) {
    setState(() => _category = id);
  }

  Widget _playbookSectionLabel(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.92),
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withOpacity(0.48),
              fontSize: 12,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _pillRow<T>({
    required List<T> values,
    required T? selected,
    required String Function(T) label,
    required void Function(T?) onSelect,
  }) {
    const cyan = Color(0xFF00D9FF);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final v in values)
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => setState(() {
                onSelect(selected == v ? null : v);
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: selected == v
                      ? cyan.withOpacity(0.2)
                      : const Color(0xFF0F1023),
                  border: Border.all(
                    color: selected == v
                        ? cyan
                        : Colors.white.withOpacity(0.14),
                    width: selected == v ? 1.4 : 1,
                  ),
                ),
                child: Text(
                  label(v),
                  style: TextStyle(
                    color: selected == v ? Colors.white : Colors.white70,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFrequencyRow() {
    const cyan = Color(0xFF00D9FF);
    const options = <(String id, String label)>[
      ('daily', 'Every day'),
      ('weekdays', 'Weekdays'),
      ('weekly', 'Once a week'),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (id, label) in options)
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => setState(() => _frequency = id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: _frequency == id
                      ? cyan.withOpacity(0.2)
                      : const Color(0xFF0F1023),
                  border: Border.all(
                    color: _frequency == id
                        ? cyan
                        : Colors.white.withOpacity(0.14),
                    width: _frequency == id ? 1.4 : 1,
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: _frequency == id ? Colors.white : Colors.white70,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCategoryPlaybook() {
    const cyan = Color(0xFF00D9FF);
    switch (_category) {
      case 'focus':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _playbookSectionLabel(
              'Attention blueprint',
              'Pick how you work and for how long — we fold it into your habit name.',
            ),
            Text(
              'Work mode',
              style: TextStyle(
                color: Colors.white.withOpacity(0.45),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            _pillRow<String>(
              values: const [
                'Deep work',
                'Admin & email',
                'Creative flow',
                'Study block',
              ],
              selected: _focusWorkMode,
              label: (s) => s,
              onSelect: (v) => _focusWorkMode = v,
            ),
            const SizedBox(height: 18),
            Text(
              'Target block',
              style: TextStyle(
                color: Colors.white.withOpacity(0.45),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            _pillRow<int>(
              values: const [15, 25, 45, 60],
              selected: _focusMinutes,
              label: (m) => '${m}m',
              onSelect: (v) => _focusMinutes = v,
            ),
            const SizedBox(height: 18),
            Text(
              'Start cue',
              style: TextStyle(
                color: Colors.white.withOpacity(0.45),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            _pillRow<String>(
              values: const [
                'First thing',
                'After coffee',
                'Post-lunch',
                'Evening sprint',
              ],
              selected: _focusCue,
              label: (s) => s,
              onSelect: (v) => _focusCue = v,
            ),
          ],
        );
      case 'move':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _playbookSectionLabel(
              'Movement recipe',
              'Dial in type, duration, and effort so check-ins feel concrete.',
            ),
            Text(
              'Activity',
              style: TextStyle(
                color: Colors.white.withOpacity(0.45),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            _pillRow<String>(
              values: const [
                'Walk',
                'Run',
                'Cycle',
                'Strength',
                'Stretch',
                'Sports',
              ],
              selected: _moveKind,
              label: (s) => s,
              onSelect: (v) => _moveKind = v,
            ),
            const SizedBox(height: 18),
            Text(
              'Duration',
              style: TextStyle(
                color: Colors.white.withOpacity(0.45),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            _pillRow<int>(
              values: const [10, 20, 30, 45, 60],
              selected: _moveMinutes,
              label: (m) => '${m}m',
              onSelect: (v) => _moveMinutes = v,
            ),
            const SizedBox(height: 18),
            Text(
              'Effort',
              style: TextStyle(
                color: Colors.white.withOpacity(0.45),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            _pillRow<String>(
              values: const ['Light', 'Moderate', 'Push day'],
              selected: _moveIntensity,
              label: (s) => s,
              onSelect: (v) => _moveIntensity = v,
            ),
          ],
        );
      case 'mind':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _playbookSectionLabel(
              'Mindful stack',
              'Match practice, length, and the part of your day you protect.',
            ),
            Text(
              'Practice',
              style: TextStyle(
                color: Colors.white.withOpacity(0.45),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            _pillRow<String>(
              values: const [
                'Meditation',
                'Breathwork',
                'Journal',
                'Gratitude',
              ],
              selected: _mindKind,
              label: (s) => s,
              onSelect: (v) => _mindKind = v,
            ),
            const SizedBox(height: 18),
            Text(
              'Length',
              style: TextStyle(
                color: Colors.white.withOpacity(0.45),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            _pillRow<int>(
              values: const [5, 10, 15, 20],
              selected: _mindMinutes,
              label: (m) => '${m}m',
              onSelect: (v) => _mindMinutes = v,
            ),
            const SizedBox(height: 18),
            Text(
              'Rhythm',
              style: TextStyle(
                color: Colors.white.withOpacity(0.45),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            _pillRow<String>(
              values: const ['Morning', 'Midday reset', 'Before bed'],
              selected: _mindSlot,
              label: (s) => s,
              onSelect: (v) => _mindSlot = v,
            ),
          ],
        );
      case 'learn':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _playbookSectionLabel(
              'Learning loop',
              'Format, session size, and what you are leveling up.',
            ),
            Text(
              'Format',
              style: TextStyle(
                color: Colors.white.withOpacity(0.45),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            _pillRow<String>(
              values: const [
                'Reading',
                'Video course',
                'Hands-on practice',
                'Language',
                'Flashcards',
              ],
              selected: _learnFormat,
              label: (s) => s,
              onSelect: (v) => _learnFormat = v,
            ),
            const SizedBox(height: 18),
            Text(
              'Session size',
              style: TextStyle(
                color: Colors.white.withOpacity(0.45),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            _pillRow<int>(
              values: const [15, 25, 45, 60],
              selected: _learnMinutes,
              label: (m) => '${m}m',
              onSelect: (v) => _learnMinutes = v,
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _learnTopicCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Skill, book, or course (optional)',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.38)),
                labelText: 'What are you learning?',
                labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                filled: true,
                fillColor: const Color(0xFF0F1023),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: cyan, width: 1.4),
                ),
              ),
            ),
          ],
        );
      case 'gym':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _playbookSectionLabel(
              'Training setup',
              'Split, duration, and intensity — added to your habit name.',
            ),
            Text(
              'Focus',
              style: TextStyle(
                color: Colors.white.withOpacity(0.45),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            _pillRow<String>(
              values: const [
                'Push',
                'Pull',
                'Legs',
                'Full body',
                'Cardio',
                'HIIT',
              ],
              selected: _gymSplit,
              label: (s) => s,
              onSelect: (v) => _gymSplit = v,
            ),
            const SizedBox(height: 18),
            Text(
              'Duration',
              style: TextStyle(
                color: Colors.white.withOpacity(0.45),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            _pillRow<int>(
              values: const [20, 30, 45, 60],
              selected: _gymMinutes,
              label: (m) => '${m}m',
              onSelect: (v) => _gymMinutes = v,
            ),
            const SizedBox(height: 18),
            Text(
              'Style',
              style: TextStyle(
                color: Colors.white.withOpacity(0.45),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            _pillRow<String>(
              values: const ['Heavy', 'Moderate', 'Deload', 'PR attempt'],
              selected: _gymStyle,
              label: (s) => s,
              onSelect: (v) => _gymStyle = v,
            ),
          ],
        );
      case 'nutrition':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _playbookSectionLabel(
              'Nutrition plan',
              'What you are optimizing and when you eat.',
            ),
            Text(
              'Goal',
              style: TextStyle(
                color: Colors.white.withOpacity(0.45),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            _pillRow<String>(
              values: const [
                'Hydration',
                'Protein',
                'Whole foods',
                'Meal timing',
                'Less sugar',
              ],
              selected: _nutritionFocus,
              label: (s) => s,
              onSelect: (v) => _nutritionFocus = v,
            ),
            const SizedBox(height: 18),
            Text(
              'Meal',
              style: TextStyle(
                color: Colors.white.withOpacity(0.45),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            _pillRow<String>(
              values: const ['Breakfast', 'Lunch', 'Dinner', 'Snacks'],
              selected: _nutritionMeal,
              label: (s) => s,
              onSelect: (v) => _nutritionMeal = v,
            ),
            const SizedBox(height: 18),
            Text(
              'Log style',
              style: TextStyle(
                color: Colors.white.withOpacity(0.45),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            _pillRow<String>(
              values: const ['Photo log', 'Calorie note', 'Simple check-in'],
              selected: _nutritionExtra,
              label: (s) => s,
              onSelect: (v) => _nutritionExtra = v,
            ),
          ],
        );
      case 'sleep':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _playbookSectionLabel(
              'Sleep stack',
              'Targets and wind-down cues for better nights.',
            ),
            Text(
              'Target',
              style: TextStyle(
                color: Colors.white.withOpacity(0.45),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            _pillRow<String>(
              values: const [
                '7h sleep',
                '8h+ sleep',
                'Same bedtime',
                'Same wake time',
              ],
              selected: _sleepTarget,
              label: (s) => s,
              onSelect: (v) => _sleepTarget = v,
            ),
            const SizedBox(height: 18),
            Text(
              'Habit',
              style: TextStyle(
                color: Colors.white.withOpacity(0.45),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            _pillRow<String>(
              values: const [
                'No screens',
                'Read',
                'Stretch',
                'Dim lights',
                'Cool room',
              ],
              selected: _sleepHabit,
              label: (s) => s,
              onSelect: (v) => _sleepHabit = v,
            ),
          ],
        );
      case 'social':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _playbookSectionLabel(
              'Connection',
              'How you show up for people — merged into the title.',
            ),
            Text(
              'Type',
              style: TextStyle(
                color: Colors.white.withOpacity(0.45),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            _pillRow<String>(
              values: const [
                'Call',
                'Text',
                'In person',
                'Family time',
                'Community',
              ],
              selected: _socialType,
              label: (s) => s,
              onSelect: (v) => _socialType = v,
            ),
            const SizedBox(height: 18),
            Text(
              'Cadence',
              style: TextStyle(
                color: Colors.white.withOpacity(0.45),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            _pillRow<String>(
              values: const [
                'Daily check-in',
                'Weekly date',
                'Monthly catch-up',
              ],
              selected: _socialCadence,
              label: (s) => s,
              onSelect: (v) => _socialCadence = v,
            ),
          ],
        );
      case 'creative':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _playbookSectionLabel(
              'Creative practice',
              'Medium and session length for your craft.',
            ),
            Text(
              'Medium',
              style: TextStyle(
                color: Colors.white.withOpacity(0.45),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            _pillRow<String>(
              values: const [
                'Writing',
                'Music',
                'Drawing',
                'Photography',
                'Side project',
              ],
              selected: _creativeMedium,
              label: (s) => s,
              onSelect: (v) => _creativeMedium = v,
            ),
            const SizedBox(height: 18),
            Text(
              'Session',
              style: TextStyle(
                color: Colors.white.withOpacity(0.45),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            _pillRow<int>(
              values: const [15, 30, 45, 60],
              selected: _creativeMinutes,
              label: (m) => '${m}m',
              onSelect: (v) => _creativeMinutes = v,
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    const cyan = Color(0xFF00D9FF);
    final presets = _activityPresetsForCategory(_category);
    final activeCategoryAccent = _accentForHabitCategory(_category);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1B3A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 24,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'New habit',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: widget.scrollController,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              children: [
                Text(
                  '1 · Your habit',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.initialTitle != null &&
                          widget.initialTitle!.trim().isNotEmpty
                      ? 'You picked this from the wheel — category is set below. Add notes, repeat, and optional details, then save.'
                      : 'Type a clear name you can check off. Optional fields help you remember why and how often.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.42),
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _titleCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'e.g. Drink 8 glasses of water',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.45)),
                    labelText: 'Habit name',
                    labelStyle: TextStyle(
                      color: Colors.white.withOpacity(0.65),
                    ),
                    filled: true,
                    fillColor: const Color(0xFF0F1023),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: Colors.white.withOpacity(0.12),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: Colors.white.withOpacity(0.12),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: cyan, width: 1.4),
                    ),
                  ),
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                Text(
                  'Why / reminder (optional)',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.45),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _notesCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText:
                        'Motivation, trigger, or a detail for future you…',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.38)),
                    filled: true,
                    fillColor: const Color(0xFF0F1023),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: Colors.white.withOpacity(0.12),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: Colors.white.withOpacity(0.12),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: cyan, width: 1.4),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                Text(
                  'Repeat',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.45),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                _buildFrequencyRow(),
                const SizedBox(height: 22),
                Text(
                  '2 · Category',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.92,
                  children: [
                    for (final (id, label, blurb) in _categoryCards)
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _setCategory(id),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: _category == id
                                  ? LinearGradient(
                                      colors: [
                                        _accentForHabitCategory(
                                          id,
                                        ).withOpacity(0.22),
                                        const Color(0xFF0F1023),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : null,
                              color: _category == id
                                  ? null
                                  : const Color(0xFF0F1023),
                              border: Border.all(
                                color: _category == id
                                    ? _accentForHabitCategory(id)
                                    : _accentForHabitCategory(
                                        id,
                                      ).withOpacity(0.38),
                                width: _category == id ? 1.6 : 1,
                              ),
                              boxShadow: _category == id
                                  ? [
                                      BoxShadow(
                                        color: _accentForHabitCategory(
                                          id,
                                        ).withOpacity(0.22),
                                        blurRadius: 12,
                                        spreadRadius: 0,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _iconForHabitCategory(id),
                                  size: 22,
                                  color: _category == id
                                      ? _accentForHabitCategory(id)
                                      : _accentForHabitCategory(
                                          id,
                                        ).withOpacity(0.72),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  label,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(
                                      _category == id ? 1 : 0.88,
                                    ),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  blurb,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.45),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  '3 · Optional detail',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Extras are merged into the habit name (duration, cue, format…). Skip if your name above is enough.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.42),
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, anim) {
                    return FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.04, 0),
                          end: Offset.zero,
                        ).animate(anim),
                        child: child,
                      ),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey<String>(_category),
                    child: _buildCategoryPlaybook(),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  'Quick templates',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Matched to your lane',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.38),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (label, icon) in presets)
                      ActionChip(
                        avatar: Icon(
                          icon,
                          size: 18,
                          color: _accentForHabitCategory(
                            _categoryForRadialLabel(label),
                          ),
                        ),
                        label: Text(label),
                        labelStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        backgroundColor: _accentForHabitCategory(
                          _categoryForRadialLabel(label),
                        ).withOpacity(0.12),
                        side: BorderSide(
                          color: _accentForHabitCategory(
                            _categoryForRadialLabel(label),
                          ).withOpacity(0.45),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        onPressed: () => _applyTemplate(label),
                      ),
                  ],
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _canSubmit ? _submit : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: activeCategoryAccent,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.white24,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Add habit',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton.icon(
                    onPressed: widget.onOpenActivityWheel,
                    icon: const Icon(
                      Icons.blur_circular,
                      color: Color(0xFF00D9FF),
                      size: 20,
                    ),
                    label: const Text(
                      'Activity wheel instead',
                      style: TextStyle(
                        color: Color(0xFF00D9FF),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- RADIAL + BUTTON ACTIVITY PICKER (FAB) ---

class RadialActivityPickerOverlay extends StatefulWidget {
  const RadialActivityPickerOverlay({
    super.key,
    required this.fabTopLeft,
    required this.fabSize,
    required this.onClose,
    this.onPickActivity,
    this.onPresetChosen,
    this.onAfterCustomHabit,
  });

  final Offset fabTopLeft;
  final Size fabSize;
  final VoidCallback onClose;

  /// Legacy: add habit immediately (unused when [onPresetChosen] is set).
  final Future<void> Function(String title, String category)? onPickActivity;

  /// Opens the full habit form after dismiss; pass preset label + category.
  final void Function(String title, String category)? onPresetChosen;
  final Future<void> Function()? onAfterCustomHabit;

  @override
  State<RadialActivityPickerOverlay> createState() =>
      _RadialActivityPickerOverlayState();
}

class _RadialActivityPickerOverlayState
    extends State<RadialActivityPickerOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final AnimationController _orbitController;
  late final Animation<double> _expand;
  bool _dismissing = false;

  static const List<(String label, IconData icon)> _activities =
      _kActivityPresets;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
    );
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
    _expand = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _orbitController.dispose();
    super.dispose();
  }

  void _scheduleCloseAfterPointerSettles() {
    if (!mounted) return;
    void close() {
      if (!mounted) return;
      widget.onClose();
    }

    // Web: give the engine time to finish pointer / hover bookkeeping before removing the route.
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Future.delayed(const Duration(milliseconds: 48), close);
        });
      });
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) close();
    });
  }

  Future<void> _dismiss() async {
    if (_dismissing) return;
    _dismissing = true;
    try {
      if (_controller.status != AnimationStatus.dismissed) {
        await _controller.reverse();
      }
    } catch (_) {}
    if (!mounted) return;
    _scheduleCloseAfterPointerSettles();
  }

  @override
  Widget build(BuildContext context) {
    final mqSize = MediaQuery.sizeOf(context);
    // Final wheel hub: screen center. Motion: hub + chips travel from + FAB to center.
    final hubCx = mqSize.width / 2;
    final hubCy = mqSize.height / 2;
    final fabCx = widget.fabTopLeft.dx + widget.fabSize.width / 2;
    final fabCy = widget.fabTopLeft.dy + widget.fabSize.height / 2;
    const chipW = 68.0;
    const chipH = 84.0;
    final n = _activities.length;

    /// GTA-style: heavy blur + dark radial falloff from the hub (still dismiss via [Listener]).
    /// [vignetteX]/[vignetteY] are Alignment coordinates (-1..1) derived from current hub position.
    Widget scrimLayer(double vignetteX, double vignetteY) {
      return Listener(
        behavior: HitTestBehavior.opaque,
        onPointerUp: (_) => _dismiss(),
        child: ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                child: Container(color: Colors.black.withOpacity(0.18)),
              ),
              IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(vignetteX, vignetteY),
                      radius: 1.05,
                      colors: [
                        Colors.black.withOpacity(0.05),
                        Colors.black.withOpacity(0.72),
                      ],
                      stops: const [0.25, 1.0],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _dismiss();
      },
      child: Material(
        type: MaterialType.transparency,
        child: AnimatedBuilder(
          animation: Listenable.merge([_expand, _orbitController]),
          builder: (context, child) {
            final t = _expand.value;
            final orbitPhase = _orbitController.value * 2 * math.pi;
            // Hub slides from + button to screen center; arc radius grows with same progress.
            final curHubX = fabCx + (hubCx - fabCx) * t;
            final curHubY = fabCy + (hubCy - fabCy) * t;
            final vignetteX =
                ((curHubX / mqSize.width).clamp(0.001, 0.999)) * 2 - 1;
            final vignetteY =
                ((curHubY / mqSize.height).clamp(0.001, 0.999)) * 2 - 1;
            // Full 360° ring; use most of safe margin so neighbors have more arc length between them.
            final edgePad = 6.0;
            final maxRx =
                (math.min(curHubX, mqSize.width - curHubX) -
                        chipW / 2 -
                        edgePad)
                    .clamp(68.0, 400.0);
            final maxRy =
                (math.min(curHubY, mqSize.height - curHubY) -
                        chipH / 2 -
                        edgePad)
                    .clamp(68.0, 400.0);
            final ringRadius = math.min(206.0, math.min(maxRx, maxRy));
            return Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(child: scrimLayer(vignetteX, vignetteY)),
                Positioned(
                  left: curHubX - widget.fabSize.width / 2,
                  top: curHubY - widget.fabSize.height / 2,
                  child: Transform.scale(
                    scale: 0.35 + 0.65 * t,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () async {
                        if (_dismissing) return;
                        _dismissing = true;
                        try {
                          if (_controller.status != AnimationStatus.dismissed) {
                            await _controller.reverse();
                          }
                        } catch (_) {}
                        if (!mounted) return;
                        // Pop the route here — [await _dismiss] only schedules [onClose] on the next
                        // frame, so opening the bottom sheet immediately left the dialog on the stack
                        // and blocked all touches ("stuck").
                        final after = widget.onAfterCustomHabit;
                        Navigator.of(context, rootNavigator: true).pop();
                        if (after != null) {
                          void runAfter() {
                            after();
                          }

                          if (kIsWeb) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                Future<void>.delayed(
                                  const Duration(milliseconds: 48),
                                  runAfter,
                                );
                              });
                            });
                          } else {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              runAfter();
                            });
                          }
                        }
                      },
                      child: Container(
                        width: widget.fabSize.width,
                        height: widget.fabSize.height,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(
                            0xFF00D9FF,
                          ).withOpacity(0.12 * t.clamp(0, 1)),
                          border: Border.all(
                            color: const Color(
                              0xFF00D9FF,
                            ).withOpacity(0.55 * t.clamp(0, 1)),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF00D9FF,
                              ).withOpacity(0.45 * t.clamp(0, 1)),
                              blurRadius: 28,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Text(
                          'Custom',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withOpacity(
                              (0.2 + 0.8 * t).clamp(0.0, 1.0),
                            ),
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            letterSpacing: 0.4,
                            height: 1.0,
                            shadows: const [
                              Shadow(
                                color: Colors.black87,
                                blurRadius: 8,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                ...List<Widget>.generate(n, (i) {
                  // Even spacing on a full circle, starting from top (-π/2), clockwise.
                  final baseAngle = n <= 1
                      ? -math.pi / 2
                      : -math.pi / 2 + (2 * math.pi * i) / n;
                  // Slow continuous orbit around the center "Custom" hub.
                  final angle = baseAngle + orbitPhase;
                  final r = ringRadius * t;
                  final dx = math.cos(angle) * r;
                  final dy = math.sin(angle) * r;
                  final (String label, IconData icon) = _activities[i];
                  final accent = _accentForHabitCategory(
                    _categoryForRadialLabel(label),
                  );
                  return Positioned(
                    left: curHubX + dx - chipW / 2,
                    top: curHubY + dy - chipH / 2,
                    child: Opacity(
                      opacity: (0.2 + 0.8 * t).clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: 0.45 + 0.55 * t,
                        child: _ActivityChip(
                          label: label,
                          icon: icon,
                          accentColor: accent,
                          onTap: () async {
                            final category = _categoryForRadialLabel(label);
                            if (widget.onPresetChosen != null) {
                              widget.onPresetChosen!(label, category);
                            } else if (widget.onPickActivity != null) {
                              await widget.onPickActivity!(label, category);
                            }
                            await _dismiss();
                          },
                        ),
                      ),
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ActivityChip extends StatelessWidget {
  const _ActivityChip({
    required this.label,
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color accentColor;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withOpacity(0.82),
              border: Border.all(
                color: accentColor.withOpacity(0.72),
                width: 1.75,
              ),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withOpacity(0.38),
                  blurRadius: 12,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Icon(icon, size: 23, color: accentColor),
          ),
          const SizedBox(height: 5),
          SizedBox(
            width: 68,
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Color.lerp(
                  Colors.white,
                  accentColor,
                  0.35,
                )!.withOpacity(0.98),
                fontWeight: FontWeight.w700,
                fontSize: 10,
                height: 1.12,
                shadows: const [
                  Shadow(
                    color: Colors.black87,
                    blurRadius: 6,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- WAVE PAINTER CLASS ---

class WavePainter extends CustomPainter {
  final Color color;
  final double progress;
  final double waveValue;

  WavePainter({
    required this.color,
    required this.progress,
    required this.waveValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();

    // Calculate the height of the filled part
    final fillHeight = size.height * progress;
    final startY = size.height - fillHeight;

    path.moveTo(0, size.height);
    path.lineTo(0, startY);

    // Draw the sine wave at the top of the progress bar
    for (double i = 0; i <= size.width; i++) {
      path.lineTo(
        i,
        startY +
            math.sin(
                  (i / size.width * 2 * math.pi) + (waveValue * 2 * math.pi),
                ) *
                4,
      );
    }

    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);

    // Add a secondary lighter wave for depth
    final paint2 = Paint()..color = color.withOpacity(0.3);
    final path2 = Path();

    path2.moveTo(0, size.height);
    path2.lineTo(0, startY);

    for (double i = 0; i <= size.width; i++) {
      path2.lineTo(
        i,
        startY +
            math.cos(
                  (i / size.width * 2 * math.pi) + (waveValue * 2 * math.pi),
                ) *
                4,
      );
    }

    path2.lineTo(size.width, size.height);
    path2.close();

    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant WavePainter oldDelegate) {
    return oldDelegate.waveValue != waveValue ||
        (oldDelegate.progress - progress).abs() > 0.0005 ||
        oldDelegate.color != color;
  }
}
