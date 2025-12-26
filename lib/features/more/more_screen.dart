import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/theme.dart';
import 'profile/profile_screen.dart';
import 'farm/farm_location_screen.dart';
import 'farm/farm_details_screen.dart';
import 'notifications/notifications_screen.dart';
import 'preferences/language_screen.dart';
import 'preferences/alert_tone_screen.dart';
import 'preferences/change_password_screen.dart';
import 'logout/logout_dialog.dart';
import '../crop_management/crop_list_screen.dart';

/// ------------------------------------------------------------
/// MORE SCREEN (SETTINGS HUB)
///
/// Shows:
/// - User Profile Card
/// - Farm Management Section
/// - Preferences Section
/// - Logout Button
/// ------------------------------------------------------------
class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                'Settings',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),

              // Profile Card
              _buildProfileCard(),
              const SizedBox(height: 24),

              // Farm Management Section
              _buildSectionTitle('Farm Management'),
              const SizedBox(height: 12),
              _buildMenuCard([
                _MenuItem(
                  icon: Icons.location_on_outlined,
                  iconColor: AppColors.primary,
                  title: 'Farm Location',
                  subtitle: 'Set location for weather',
                  onTap: () => _navigateTo(const FarmLocationScreen()),
                ),
                _MenuItem(
                  icon: Icons.agriculture_outlined,
                  iconColor: AppColors.warning,
                  title: 'Farm Details',
                  subtitle: 'Manage farm information',
                  onTap: () => _navigateTo(const FarmDetailsScreen()),
                ),
                _MenuItem(
                  icon: Icons.eco_outlined,
                  iconColor: AppColors.soilMoisture,
                  title: 'Crop Management',
                  subtitle: 'Manage farm information',
                  onTap: () => _navigateTo(const CropListScreen()),
                ),
                _MenuItem(
                  icon: Icons.notifications_outlined,
                  iconColor: AppColors.error,
                  title: 'Notifications',
                  subtitle: 'Alerts and updates',
                  badge: '3',
                  onTap: () => _navigateTo(const NotificationsScreen()),
                ),
              ]),
              const SizedBox(height: 24),

              // Preferences Section
              _buildSectionTitle('Preferences'),
              const SizedBox(height: 12),
              _buildMenuCard([
                _MenuItem(
                  icon: Icons.language_outlined,
                  iconColor: AppColors.info,
                  title: 'Language',
                  subtitle: 'English',
                  onTap: () => _navigateTo(const LanguageScreen()),
                ),
                _MenuItem(
                  icon: Icons.volume_up_outlined,
                  iconColor: AppColors.phLevel,
                  title: 'Alert Tones',
                  subtitle: 'Sound settings',
                  onTap: () => _navigateTo(const AlertToneScreen()),
                ),
                _MenuItem(
                  icon: Icons.lock_outline,
                  iconColor: AppColors.temperature,
                  title: 'Change Password',
                  subtitle: 'Update your password',
                  onTap: () => _navigateTo(const ChangePasswordScreen()),
                ),
              ]),
              const SizedBox(height: 24),

              // App Info
              _buildSectionTitle('About'),
              const SizedBox(height: 12),
              _buildMenuCard([
                _MenuItem(
                  icon: Icons.info_outline,
                  iconColor: Colors.grey,
                  title: 'App Version',
                  subtitle: 'v1.0.0',
                  showArrow: false,
                  onTap: () {},
                ),
                _MenuItem(
                  icon: Icons.description_outlined,
                  iconColor: Colors.grey,
                  title: 'Terms of Service',
                  onTap: () {},
                ),
                _MenuItem(
                  icon: Icons.privacy_tip_outlined,
                  iconColor: Colors.grey,
                  title: 'Privacy Policy',
                  onTap: () {},
                ),
              ]),
              const SizedBox(height: 24),

              // Logout Button
              _buildLogoutButton(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  /// ------------------------------------------------
  /// PROFILE CARD
  /// ------------------------------------------------
  Widget _buildProfileCard() {
    final user = _auth.currentUser;

    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('users').doc(user?.uid).snapshots(),
      builder: (context, snapshot) {
        String name = 'User';
        String farmName = 'My Farm';
        String email = user?.email ?? '';

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          name = data?['name'] ?? data?['displayName'] ?? 'User';
          farmName = data?['farm_name'] ?? 'My Farm';
        }

        return GestureDetector(
          onTap: () => _navigateTo(const ProfileScreen()),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.borderDark),
            ),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        farmName,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        email,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.5)),
              ],
            ),
          ),
        );
      },
    );
  }

  /// ------------------------------------------------
  /// SECTION TITLE
  /// ------------------------------------------------
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white.withOpacity(0.5),
          letterSpacing: 1,
        ),
      ),
    );
  }

  /// ------------------------------------------------
  /// MENU CARD
  /// ------------------------------------------------
  Widget _buildMenuCard(List<_MenuItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isLast = index == items.length - 1;

          return Column(
            children: [
              _buildMenuItem(item),
              if (!isLast)
                Divider(height: 1, color: AppColors.borderDark, indent: 60),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMenuItem(_MenuItem item) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: item.iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(item.icon, color: item.iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  if (item.subtitle != null)
                    Text(
                      item.subtitle!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.5),
                      ),
                    ),
                ],
              ),
            ),
            if (item.badge != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  item.badge!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            if (item.showArrow)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(
                  Icons.chevron_right,
                  color: Colors.white.withOpacity(0.3),
                  size: 22,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// ------------------------------------------------
  /// LOGOUT BUTTON
  /// ------------------------------------------------
  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: () => _showLogoutDialog(),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.error,
          side: BorderSide(color: AppColors.error.withOpacity(0.5)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout, size: 22),
            SizedBox(width: 10),
            Text(
              'Log Out',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateTo(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  void _showLogoutDialog() {
    showDialog(context: context, builder: (context) => const LogoutDialog());
  }
}

/// Menu Item Model
class _MenuItem {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final String? badge;
  final bool showArrow;
  final VoidCallback onTap;

  _MenuItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.badge,
    this.showArrow = true,
    required this.onTap,
  });
}
