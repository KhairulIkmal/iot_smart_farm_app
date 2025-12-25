import 'package:flutter/material.dart';

import '../../core/theme.dart';
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
      extendBody: true, // Allow body to extend behind nav bar
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.backgroundDark.withOpacity(0.95),
          border: Border(
            top: BorderSide(
              color: AppColors.borderDark,
              width: 1,
            ),
          ),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 64,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Main navigation items
                Row(
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
                    // Empty space for floating button
                    const SizedBox(width: 56),
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
                // Floating center button
                Positioned(
                  left: MediaQuery.of(context).size.width / 2 - 28,
                  top: -24,
                  child: _buildFloatingButton(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingButton() {
    final bool isSelected = _currentIndex == 2;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _currentIndex = 2;
            });
          },
          child: Container(
            height: 56,
            width: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppColors.primary,
                  AppColors.primary.withOpacity(0.9),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: AppColors.backgroundDark,
                width: 4,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              isSelected ? Icons.water_drop : Icons.water_drop_outlined,
              color: Colors.black,
              size: 28,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Control',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: isSelected ? AppColors.textSecondaryDark : AppColors.textSecondaryDark.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final bool isSelected = _currentIndex == index;

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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              size: 24,
              color: isSelected ? AppColors.primary : AppColors.textSecondaryDark.withOpacity(0.6),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.textSecondaryDark.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
