import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kultivate_new_ver/screens/motivation_start_screen.dart';

/// Cold-open ritual before auth: orbital sigil, gradient wordmark, tap-to-skip.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _orbit;
  late final AnimationController _intro;
  late final Animation<double> _reveal;
  late final Animation<double> _titleFade;
  late final Animation<double> _titleLift;
  late final Animation<double> _barProgress;
  bool _left = false;

  @override
  void initState() {
    super.initState();
    _orbit = AnimationController(vsync: this, duration: const Duration(seconds: 14))..repeat();

    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _reveal = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.0, 0.75, curve: Curves.easeOutCubic),
    );
    _titleFade = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.12, 0.55, curve: Curves.easeOut),
    );
    _titleLift = Tween<double>(begin: 18, end: 0).animate(
      CurvedAnimation(
        parent: _intro,
        curve: const Interval(0.1, 0.65, curve: Curves.easeOutCubic),
      ),
    );
    _barProgress = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _intro, curve: const Interval(0.05, 0.92, curve: Curves.easeInOutCubic)),
    );

    _intro.forward();
    unawaited(_exitAfterHold());
  }

  Future<void> _exitAfterHold() async {
    await Future<void>.delayed(const Duration(milliseconds: 3100));
    if (!mounted || _left) return;
    _goNext();
  }

  void _goNext() {
    if (_left) return;
    _left = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 640),
        pageBuilder: (context, animation, secondaryAnimation) {
          return const MotivationStartScreen();
        },
        transitionsBuilder: (context, animation, _, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            child: child,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _orbit.dispose();
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final side = math.min(size.width, size.height);

    return Scaffold(
      backgroundColor: const Color(0xFF03050C),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (_intro.value >= 0.2) _goNext();
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            const _VoidBackdrop(),
            AnimatedBuilder(
              animation: _orbit,
              builder: (context, _) {
                return CustomPaint(
                  painter: _NebulaDriftPainter(phase: _orbit.value * 2 * math.pi),
                  size: size,
                );
              },
            ),
            Center(
              child: AnimatedBuilder(
                animation: Listenable.merge([_orbit, _intro]),
                builder: (context, _) {
                  return CustomPaint(
                    size: Size.square(side * 0.95),
                    painter: _OrbitSigilPainter(
                      rotation: _orbit.value * 2 * math.pi,
                      reveal: _reveal.value,
                    ),
                  );
                },
              ),
            ),
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.02, -0.12),
                    radius: 1.05,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.5),
                    ],
                    stops: const [0.35, 1.0],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: AnimatedBuilder(
                  animation: _intro,
                  builder: (context, _) {
                    return Opacity(
                      opacity: _titleFade.value,
                      child: Transform.translate(
                        offset: Offset(0, _titleLift.value),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ShaderMask(
                              blendMode: BlendMode.srcIn,
                              shaderCallback: (bounds) {
                                return const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFFFFD1A1),
                                    Color(0xFF00D9FF),
                                    Color(0xFF8AE9C1),
                                  ],
                                  stops: [0.0, 0.48, 1.0],
                                ).createShader(bounds);
                              },
                              child: Text(
                                'KULTIVATE',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.geologica(
                                  fontSize: 40,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 6,
                                  height: 1.02,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'BUILD BETTER HABITS',
                              style: GoogleFonts.geologica(
                                fontSize: 12,
                                letterSpacing: 2.2,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.38),
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
            Positioned(
              left: 28,
              right: 28,
              bottom: 44,
              child: AnimatedBuilder(
                animation: _intro,
                builder: (context, _) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: _barProgress.value,
                          minHeight: 3,
                          backgroundColor: Colors.white.withValues(alpha: 0.07),
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00D9FF)),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Tap to continue',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.geologica(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.32),
                          letterSpacing: 0.15,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoidBackdrop extends StatelessWidget {
  const _VoidBackdrop();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.35),
          radius: 1.25,
          colors: [
            Color(0xFF152238),
            Color(0xFF0A0E1A),
            Color(0xFF03050C),
          ],
          stops: [0.0, 0.42, 1.0],
        ),
      ),
    );
  }
}

/// Soft cyan / ember fields that drift — no flat solid fill.
class _NebulaDriftPainter extends CustomPainter {
  _NebulaDriftPainter({required this.phase});

  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    void blob(Offset c, double radius, List<Color> colors) {
      final shader = RadialGradient(
        colors: colors,
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: c, radius: radius));
      canvas.drawCircle(c, radius, Paint()..shader = shader);
    }

    final w = size.width;
    final h = size.height;
    final o1 = Offset(
      w * 0.18 + math.sin(phase) * 16,
      h * 0.32 + math.cos(phase * 0.85) * 12,
    );
    final o2 = Offset(
      w * 0.82 + math.cos(phase * 0.7) * 14,
      h * 0.58 + math.sin(phase * 1.1) * 18,
    );
    final o3 = Offset(
      w * 0.52 + math.sin(phase * 1.3) * 22,
      h * 0.88 + math.cos(phase) * 10,
    );

    blob(
      o1,
      w * 0.42,
      [
        const Color(0xFF00D9FF).withValues(alpha: 0.14),
        const Color(0xFF00D9FF).withValues(alpha: 0.04),
        Colors.transparent,
      ],
    );
    blob(
      o2,
      w * 0.36,
      [
        const Color(0xFFFF8A00).withValues(alpha: 0.10),
        const Color(0xFFFF6B35).withValues(alpha: 0.03),
        Colors.transparent,
      ],
    );
    blob(
      o3,
      w * 0.28,
      [
        const Color(0xFF6B9FFF).withValues(alpha: 0.08),
        const Color(0xFF00D9FF).withValues(alpha: 0.02),
        Colors.transparent,
      ],
    );
  }

  @override
  bool shouldRepaint(covariant _NebulaDriftPainter old) => old.phase != phase;
}

/// Hand-drawn feeling orbit arcs — signature mark for the cold open.
class _OrbitSigilPainter extends CustomPainter {
  _OrbitSigilPainter({required this.rotation, required this.reveal});

  final double rotation;
  final double reveal;

  @override
  void paint(Canvas canvas, Size size) {
    if (reveal <= 0.001) return;

    final c = Offset(size.width / 2, size.height / 2);
    final baseR = size.shortestSide * 0.38;

    for (var i = 0; i < 5; i++) {
      final radius = baseR + i * 22.0;
      final start = rotation * (0.35 + i * 0.08) + i * 0.95;
      final sweep = math.pi * (1.05 + i * 0.06) * reveal;
      final t = i / 4.0;
      final cyan = Color.lerp(
        const Color(0xFF00D9FF),
        const Color(0xFF7CF0FF),
        t,
      )!;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.35 - i * 0.12
        ..strokeCap = StrokeCap.round
        ..color = cyan.withValues(alpha: (0.08 + 0.22 * (1 - t)) * reveal);

      canvas.drawArc(
        Rect.fromCircle(center: c, radius: radius),
        start,
        sweep,
        false,
        paint,
      );
    }

    // Inner spark ring
    final spark = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..color = const Color(0xFFFFB56B).withValues(alpha: 0.35 * reveal);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: baseR * 0.42),
      -math.pi / 2 + rotation * 0.5,
      math.pi * 1.4 * reveal,
      false,
      spark,
    );
  }

  @override
  bool shouldRepaint(covariant _OrbitSigilPainter old) =>
      old.rotation != rotation || old.reveal != reveal;
}
