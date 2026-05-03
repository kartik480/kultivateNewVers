import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kultivate_new_ver/screens/login_screen.dart';

/// Pre–sign-in intro: horizontal pages with parallax. Each scene draws parN.png
/// behind and imgN.png in front (img1 over par1, img2 over par2, …).
class MotivationStartScreen extends StatefulWidget {
  const MotivationStartScreen({super.key});

  @override
  State<MotivationStartScreen> createState() => _MotivationStartScreenState();
}

class _MotivationStartScreenState extends State<MotivationStartScreen> {
  static const _cyan = Color(0xFF00D9FF);
  static const _bgTop = Color(0xFF121A2E);
  static const _bgBottom = Color(0xFF070B15);

  late final PageController _pageController;
  int _currentPage = 0;
  bool _exited = false;

  static const _slides = <({
    String foreground,
    String background,
    String motivation,
  })>[
    (
      foreground: 'images/img1.png',
      background: 'images/par1.png',
      motivation: 'One slow breath—the path only asks for today.',
    ),
    (
      foreground: 'images/img2.png',
      background: 'images/par2.png',
      motivation: 'Keep going—gentle steps still widen the view.',
    ),
    (
      foreground: 'images/img3.png',
      background: 'images/par3.png',
      motivation: "Bring this calm with you—step inside when you're ready.",
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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

  Future<void> _nextOrSignIn() async {
    if (_exited) return;
    final i = _pageController.hasClients
        ? (_pageController.page?.round() ?? _currentPage)
        : _currentPage;
    if (i < _slides.length - 1) {
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    } else {
      _goLogin();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgBottom,
      body: Container(
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
          child: Stack(
            children: [
              Positioned(
                top: -70,
                left: -40,
                child: IgnorePointer(
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          _cyan.withValues(alpha: 0.12),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: -60,
                bottom: 120,
                child: IgnorePointer(
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Color(0x22FFB56B),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Column(
                children: [
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF172540).withValues(alpha: 0.92),
                            const Color(0xFF0F172B).withValues(alpha: 0.9),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _cyan.withValues(alpha: 0.14),
                            blurRadius: 26,
                            spreadRadius: -8,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              color: _cyan.withValues(alpha: 0.14),
                              border: Border.all(color: _cyan.withValues(alpha: 0.45)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.auto_awesome_rounded, size: 14, color: _cyan.withValues(alpha: 0.95)),
                                const SizedBox(width: 6),
                                Text(
                                  'START RITUAL',
                                  style: GoogleFonts.geologica(
                                    color: Colors.white.withValues(alpha: 0.92),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10.5,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Before you sign in',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.greatVibes(
                              fontSize: 45,
                              color: Colors.white,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 6),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 260),
                            switchInCurve: Curves.easeOut,
                            switchOutCurve: Curves.easeIn,
                            transitionBuilder: (child, animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: child,
                              );
                            },
                            child: Text(
                              _slides[_currentPage.clamp(0, _slides.length - 1)]
                                  .motivation,
                              key: ValueKey<int>(_currentPage),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.geologica(
                                fontSize: 13.5,
                                height: 1.45,
                                color: Colors.white.withValues(alpha: 0.62),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: _slides.length,
                        onPageChanged: (i) => setState(() => _currentPage = i),
                        itemBuilder: (context, index) {
                          final s = _slides[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: _ParallaxSlide(
                              pageController: _pageController,
                              pageIndex: index,
                              foregroundAsset: s.foreground,
                              backgroundAsset: s.background,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  _StepDots(page: _currentPage.clamp(0, _slides.length - 1)),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _exited ? null : _nextOrSignIn,
                    child: Text(
                      _currentPage >= _slides.length - 1 ? 'Sign in' : 'Next',
                      style: GoogleFonts.geologica(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _cyan.withValues(alpha: _exited ? 0.35 : 0.95),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One intro scene: [backgroundAsset] is drawn first (par — depth / sky),
/// [foregroundAsset] on top (img — closer props / figures). Transparent
/// areas on img let par show through. While the [PageView] scrolls, layers move in
/// opposite horizontal directions for parallax.
class _ParallaxSlide extends StatelessWidget {
  const _ParallaxSlide({
    required this.pageController,
    required this.pageIndex,
    required this.foregroundAsset,
    required this.backgroundAsset,
  });

  final PageController pageController;
  final int pageIndex;
  final String foregroundAsset;
  final String backgroundAsset;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: AnimatedBuilder(
            animation: pageController,
            builder: (context, _) {
              final page = pageController.hasClients
                  ? (pageController.page ?? pageIndex.toDouble())
                  : pageIndex.toDouble();
              // How far this page is from the scroll position (fractional while dragging).
              final rel = page - pageIndex;
              // Back layer (par): smaller shift; front layer (img): larger opposite shift.
              // Higher factors = stronger / “faster-feeling” parallax while paging.
              const backFactor = 92.0;
              const frontFactor = 140.0;
              final oxBack = rel * backFactor;
              final oxFront = -rel * frontFactor;
              // Extra width so translated layers don’t show empty strips at the card edges.
              final over = w * 0.52;

              Widget layer(String asset, double dx) {
                return Transform.translate(
                  offset: Offset(dx, 0),
                  child: Align(
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: w + over * 2,
                      height: h,
                      child: Image.asset(
                        asset,
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                  ),
                );
              }

              return Stack(
                fit: StackFit.expand,
                children: [
                  layer(backgroundAsset, oxBack),
                  layer(foregroundAsset, oxFront),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _StepDots extends StatelessWidget {
  const _StepDots({required this.page});

  final int page;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final active = i == page;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width: active ? 22 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            color: active
                ? const Color(0xFF00D9FF).withValues(alpha: 0.85)
                : Colors.white.withValues(alpha: 0.18),
          ),
        );
      }),
    );
  }
}
