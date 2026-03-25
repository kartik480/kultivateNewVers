import 'package:flutter/material.dart';
import 'dart:ui';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  double _navBarHeight = 120.0;
  final double _minHeight = 120.0;

  double _calculateOpacity(double maxHeight) {
    double opacity = 1.0 - ((_navBarHeight - _minHeight) / (maxHeight * 0.6 - _minHeight));
    return opacity.clamp(0.0, 1.0);
  }

  double _getIconOpacity() {
    double fade = 1.0 - ((_navBarHeight - _minHeight) / 30);
    return fade.clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double maxHeight = screenHeight;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1023),
      extendBody: true,
      bottomNavigationBar: _buildBottomNavBar(),
      floatingActionButton: Transform.translate(
        offset: const Offset(0, 27),
        child: Container(
          height: 70, width: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(colors: [Color(0xFF00D9FF), Color(0xFF00D8FF)]),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 20, spreadRadius: 2)],
          ),
          child: IconButton(
            icon: const Icon(Icons.add, color: Colors.white, size: 32),
            onPressed: () {},
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      body: Stack(
        children: [
          // 1. HOME PANEL CONTENT
          Positioned.fill(
            child: Opacity(
              opacity: _calculateOpacity(maxHeight),
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: 170, left: 16, right: 16, bottom: 150),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatsBox(),
                    const SizedBox(height: 25),
                    const Text(
                      "Today's Habit",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    _habitCard(),
                    _habitCard(),
                    _habitCard(),
                  ],
                ),
              ),
            ),
          ),

          // 2. BLUR OVERLAY
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

          // 3. DRAGGABLE HEADER
          Positioned(
            top: 0, left: 0, right: 0,
            height: _navBarHeight,
            child: GestureDetector(
              onVerticalDragUpdate: (details) {
                setState(() {
                  _navBarHeight = (_navBarHeight + details.delta.dy).clamp(_minHeight, maxHeight);
                });
              },
              onVerticalDragEnd: (details) {
                setState(() {
                  if (_navBarHeight > screenHeight * 0.25) {
                    _navBarHeight = maxHeight;
                  } else {
                    _navBarHeight = _minHeight;
                  }
                });
              },
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
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween, // Pushes icons to far edges
                          children: [
                            // LEFT MENU ICON
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

                            // RIGHT ICONS
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
                                      onPressed: () {},
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (_navBarHeight > 250)
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                            child: Column(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.keyboard_arrow_up, color: Colors.white, size: 30),
                                  onPressed: () => setState(() => _navBarHeight = _minHeight),
                                ),
                                const Text("Daily Statistics", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 20),
                                _menuItem(Icons.auto_graph, "Weekly Progress", "Consistency is up 12%"),
                                _menuItem(Icons.history, "History", "Review your last 30 days"),
                                _menuItem(Icons.emoji_events, "Achievements", "4 new badges unlocked"),
                              ],
                            ),
                          ),
                        )
                      else
                        const Spacer(),

                      if (_navBarHeight < maxHeight)
                        Container(
                          height: 5, width: 65,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(color: const Color(0xFF00D9FF), borderRadius: BorderRadius.circular(50)),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- UI HELPERS ---

  Widget _menuItem(IconData icon, String title, String subtitle) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 10),
      leading: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFF00D9FF).withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
        child: Icon(icon, color: const Color(0xFF00D9FF)),
      ),
      title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white60)),
    );
  }

  Widget _buildStatsBox() {
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
          _buildVerticalStat("current\nStreak", "12", 0.6, Colors.orange),
          _buildVerticalStat("Today's\nProgress", "75%", 0.75, Colors.cyan),
          _buildVerticalStat("Focus\nTime", "2h", 0.75, Colors.cyan),
          _buildVerticalStat("Best\nStreak", "30", 0.9, Colors.purple),
        ],
      ),
    );
  }

  Widget _buildVerticalStat(String title, String value, double progress, Color color) {
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
            Container(height: maxHeight, width: barWidth, decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(12))),
            Container(
              height: maxHeight * progress, width: barWidth,
              decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, spreadRadius: 1)],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }

  Widget _habitCard() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Stack(
        children: [
          Positioned(
            left: 4, right: 0, top: 4,
            child: Container(height: 80, decoration: BoxDecoration(color: const Color(0xFF15162B), borderRadius: BorderRadius.circular(22))),
          ),
          Container(
            height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF2A2B4A), Color(0xFF1F203A)]),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFF00D9FF).withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.menu_book, color: Color(0xFF00D9FF), size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Read 10 Pages", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text("Streak: 12 days", style: TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ),
                  const CircleAvatar(radius: 14, backgroundColor: Color(0xFF00D9FF), child: Icon(Icons.check, color: Colors.white, size: 18)),
                ],
              ),
            ),
          ),
        ],
      ),
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
            _navItem(Icons.pie_chart, "stats", false),
            const SizedBox(width: 50),
            _navItem(Icons.calendar_today, "Calendar", false),
            _navItem(Icons.settings, "Settings", false),
          ],
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, bool isActive) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: isActive ? const Color(0xFF00D9FF) : Colors.white),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: isActive ? const Color(0xFF00D9FF) : Colors.white, fontSize: 12))
      ],
    );
  }
}