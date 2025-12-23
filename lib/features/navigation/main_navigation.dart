import 'package:flutter/material.dart';

import '../dashboard/dashboard_screen.dart';
import '../sensors/sensors_screen.dart';
import '../irrigation/irrigation_screen.dart';
import '../chatbot/ai_chatbot_screen.dart';
import '../more/more_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    SensorsScreen(),
    IrrigationScreen(),
    AiChatbotScreen(),
    MoreScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  index: 0,
                  icon: Icons.dashboard_outlined,
                  activeIcon: Icons.dashboard,
                  label: 'Home',
                ),
                _buildNavItem(
                  index: 1,
                  icon: Icons.show_chart,
                  activeIcon: Icons.show_chart,
                  label: 'Sensors',
                ),
                _buildNavItem(
                  index: 2,
                  icon: Icons.water_drop_outlined,
                  activeIcon: Icons.water_drop,
                  label: 'Water',
                ),
                _buildNavItem(
                  index: 3,
                  icon: Icons.smart_toy_outlined,
                  activeIcon: Icons.smart_toy,
                  label: 'AI Assist',
                ),
                _buildNavItem(
                  index: 4,
                  icon: Icons.menu,
                  activeIcon: Icons.menu,
                  label: 'More',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final bool isSelected = _currentIndex == index;
    final Color activeColor = const Color(0xFF2E7D32); // Green
    final Color inactiveColor = Colors.grey.shade600;

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              size: 26,
              color: isSelected ? activeColor : inactiveColor,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? activeColor : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
