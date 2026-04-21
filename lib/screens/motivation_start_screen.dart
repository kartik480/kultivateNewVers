import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kultivate_new_ver/screens/login_screen.dart';

/// Three motivational cards (left / center / right). Each horizontal swipe folds
/// the next card downward (rotation around the top edge), then continues to login.
class MotivationStartScreen extends StatefulWidget {
  const MotivationStartScreen({super.key});

  @override
  State<MotivationStartScreen> createState() => _MotivationStartScreenState();
}

class _MotivationStartScreenState extends State<MotivationStartScreen>
    with TickerProviderStateMixin {
  static const _cyan = Color(0xFF00D9FF);
  static const _bgTop = Color(0xFF121A2E);
  static const _bgBottom = Color(0xFF070B15);

  late final AnimationController _flipLeft;
  late final AnimationController _flipMid;
  late final AnimationController _flipRight;

  int _step = 0;
  bool _busy = false;
  bool _exited = false;

  static const List<_MotivationCopy> _cards = [
    _MotivationCopy(
      icon: Icons.wb_sunny_outlined,
      title: 'Start tiny',
      body: 'One honest check-in today beats a perfect plan you never touch.',
    ),
    _MotivationCopy(
      icon: Icons.auto_graph_rounded,
      title: 'Stack the wins',
      body: 'Small repeats compound. You are not behind — you are building the curve.',
    ),
    _MotivationCopy(
      icon: Icons.favorite_outline_rounded,
      title: 'Stay kind',
      body: 'Miss a day, not the story. Come back; your streak is the habit of returning.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    const dur = Duration(milliseconds: 720);
    _flipLeft = AnimationController(vsync: this, duration: dur);
    _flipMid = AnimationController(vsync: this, duration: dur);
    _flipRight = AnimationController(vsync: this, duration: dur);
  }

  @override
  void dispose() {
    _flipLeft.dispose();
    _flipMid.dispose();
    _flipRight.dispose();
    super.dispose();
  }

  Future<void> _advance() async {
    if (_busy || _exited) return;
    if (_step >= 3) {
      _goLogin();
      return;
    }
    _busy = true;
    setState(() {});

    switch (_step) {
      case 0:
        await _flipLeft.forward();
        break;
      case 1:
        await _flipMid.forward();
        break;
      case 2:
        await _flipRight.forward();
        break;
    }

    if (!mounted) return;
    _step++;
    _busy = false;
    setState(() {});

    if (_step >= 3) {
      await Future<void>.delayed(const Duration(milliseconds: 420));
      if (mounted) _goLogin();
    }
  }

  void _goLogin() {
    if (_exited) return;
    _exited = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 700),
        reverseTransitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (context, animation, secondaryAnimation) {
          return const LoginScreen();
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          final slide = Tween<Offset>(
            begin: const Offset(0, 0.14),
            end: Offset.zero,
          ).animate(curved);
          final fade = Tween<double>(begin: 0, end: 1).animate(
            CurvedAnimation(
              parent: animation,
              curve: const Interval(0.0, 0.85, curve: Curves.easeOut),
            ),
          );
          
          return FadeTransition(
            opacity: fade,
            child: SlideTransition(
              position: slide,
              child: child,
            ),
          );
        },
      ),
    );
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    final v = details.primaryVelocity ?? 0;
    // Swipe right (finger moves right) or left — either clears the next card.
    if (v.abs() < 160) return;
    _advance();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgBottom,
      body: GestureDetector(
        onHorizontalDragEnd: _onHorizontalDragEnd,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_bgTop, _bgBottom],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      Text(
                        'Before you sign in',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.clickerScript(
                          fontSize: 38,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Swipe left or right — each move folds the next card forward until you are ready.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.geologica(
                          fontSize: 14,
                          height: 1.45,
                          color: Colors.white.withValues(alpha: 0.55),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      const gap = 6.0;
                      const hPad = 10.0;
                      final innerW = constraints.maxWidth - hPad * 2;
                      // Wide columns + tall tiles (not square) so body copy reads comfortably.
                      final cardW = (innerW - gap * 2) / 3;
                      final maxH = constraints.maxHeight * 0.88;
                      final targetH = (cardW * 1.72).clamp(cardW * 1.22, 232.0);
                      final cardH = math.min(maxH, targetH);
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: hPad),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: cardW,
                                height: cardH,
                                child: _FlipCard(
                                  width: cardW,
                                  height: cardH,
                                  controller: _flipLeft,
                                  copy: _cards[0],
                                  accent: _cyan,
                                ),
                              ),
                              SizedBox(width: gap),
                              SizedBox(
                                width: cardW,
                                height: cardH,
                                child: _FlipCard(
                                  width: cardW,
                                  height: cardH,
                                  controller: _flipMid,
                                  copy: _cards[1],
                                  accent: const Color(0xFFFFB56B),
                                ),
                              ),
                              SizedBox(width: gap),
                              SizedBox(
                                width: cardW,
                                height: cardH,
                                child: _FlipCard(
                                  width: cardW,
                                  height: cardH,
                                  controller: _flipRight,
                                  copy: _cards[2],
                                  accent: const Color(0xFF8AE9C1),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                _StepDots(step: _step.clamp(0, 3)),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _busy ? null : _advance,
                  child: Text(
                    _step >= 3 ? 'Opening…' : 'Tap to fold next card',
                    style: GoogleFonts.geologica(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _cyan.withValues(alpha: _busy ? 0.35 : 0.95),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MotivationCopy {
  const _MotivationCopy({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

class _FlipCard extends StatelessWidget {
  const _FlipCard({
    required this.width,
    required this.height,
    required this.controller,
    required this.copy,
    required this.accent,
  });

  final double width;
  final double height;
  final AnimationController controller;
  final _MotivationCopy copy;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = Curves.easeInCubic.transform(controller.value);
        final rot = t * 1.38;
        final opacity = (1.0 - Curves.easeIn.transform(t)).clamp(0.0, 1.0);
        final drop = t * (12.0 + height * 0.05);

        return Opacity(
          opacity: opacity,
          child: Transform(
            alignment: Alignment.topCenter,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0018)
              ..rotateX(rot),
            child: Transform.translate(
              offset: Offset(0, drop),
              child: SizedBox(
                width: width,
                height: height,
                child: _CardFace(
                  copy: copy,
                  accent: accent,
                  width: width,
                  height: height,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CardFace extends StatelessWidget {
  const _CardFace({
    required this.copy,
    required this.accent,
    required this.width,
    required this.height,
  });

  final _MotivationCopy copy;
  final Color accent;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final shortest = math.min(width, height);
    final radius = (shortest * 0.1).clamp(13.0, 18.0);
    final pad = (shortest * 0.065).clamp(10.0, 14.0);
    return Container(
      width: width,
      height: height,
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1B2742).withValues(alpha: 0.95),
            const Color(0xFF131B2E).withValues(alpha: 0.98),
          ],
        ),
        border: Border.all(color: accent.withValues(alpha: 0.45), width: 1.1),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(shortest * 0.05),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(radius * 0.65),
                ),
                child: Icon(
                  copy.icon,
                  color: accent,
                  size: (shortest * 0.13).clamp(18.0, 24.0),
                ),
              ),
            ],
          ),
          SizedBox(height: shortest * 0.038),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              copy.title,
              maxLines: 2,
              style: GoogleFonts.geologica(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.1,
              ),
            ),
          ),
          SizedBox(height: shortest * 0.032),
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) {
                return FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.topLeft,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: box.maxWidth),
                    child: Text(
                      copy.body,
                      style: GoogleFonts.geologica(
                        fontSize: 13.5,
                        height: 1.42,
                        color: Colors.white.withValues(alpha: 0.86),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StepDots extends StatelessWidget {
  const _StepDots({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final done = step > i;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width: done ? 22 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            color: done
                ? const Color(0xFF00D9FF).withValues(alpha: 0.85)
                : Colors.white.withValues(alpha: 0.18),
          ),
        );
      }),
    );
  }
}
