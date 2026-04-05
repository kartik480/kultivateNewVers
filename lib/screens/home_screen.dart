import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:math' as math;
import 'package:video_player/video_player.dart';

import 'package:kultivate_new_ver/services/habit_store.dart';

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
    default:
      return Icons.center_focus_strong;
  }
}

String _greetingForNow() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}

/// Shared between the habit creation panel and the radial FAB picker.
const List<(String label, IconData icon)> _kActivityPresets = [
  ('Yoga', Icons.self_improvement),
  ('Running', Icons.directions_run),
  ('Reading', Icons.menu_book),
  ('Meditation', Icons.spa_outlined),
  ('Cycling', Icons.pedal_bike),
  ('Walking', Icons.directions_walk),
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

// Added TickerProviderStateMixin for the wave animation
class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  double _navBarHeight = 120.0;
  final double _minHeight = 120.0;

  late AnimationController _waveController;
  late VideoPlayerController _babyDragonController;
  bool _wasCompanionsExpanded = false;

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

  @override
  void initState() {
    super.initState();
    HabitStore.instance.ensureLoaded();
    // Animation controller that runs infinitely
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _babyDragonController = VideoPlayerController.asset('companions/babydragon.mp4')
      ..setLooping(true)
      ..setVolume(0);
    _babyDragonController.addListener(_onBabyDragonVideoTick);
    _babyDragonController.initialize().then((_) {
      if (mounted) {
        setState(() {});
        _babyDragonController.setLooping(true);
        _babyDragonController.play();
      }
    });
  }

  @override
  void dispose() {
    _babyDragonController.removeListener(_onBabyDragonVideoTick);
    _waveController.dispose();
    _babyDragonController.dispose();
    super.dispose();
  }

  double _calculateOpacity(double maxHeight) {
    double opacity = 1.0 - ((_navBarHeight - _minHeight) / (maxHeight * 0.6 - _minHeight));
    return opacity.clamp(0.0, 1.0);
  }

  double _getIconOpacity() {
    double fade = 1.0 - ((_navBarHeight - _minHeight) / 30);
    return fade.clamp(0.0, 1.0);
  }

  void _onPanelVerticalDragUpdate(DragUpdateDetails details) {
    final maxH = MediaQuery.sizeOf(context).height;
    setState(() {
      _navBarHeight = (_navBarHeight + details.delta.dy).clamp(_minHeight, maxH);
    });
  }

  void _onPanelVerticalDragEnd(DragEndDetails details) {
    final screenH = MediaQuery.sizeOf(context).height;
    final maxH = screenH;
    final vy = details.velocity.pixelsPerSecond.dy;
    setState(() {
      if (vy > 500) {
        _navBarHeight = maxH;
      } else if (vy < -500) {
        _navBarHeight = _minHeight;
      } else if (_navBarHeight > screenH * 0.25) {
        _navBarHeight = maxH;
      } else {
        _navBarHeight = _minHeight;
      }
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

  void _showHabitCreatePanel() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final bottomInset = MediaQuery.paddingOf(sheetContext).bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: DraggableScrollableSheet(
            initialChildSize: 0.58,
            minChildSize: 0.36,
            maxChildSize: 0.92,
            expand: false,
            builder: (context, scrollController) {
              return _HabitCreateSheet(
                scrollController: scrollController,
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
    final (topLeft, fabSize) = _fabTopLeftAndSize();
    final homeCtx = context;

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
          onClose: () => Navigator.of(dialogContext).pop(),
          onPickActivity: (title, category) => HabitStore.instance.addHabit(title: title, category: category),
          onAfterCustomHabit: () async {
            await Future<void>.delayed(const Duration(milliseconds: 80));
            if (!homeCtx.mounted) return;
            final name = await showDialog<String>(
              context: homeCtx,
              builder: (ctx) {
                final c = TextEditingController();
                return AlertDialog(
                  backgroundColor: const Color(0xFF1A1B3A),
                  title: const Text('Custom habit', style: TextStyle(color: Colors.white)),
                  content: TextField(
                    controller: c,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'What will you track?',
                      hintStyle: TextStyle(color: Colors.white54),
                    ),
                    onSubmitted: (v) => Navigator.pop(ctx, v),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, c.text.trim()),
                      child: const Text('Add'),
                    ),
                  ],
                );
              },
            );
            if (name != null && name.trim().isNotEmpty) {
              await HabitStore.instance.addHabit(title: name.trim(), category: 'focus');
            }
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double maxHeight = screenHeight;
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
            backgroundColor: Color(0xFF0F1023),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF00D9FF)),
            ),
          );
        }
        return Scaffold(
      backgroundColor: const Color(0xFF0F1023),
      extendBody: true,
      bottomNavigationBar: _buildBottomNavBar(),
      floatingActionButton: Transform.translate(
        offset: const Offset(0, 27),
        child: Container(
          height: 70,
          width: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(colors: [Color(0xFF00D9FF), Color(0xFF00D8FF)]),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 20, spreadRadius: 2)],
          ),
          child: IconButton(
            icon: const Icon(Icons.add, color: Colors.white, size: 32),
            onPressed: _showHabitCreatePanel,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: _calculateOpacity(maxHeight),
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: 170, left: 16, right: 16, bottom: 150),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.wb_sunny_rounded,
                          color: const Color(0xFFFFB74D),
                          size: 32,
                          shadows: [
                            Shadow(
                              color: const Color(0xFFFFB74D).withOpacity(0.45),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${_greetingForNow()}, ${HabitStore.instance.displayName}!',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ) ??
                                const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildStatsBox(),
                    const SizedBox(height: 25),
                    const Text(
                      "Today's Habit",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    ..._buildHabitSection(context),
                  ],
                ),
              ),
            ),
          ),

          if (_navBarHeight > _minHeight)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: (1.0 - _calculateOpacity(maxHeight)) * 15,
                  sigmaY: (1.0 - _calculateOpacity(maxHeight)) * 15,
                ),
                child: Container(color: Colors.black.withOpacity(0.2 * (1.0 - _calculateOpacity(maxHeight)))),
              ),
            ),

          Positioned(
            top: 0, left: 0, right: 0,
            height: _navBarHeight,
            child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1B3A),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(_navBarHeight >= maxHeight ? 0 : 30)),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onVerticalDragUpdate:
                            _navBarHeight < maxHeight ? _onPanelVerticalDragUpdate : null,
                        onVerticalDragEnd:
                            _navBarHeight < maxHeight ? _onPanelVerticalDragEnd : null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Opacity(
                                opacity: _getIconOpacity(),
                                child: IgnorePointer(
                                  ignoring: _navBarHeight > _minHeight + 10,
                                  child: IconButton(
                                    icon: const Icon(Icons.menu, color: Colors.white, size: 26),
                                    onPressed: () {},
                                  ),
                                ),
                              ),
                              Opacity(
                                opacity: _getIconOpacity(),
                                child: IgnorePointer(
                                  ignoring: _navBarHeight > _minHeight + 10,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.dark_mode_outlined, color: Colors.white, size: 22),
                                        onPressed: () {},
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.smart_toy_outlined, color: Color(0xFF00D9FF), size: 22),
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

                      if (_navBarHeight > 250)
                        Expanded(
                          child: NotificationListener<ScrollNotification>(
                            onNotification: (ScrollNotification n) {
                              if (n is ScrollEndNotification) {
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (mounted) _resumeBabyDragonVideo();
                                });
                              }
                              return false;
                            },
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(24, 10, 24, 140),
                              child: Column(
                                children: [
                                IconButton(
                                  icon: const Icon(Icons.keyboard_arrow_up, color: Colors.white, size: 30),
                                  onPressed: () => setState(() => _navBarHeight = _minHeight),
                                ),
                                const Text("My Companions", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 20),
                                _buildCompanionVideoFrame(),
                                const SizedBox(height: 20),

                                // statistical progressive bar
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("Bond level", style: TextStyle(color: Colors.white70, fontSize: 14)),
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius:  BorderRadius.circular(10),
                                      child: LinearProgressIndicator(
                                        value: HabitStore.instance.bondProgress,
                                        minHeight: 12,
                                        backgroundColor: Colors.white10,
                                        color: const Color(0xFF00D9FF),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 25),
                                _menuItem(
                                  Icons.favorite,
                                  "Companion Status",
                                  "Get new skins and accessories",
                                  onTap: () => _showCompanionStatusSheet(context),
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
                            onVerticalDragUpdate:
                                _navBarHeight < maxHeight ? _onPanelVerticalDragUpdate : null,
                            onVerticalDragEnd:
                                _navBarHeight < maxHeight ? _onPanelVerticalDragEnd : null,
                            child: const ColoredBox(color: Colors.transparent),
                          ),
                        ),

                      if (_navBarHeight < maxHeight)
                        GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onVerticalDragUpdate: _onPanelVerticalDragUpdate,
                          onVerticalDragEnd: _onPanelVerticalDragEnd,
                          onTap: () {
                            setState(() {
                              _navBarHeight =
                                  _navBarHeight > screenHeight * 0.25 ? _minHeight : maxHeight;
                            });
                          },
                          child: SizedBox(
                            height: 40,
                            width: double.infinity,
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: Container(
                                height: 5,
                                width: 65,
                                margin: const EdgeInsets.only(top: 6),
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

  Widget _buildVerticalStat(String title, String value, double progress, Color color, {String unit = ''}) {
    double barWidth = 40.0;
    double maxHeight = 110.0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        const SizedBox(height: 10),
        Stack(
          alignment: Alignment.bottomCenter,
          children: [
            // Background track
            Container(
              height: maxHeight,
              width: barWidth,
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12)
              ),
            ),
            // Wave Animated Progress
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AnimatedBuilder(
                animation: _waveController,
                builder: (context, child) {
                  return CustomPaint(
                    size: Size(barWidth, maxHeight),
                    painter: WavePainter(
                      color: color,
                      progress: progress,
                      waveValue: _waveController.value,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
            if (unit.isNotEmpty) ...[
              const SizedBox(width: 2),
              Text(unit, style: TextStyle(color: color.withOpacity(0.85), fontWeight: FontWeight.w600, fontSize: 11)),
            ],
          ],
        ),
      ],
    );
  }

  // --- REST OF HELPERS ---

  Widget _buildStatsBox() {
    final s = HabitStore.instance;
    final tp = s.todayProgressFraction;
    final fm = s.estimatedFocusMinutesToday;
    final focusVal = fm <= 0 ? '0' : (fm < 60 ? '$fm' : (fm / 60).toStringAsFixed(fm >= 600 ? 0 : 1));
    final focusUnit = fm >= 60 ? 'h' : 'm';
    final curProg = s.habits.isEmpty ? 0.0 : (s.currentStreak / 30.0).clamp(0.0, 1.0);
    final bestProg = s.bestStreakRecorded == 0 ? 0.0 : (s.bestStreakRecorded / 60.0).clamp(0.0, 1.0);
    return Container(
      width: double.infinity, height: 250,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 22),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildVerticalStat("current\nStreak", '${s.currentStreak}', curProg, Colors.orange),
          _buildVerticalStat("Today's\nProgress", '${(tp * 100).round()}%', tp.clamp(0.0, 1.0), Colors.orange),
          _buildVerticalStat("Focus\nTime", focusVal, (fm / 120.0).clamp(0.0, 1.0), Colors.orange, unit: focusUnit),
          _buildVerticalStat("Best\nStreak", '${s.bestStreakRecorded}', bestProg, Colors.orange),
        ],
      ),
    );
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
          title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          subtitle: Text(subtitle, style: const TextStyle(color: Colors.white60)),
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
                    BoxShadow(color: Colors.black54, blurRadius: 24, offset: Offset(0, -4)),
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
                            icon: const Icon(Icons.close, color: Colors.white70),
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
                child: const Icon(Icons.pets, color: Color(0xFF00D9FF), size: 28),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Baby Dragon',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Stage · Hatchling',
                      style: TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF00D9FF).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Lv. ${HabitStore.instance.level}',
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
          const Text('Bond level', style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: HabitStore.instance.bondProgress,
              minHeight: 10,
              backgroundColor: Colors.white10,
              color: const Color(0xFF00D9FF),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(HabitStore.instance.bondProgress * 100).round()}% bond · grows with check-ins',
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
              Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 2),
              Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
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
                    color: unlocked ? const Color(0xFF00D9FF).withOpacity(0.4) : Colors.white12,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      e.$2,
                      color: unlocked ? const Color(0xFF00D9FF) : Colors.white30,
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
                            style: TextStyle(color: unlocked ? Colors.white54 : Colors.white30, fontSize: 11),
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
      ('Teen Dragon form', 'Reach bond level 100%'),
      ('Monster skin set', 'Top 10 weekly leaderboard'),
      ('Legendary aura', '30-day login streak'),
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
                const Icon(Icons.lock_open_outlined, color: Color(0xFF00D9FF), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.$1, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(r.$2, style: const TextStyle(color: Colors.white54, fontSize: 12)),
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

  Widget _buildCompanionVideoFrame() {
    return Center(
      child: Container(
        width: 220,
        height: 220,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [Color(0xFF00D9FF), Color(0xFF6A5CFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00D9FF).withOpacity(0.25),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Container(
            color: const Color(0xFF10142B),
            child: _babyDragonController.value.isInitialized
                ? AspectRatio(
                    aspectRatio: _babyDragonController.value.aspectRatio,
                    child: VideoPlayer(_babyDragonController),
                  )
                : const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Color(0xFF00D9FF),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildGamificationSection() {
    final s = HabitStore.instance;
    final pts = s.totalPoints;
    final lvl = s.level;
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
            "Points & level from habits you complete (saved on device).",
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                  child: const Icon(Icons.person, size: 20, color: Color(0xFF00D9FF)),
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
                        '${s.habits.length} active habit${s.habits.length == 1 ? '' : 's'} · ${s.totalCompletions} total check-ins',
                        style: const TextStyle(color: Colors.white60, fontSize: 12),
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
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
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
              const Text('No habits yet', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                'Tap + to open the habit panel (name, category, templates). Use the activity wheel from there if you prefer. Tap a card to mark today done.',
                style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 13, height: 1.35),
              ),
              const SizedBox(height: 14),
              TextButton.icon(
                onPressed: _showHabitCreatePanel,
                icon: const Icon(Icons.add_circle_outline, color: Color(0xFF00D9FF)),
                label: const Text('Add habit', style: TextStyle(color: Color(0xFF00D9FF), fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ];
    }
    return store.habits.map((h) => _habitTile(context, h)).toList();
  }

  Widget _habitTile(BuildContext context, Habit h) {
    final store = HabitStore.instance;
    final done = store.isCompletedOn(h.id, DateTime.now());
    final streak = store.habitStreak(h.id);
    final icon = _iconForHabitCategory(h.category);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => store.toggleCompleteToday(h.id),
          onLongPress: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: const Color(0xFF1A1B3A),
                title: const Text('Remove habit?', style: TextStyle(color: Colors.white)),
                content: Text('Delete “${h.title}” and its history?', style: TextStyle(color: Colors.white.withOpacity(0.8))),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                ],
              ),
            );
            if (ok == true) await store.removeHabit(h.id);
          },
          child: Stack(
            children: [
              Positioned(
                left: 4,
                right: 0,
                top: 4,
                child: Container(
                  height: 80,
                  decoration: BoxDecoration(color: const Color(0xFF15162B), borderRadius: BorderRadius.circular(22)),
                ),
              ),
              Container(
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: done
                        ? [const Color(0xFF1A3D3D), const Color(0xFF1F3038)]
                        : [const Color(0xFF2A2B4A), const Color(0xFF1F203A)],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: done ? const Color(0xFF00D9FF).withOpacity(0.45) : Colors.transparent),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00D9FF).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: const Color(0xFF00D9FF), size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              h.title,
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              done ? 'Done today · streak $streak d' : 'Streak: $streak days · tap to check in',
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: done ? const Color(0xFF00D9FF) : Colors.white24,
                        child: Icon(done ? Icons.check : Icons.circle_outlined, color: Colors.white, size: 18),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showStatsPanel() {
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

  Widget _buildBottomNavBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1B3A),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(Icons.home, "Home", true),
            _navItem(Icons.pie_chart, "stats", false, onTap: _showStatsPanel),
            const SizedBox(width: 50),
            _navItem(Icons.calendar_today, "Calendar", false, onTap: _showCalendarPanel),
            _navItem(Icons.groups_rounded, "Social", false, onTap: _showSocialPanel),
          ],
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, bool isActive, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isActive ? const Color(0xFF00D9FF) : Colors.white),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: isActive ? const Color(0xFF00D9FF) : Colors.white, fontSize: 12))
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
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF00D9FF);
    final monthLabel = _monthName(_visibleMonth.month);
    final firstWeekday = _visibleMonth.weekday; // Mon=1
    final leading = firstWeekday - 1;
    final daysInMonth = DateUtils.getDaysInMonth(_visibleMonth.year, _visibleMonth.month);
    final totalCells = ((leading + daysInMonth + 6) ~/ 7) * 7;
    final selectedEvents =
        _selectedDay == null ? const <String>[] : HabitStore.instance.dayLabels(_selectedDay!);

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
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  border: Border.all(color: accent.withOpacity(0.5)),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text('Plan+Track', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(colors: [Color(0xFF1B2742), Color(0xFF142035)]),
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
                        style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      onPressed: () => _changeMonth(1),
                      icon: const Icon(Icons.chevron_right, color: Colors.white),
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
                    final day = DateTime(_visibleMonth.year, _visibleMonth.month, dayNum);
                    final isToday = DateUtils.isSameDay(day, DateTime.now());
                    final isSelected = _selectedDay != null && DateUtils.isSameDay(_selectedDay!, day);
                    final hasEvent = HabitStore.instance.countCompletedOn(day) > 0;
                    return InkWell(
                      borderRadius: BorderRadius.circular(11),
                      onTap: () => setState(() => _selectedDay = day),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(11),
                          color: isSelected ? accent.withOpacity(0.2) : Colors.white.withOpacity(0.04),
                          border: Border.all(
                            color: isSelected
                                ? accent
                                : (isToday ? const Color(0xFFFF8A00).withOpacity(0.7) : Colors.white10),
                          ),
                        ),
                        child: Stack(
                          children: [
                            Center(
                              child: Text(
                                '$dayNum',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.95),
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
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
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                if (selectedEvents.isEmpty)
                  Text(
                    'No habit check-ins logged this day. Complete habits from Home — they appear here.',
                    style: TextStyle(color: Colors.white.withOpacity(0.62), fontSize: 12),
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
                            child: Icon(Icons.fiber_manual_record, size: 8, color: Color(0xFF00D9FF)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              e,
                              style: TextStyle(color: Colors.white.withOpacity(0.88), fontSize: 13),
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
        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11, fontWeight: FontWeight.w700),
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

class _StatsInsightSheetState extends State<_StatsInsightSheet> with SingleTickerProviderStateMixin {
  late final AnimationController _sweep;

  static const _mint = Color(0xFF5DFFC4);
  static const _violet = Color(0xFF9D7DFF);
  static const _deep = Color(0xFF0A1220);

  @override
  void initState() {
    super.initState();
    _sweep = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    HabitStore.instance.addListener(_onHabits);
  }

  void _onHabits() => setState(() {});

  @override
  void dispose() {
    HabitStore.instance.removeListener(_onHabits);
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = HabitStore.instance;
    final score = s.focusScore();
    final ringProgress = (score / 100.0).clamp(0.0, 1.0);
    final fm = s.estimatedFocusMinutesToday;
    final deepVal = fm <= 0 ? '0' : (fm < 60 ? '$fm' : (fm / 60).toStringAsFixed(fm >= 600 ? 0 : 1));
    final deepUnit = fm >= 60 ? 'h' : 'm';
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF0E1A32),
            _deep,
            const Color(0xFF060A12),
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: _mint.withOpacity(0.22)),
        boxShadow: [
          BoxShadow(color: _violet.withOpacity(0.15), blurRadius: 40, offset: const Offset(0, -12)),
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
                  gradient: RadialGradient(colors: [_mint.withOpacity(0.12), Colors.transparent]),
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.12)),
                      color: const Color(0xFF152238).withOpacity(0.9),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.date_range, size: 16, color: _violet.withOpacity(0.9)),
                        const SizedBox(width: 6),
                        Text(
                          'This week',
                          style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Live read on focus, habits, and momentum — no boring tables.',
                style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 12, height: 1.35),
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
                                    Shadow(color: _mint.withOpacity(0.5), blurRadius: 24),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'FOCUS SCORE',
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
                                style: TextStyle(color: _mint.withOpacity(0.9), fontSize: 11, fontWeight: FontWeight.w600),
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
                  Expanded(child: _statGlassTile('Streak', '${s.currentStreak}', 'days', Icons.local_fire_department)),
                  const SizedBox(width: 10),
                  Expanded(child: _statGlassTile('Habits', '${s.habits.length}', 'active', Icons.check_circle_outline)),
                  const SizedBox(width: 10),
                  Expanded(child: _statGlassTile('Deep work', deepVal, deepUnit, Icons.hourglass_top)),
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
                style: TextStyle(color: Colors.white.withOpacity(0.42), fontSize: 10, fontWeight: FontWeight.w600),
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

  Widget _statGlassTile(String label, String value, String unit, IconData icon) {
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
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 2),
              Text(unit, style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 10, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.8),
          ),
        ],
      ),
    );
  }

  Widget _momentumStrip() {
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final values = HabitStore.instance.last7DayIntensity();
    final avgPct = (HabitStore.instance.avgDailyCompletionLast7 * 100).round();
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
              Text('Daily completion', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
              Text('avg $avgPct%', style: TextStyle(color: _mint.withOpacity(0.9), fontSize: 11, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(7, (i) {
              final h = math.max(6.0, 56.0 * values[i]);
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
                              _violet.withOpacity(0.25 + 0.35 * values[i]),
                              _mint.withOpacity(0.45 + 0.35 * values[i]),
                            ],
                          ),
                          boxShadow: [BoxShadow(color: _mint.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 2))],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(labels[i], style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10, fontWeight: FontWeight.w600)),
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
    final intensities = HabitStore.instance.last7DayIntensity();
    const brightGreen = Color(0xFF00FF88);
    const brightRed = Color(0xFFFF3355);
    return Row(
      children: List.generate(7, (i) {
        final t = i < intensities.length ? intensities[i] : 0.0;
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
                    colors: [
                      hub.withOpacity(glow),
                      const Color(0xFF0D1526),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(color: hub.withOpacity(0.12 + 0.2 * t), blurRadius: 10, spreadRadius: 0),
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
    final fr = HabitStore.instance.categoryFractions();
    final items = <(String, IconData, double, Color)>[
      ('Focus', Icons.center_focus_strong, fr['focus'] ?? 0, const Color(0xFF5DFFC4)),
      ('Move', Icons.directions_run, fr['move'] ?? 0, const Color(0xFF7AB6FF)),
      ('Mind', Icons.spa_outlined, fr['mind'] ?? 0, const Color(0xFF9D7DFF)),
      ('Learn', Icons.menu_book, fr['learn'] ?? 0, const Color(0xFFFFB86A)),
    ];
    return Column(
      children: [
        for (final (name, icon, pct, col) in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Icon(icon, color: col.withOpacity(0.9), size: 20),
                const SizedBox(width: 8),
                SizedBox(
                  width: 52,
                  child: Text(
                    name,
                    style: TextStyle(color: Colors.white.withOpacity(0.82), fontSize: 12, fontWeight: FontWeight.w700),
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
                            gradient: LinearGradient(colors: [col.withOpacity(0.2), col]),
                            boxShadow: [BoxShadow(color: col.withOpacity(0.35), blurRadius: 8)],
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
                    style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12, fontWeight: FontWeight.w700),
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
          colors: [
            _mint.withOpacity(0.08),
            _violet.withOpacity(0.06),
          ],
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
            child: Icon(Icons.auto_awesome, color: _mint.withOpacity(0.95), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Next win',
                  style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5),
                ),
                const SizedBox(height: 4),
                Text(
                  HabitStore.instance.insightNudgeBody(),
                  style: TextStyle(color: Colors.white.withOpacity(0.82), fontSize: 13, height: 1.35),
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
    canvas.drawCircle(
      dot,
      7,
      Paint()..color = accent.withOpacity(0.95),
    );
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

class _SocialArenaSheetState extends State<_SocialArenaSheet> with TickerProviderStateMixin {
  late final AnimationController _pulse;
  late final AnimationController _blink;

  static const _magenta = Color(0xFFFF00C8);
  static const _cyan = Color(0xFF00F5FF);
  static const _lime = Color(0xFFBFFF00);
  static const _voidBg = Color(0xFF070014);

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..repeat(reverse: true);
    _blink = AnimationController(vsync: this, duration: const Duration(milliseconds: 720))..repeat(reverse: true);
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
            BoxShadow(color: _magenta.withOpacity(0.25), blurRadius: 40, spreadRadius: -4, offset: const Offset(-6, -4)),
            BoxShadow(color: _cyan.withOpacity(0.2), blurRadius: 36, spreadRadius: -6, offset: const Offset(8, 0)),
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
                  colors: [
                    Color(0xFF120028),
                    _voidBg,
                    Color(0xFF0A1628),
                  ],
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
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
              children: [
                Center(
                  child: Container(
                    width: 120,
                    height: 6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      gradient: LinearGradient(
                        colors: [_magenta.withOpacity(0.9), _cyan.withOpacity(0.9), _lime.withOpacity(0.85)],
                      ),
                      boxShadow: [
                        BoxShadow(color: _cyan.withOpacity(0.5), blurRadius: 12),
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
                                shaderCallback: (bounds) => const LinearGradient(
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
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withOpacity(0.22),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.redAccent.withOpacity(0.85), width: 1.5),
                              boxShadow: [
                                BoxShadow(color: Colors.redAccent.withOpacity(0.45), blurRadius: 14),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.fiber_manual_record, color: Colors.redAccent, size: 10),
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
                    Expanded(child: _skewStat(_formatPts(habit.totalPoints), 'POINTS', _cyan)),
                    const SizedBox(width: 10),
                    Expanded(child: _skewStat('${habit.totalCompletions}', 'DONE', _lime)),
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
                _battleRow('Morning Movers', 'You vs 4 • focus sprint', '2H', Icons.directions_run, 0),
                _battleRow('Mindful Crew', 'Meditation relay', 'TONIGHT', Icons.spa_outlined, 1),
                _battleRow('Readers Club', 'Pages gauntlet', 'WKND', Icons.menu_book, 2),
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
                  style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 11),
                ),
                const SizedBox(height: 12),
                ...List<Widget>.generate(leaderboardRows.length, (i) {
                  final row = leaderboardRows[i];
                  return _leaderboardRow(rank: i + 1, name: row.name, points: row.points);
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
                    _ArenaDeployChip(icon: Icons.chat_bubble_outline, label: 'SQUAD CHAT'),
                    _ArenaDeployChip(icon: Icons.flag_outlined, label: 'SET GOAL'),
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
        Positioned(left: 2, top: 1, child: Text(text, style: _titleStyle.copyWith(color: _magenta.withOpacity(0.65)))),
        Positioned(left: -2, top: -1, child: Text(text, style: _titleStyle.copyWith(color: _cyan.withOpacity(0.7)))),
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
                shadows: [Shadow(color: accent.withOpacity(0.5), blurRadius: 10)],
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
    final left = s.habits.where((h) => !s.isCompletedOn(h.id, DateTime.now())).length;
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
          BoxShadow(color: _magenta.withOpacity(0.2), blurRadius: 24, offset: const Offset(0, 8)),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _TicketPerforationPainter(color: Colors.white.withOpacity(0.12)),
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
                      shaderCallback: (b) => LinearGradient(colors: [_lime, _cyan]).createShader(b),
                      child: const Text(
                        'TODAY',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 2),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Resets midnight',
                      style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  s.habits.isEmpty
                      ? 'Add habits from Home, then check them off to build your score.'
                      : 'Complete every habit today for a perfect day. $left habit${left == 1 ? '' : 's'} left.',
                  style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.35),
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
                            gradient: LinearGradient(colors: [_magenta, _cyan, _lime]),
                            boxShadow: [BoxShadow(color: _cyan.withOpacity(0.6), blurRadius: 12)],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${(tp * 100).round()}% of today\'s habits done',
                  style: TextStyle(color: _cyan.withOpacity(0.85), fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _leaderboardRow({required int rank, required String name, required int points}) {
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
    final ptsLabel = points >= 1000 ? '${(points / 1000).toStringAsFixed(1)}K' : '$points';
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
                  shadows: [Shadow(color: rankAccent.withOpacity(0.4), blurRadius: 8)],
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

  Widget _battleRow(String title, String subtitle, String badge, IconData icon, int index) {
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
              left: BorderSide(color: index == 0 ? _magenta : index == 1 ? _cyan : _lime, width: 4),
            ),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 12, offset: const Offset(4, 4))],
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
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 12)),
                  ],
                ),
              ),
              Transform.rotate(
                angle: math.pi / 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
              BoxShadow(color: Colors.black.withOpacity(0.5), offset: const Offset(3, 4), blurRadius: 0),
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
    final c1 = Color.lerp(const Color(0x33FF00C8), const Color(0x3300F5FF), phase)!;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (double x = -size.height; x < size.width + size.height; x += 32) {
      paint.color = c1.withOpacity(0.08 + 0.06 * phase);
      canvas.drawLine(Offset(x, 0), Offset(x + size.height * 0.85, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 40) {
      paint.color = const Color(0x22FFFFFF);
      canvas.drawLine(Offset(0, y + phase * 20), Offset(size.width, y + phase * 20), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ArenaGridPainter oldDelegate) => oldDelegate.phase != phase;
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
  bool shouldRepaint(covariant _TicketPerforationPainter oldDelegate) => oldDelegate.color != color;
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
  if (s.contains('motivat') || s.contains('lazy') || s.contains("can't") || s.contains('hard')) {
    return "Motivation is unreliable—build a cue instead. After something you already do every day "
        "(coffee, brushing teeth), stack your new habit. Start so small it feels silly to skip.";
  }
  if (s.contains('start') || s.contains('begin') || s.contains('new habit')) {
    return "One habit at a time. Name it clearly, pick Focus / Move / Mind / Learn, and add it in Kultivate. "
        "Use the **Open habit creator** chip below when you’re ready to lock it in.";
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
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.82),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
          color: isUser ? cyan.withOpacity(0.22) : const Color(0xFF0F1023),
          border: Border.all(color: isUser ? cyan.withOpacity(0.35) : Colors.white.withOpacity(0.1)),
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
          BoxShadow(color: Colors.black54, blurRadius: 24, offset: Offset(0, -4)),
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
                  child: const Icon(Icons.smart_toy_rounded, color: cyan, size: 26),
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
                            style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 12),
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
                    labelStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    backgroundColor: const Color(0xFF0F1023),
                    side: BorderSide(color: Colors.white.withOpacity(0.14)),
                    onPressed: () => _sendUserText('How do I start a new habit?'),
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    label: const Text('Streaks'),
                    labelStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    backgroundColor: const Color(0xFF0F1023),
                    side: BorderSide(color: Colors.white.withOpacity(0.14)),
                    onPressed: () => _sendUserText('Tell me about streaks'),
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    label: const Text('Motivation'),
                    labelStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    backgroundColor: const Color(0xFF0F1023),
                    side: BorderSide(color: Colors.white.withOpacity(0.14)),
                    onPressed: () => _sendUserText('I struggle with motivation'),
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: const Icon(Icons.add_circle_outline, color: cyan, size: 18),
                    label: const Text('Open habit creator'),
                    labelStyle: const TextStyle(color: cyan, fontSize: 12, fontWeight: FontWeight.w700),
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
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.35)),
                      filled: true,
                      fillColor: const Color(0xFF0F1023),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: cyan, width: 1.2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
  });

  final ScrollController scrollController;
  final VoidCallback onOpenActivityWheel;

  @override
  State<_HabitCreateSheet> createState() => _HabitCreateSheetState();
}

class _HabitCreateSheetState extends State<_HabitCreateSheet> {
  final TextEditingController _titleCtrl = TextEditingController();
  String _category = 'focus';
  bool _saving = false;

  static const List<(String id, String label)> _categories = [
    ('focus', 'Focus'),
    ('move', 'Move'),
    ('mind', 'Mind'),
    ('learn', 'Learn'),
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final t = _titleCtrl.text.trim();
    if (t.isEmpty || _saving) return;
    setState(() => _saving = true);
    await HabitStore.instance.addHabit(title: t, category: _category);
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

  @override
  Widget build(BuildContext context) {
    const cyan = Color(0xFF00D9FF);
    final canSubmit = _titleCtrl.text.trim().isNotEmpty && !_saving;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1B3A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(color: Colors.black54, blurRadius: 24, offset: Offset(0, -4)),
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
                TextField(
                  controller: _titleCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'What will you track?',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.45)),
                    labelText: 'Habit name',
                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.65)),
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
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 22),
                Text(
                  'Category',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final (id, label) in _categories)
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => setState(() => _category = id),
                          borderRadius: BorderRadius.circular(14),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: _category == id ? cyan.withOpacity(0.18) : const Color(0xFF0F1023),
                              border: Border.all(
                                color: _category == id ? cyan : Colors.white.withOpacity(0.12),
                                width: _category == id ? 1.4 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _iconForHabitCategory(id),
                                  size: 20,
                                  color: _category == id ? cyan : Colors.white54,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  label,
                                  style: TextStyle(
                                    color: _category == id ? Colors.white : Colors.white70,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Quick templates',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (label, icon) in _kActivityPresets)
                      ActionChip(
                        avatar: Icon(icon, size: 18, color: cyan),
                        label: Text(label),
                        labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                        backgroundColor: const Color(0xFF0F1023),
                        side: BorderSide(color: Colors.white.withOpacity(0.14)),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        onPressed: () => _applyTemplate(label),
                      ),
                  ],
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: canSubmit ? _submit : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: cyan,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.white24,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                          )
                        : const Text('Add habit', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton.icon(
                    onPressed: widget.onOpenActivityWheel,
                    icon: const Icon(Icons.blur_circular, color: Color(0xFF00D9FF), size: 20),
                    label: const Text(
                      'Activity wheel instead',
                      style: TextStyle(color: Color(0xFF00D9FF), fontWeight: FontWeight.w600),
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
    this.onAfterCustomHabit,
  });

  final Offset fabTopLeft;
  final Size fabSize;
  final VoidCallback onClose;
  final Future<void> Function(String title, String category)? onPickActivity;
  final Future<void> Function()? onAfterCustomHabit;

  @override
  State<RadialActivityPickerOverlay> createState() => _RadialActivityPickerOverlayState();
}

class _RadialActivityPickerOverlayState extends State<RadialActivityPickerOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final AnimationController _orbitController;
  late final Animation<double> _expand;
  bool _dismissing = false;

  static const List<(String label, IconData icon)> _activities = _kActivityPresets;

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
    _expand = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
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
    // Larger radius + wider arc = more space between each circular slot.
    const radius = 175.0;
    const chipW = 76.0;
    const chipH = 92.0;
    final n = _activities.length;
    final startAngle = -math.pi / 2 - math.pi / 1.72;
    final endAngle = -math.pi / 2 + math.pi / 1.72;

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
                child: Container(
                  color: Colors.black.withOpacity(0.18),
                ),
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
            final vignetteX = ((curHubX / mqSize.width).clamp(0.001, 0.999)) * 2 - 1;
            final vignetteY = ((curHubY / mqSize.height).clamp(0.001, 0.999)) * 2 - 1;
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
                        await _dismiss();
                        if (widget.onAfterCustomHabit != null) {
                          await widget.onAfterCustomHabit!();
                        }
                      },
                      child: Container(
                        width: widget.fabSize.width,
                        height: widget.fabSize.height,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF00D9FF).withOpacity(0.12 * t.clamp(0, 1)),
                          border: Border.all(
                            color: const Color(0xFF00D9FF).withOpacity(0.55 * t.clamp(0, 1)),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00D9FF).withOpacity(0.45 * t.clamp(0, 1)),
                              blurRadius: 28,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Text(
                          'Custom',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withOpacity((0.2 + 0.8 * t).clamp(0.0, 1.0)),
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            letterSpacing: 0.4,
                            height: 1.0,
                            shadows: const [
                              Shadow(color: Colors.black87, blurRadius: 8, offset: Offset(0, 1)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                ...List<Widget>.generate(n, (i) {
                  final baseAngle = n <= 1
                      ? -math.pi / 2
                      : startAngle + (endAngle - startAngle) * (i / (n - 1));
                  // Slow continuous orbit around the center "Custom" hub.
                  final angle = baseAngle + orbitPhase;
                  final r = radius * t;
                  final dx = math.cos(angle) * r;
                  final dy = math.sin(angle) * r;
                  final (String label, IconData icon) = _activities[i];
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
                          onTap: () async {
                            if (widget.onPickActivity != null) {
                              await widget.onPickActivity!(label, _categoryForRadialLabel(label));
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
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    const cyan = Color(0xFF00D9FF);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withOpacity(0.82),
              border: Border.all(color: cyan.withOpacity(0.65), width: 2),
              boxShadow: [
                BoxShadow(
                  color: cyan.withOpacity(0.35),
                  blurRadius: 14,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Icon(icon, size: 26, color: cyan),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 76,
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withOpacity(0.95),
                fontWeight: FontWeight.w700,
                fontSize: 11,
                height: 1.1,
                shadows: const [
                  Shadow(color: Colors.black87, blurRadius: 6, offset: Offset(0, 1)),
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

  WavePainter({required this.color, required this.progress, required this.waveValue});

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
        startY + math.sin((i / size.width * 2 * math.pi) + (waveValue * 2 * math.pi)) * 4,
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
        startY + math.cos((i / size.width * 2 * math.pi) + (waveValue * 2 * math.pi)) * 4,
      );
    }

    path2.lineTo(size.width, size.height);
    path2.close();

    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant WavePainter oldDelegate) => true;
}