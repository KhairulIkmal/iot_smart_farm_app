import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/theme.dart';
import '../../core/app_localizations.dart';
import '../../core/language_notifier.dart';
import '../../core/theme_notifier.dart';
import '../../services/notifications/notification_service.dart';
import '../../services/user_counter_service.dart';
import 'profile/profile_screen.dart';
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
  final NotificationService _notificationService = NotificationService();

  int _unreadCount = 0;
  StreamSubscription<int>? _unreadSub;

  @override
  void initState() {
    super.initState();
    final stream = _notificationService.getUnreadCountStream();
    if (stream != null) {
      _unreadSub = stream.listen((count) {
        if (mounted) setState(() => _unreadCount = count);
      });
    }
  }

  @override
  void dispose() {
    _unreadSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: ThemeColors.bg(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                l10n.t('Settings'),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: ThemeColors.textPrimary(context),
                ),
              ),
              const SizedBox(height: 24),

              // Profile Card
              _buildProfileCard(),
              const SizedBox(height: 24),

              // Farm Management Section
              _buildSectionTitle(l10n.t('Farm Management')),
              const SizedBox(height: 12),
              _buildMenuCard([
                _MenuItem(
                  icon: Icons.agriculture_outlined,
                  iconColor: AppColors.warning,
                  title: l10n.t('My Farm'),
                  subtitle: l10n.t('Farm profile, location & details'),
                  onTap: () => _navigateTo(const FarmDetailsScreen()),
                ),
                _MenuItem(
                  icon: Icons.eco_outlined,
                  iconColor: AppColors.soilMoisture,
                  title: l10n.t('Crop Management'),
                  subtitle: l10n.t('Manage farm information'),
                  onTap: () => _navigateTo(const CropListScreen()),
                ),
                _MenuItem(
                  icon: Icons.notifications_outlined,
                  iconColor: AppColors.error,
                  title: l10n.t('Notifications'),
                  subtitle: l10n.t('Alerts and updates'),
                  badge: _unreadCount > 0 ? '$_unreadCount' : null,
                  onTap: () => _navigateTo(const NotificationsScreen()),
                ),
              ]),
              const SizedBox(height: 24),

              // Preferences Section
              _buildSectionTitle(l10n.t('Preferences')),
              const SizedBox(height: 12),
              _buildMenuCard([
                _MenuItem(
                  icon: Icons.language_outlined,
                  iconColor: AppColors.info,
                  title: l10n.t('Language'),
                  subtitle: LanguageNotifier.instance.languageCode == 'ms' ? 'Bahasa Melayu' : 'English',
                  onTap: () => _navigateTo(const LanguageScreen()),
                ),
                _MenuItem(
                  icon: Icons.volume_up_outlined,
                  iconColor: AppColors.phLevel,
                  title: l10n.t('Alert Tones'),
                  subtitle: l10n.t('Sound settings'),
                  onTap: () => _navigateTo(const AlertToneScreen()),
                ),
                _MenuItem(
                  icon: Icons.lock_outline,
                  iconColor: AppColors.temperature,
                  title: l10n.t('Change Password'),
                  subtitle: l10n.t('Update your password'),
                  onTap: () => _navigateTo(const ChangePasswordScreen()),
                ),
              ]),
              const SizedBox(height: 24),

              // Appearance Section
              _buildSectionTitle(l10n.t('Appearance')),
              const SizedBox(height: 12),
              _buildAppearanceCard(l10n),
              const SizedBox(height: 24),

              // App Info
              _buildSectionTitle(l10n.t('About')),
              const SizedBox(height: 12),
              _buildMenuCard([
                _MenuItem(
                  icon: Icons.info_outline,
                  iconColor: Colors.grey,
                  title: l10n.t('App Version'),
                  subtitle: 'v1.0.0',
                  showArrow: false,
                  onTap: () {},
                ),
                _MenuItem(
                  icon: Icons.description_outlined,
                  iconColor: Colors.grey,
                  title: l10n.t('Terms of Service'),
                  onTap: () {},
                ),
                _MenuItem(
                  icon: Icons.privacy_tip_outlined,
                  iconColor: Colors.grey,
                  title: l10n.t('Privacy Policy'),
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

    return FutureBuilder<DocumentSnapshot?>(
      future: user != null
          ? UserCounterService().getUserByAuthUid(user.uid)
          : null,
      builder: (context, userDocSnapshot) {
        if (!userDocSnapshot.hasData || userDocSnapshot.data == null) {
          return _buildProfileCardContent(
            name: 'User',
            farmName: 'My Farm',
            email: user?.email ?? '',
            photoURL: null,
          );
        }

        final customUserId = userDocSnapshot.data!.id;

        return StreamBuilder<DocumentSnapshot>(
          stream: _firestore.collection('users').doc(customUserId).snapshots(),
          builder: (context, snapshot) {
            String name = 'User';
            String farmName = 'My Farm';
            String email = user?.email ?? '';
            String? photoURL;

            if (snapshot.hasData && snapshot.data!.exists) {
              final data = snapshot.data!.data() as Map<String, dynamic>?;
              name = data?['name'] ?? data?['displayName'] ?? 'User';
              farmName = data?['farm_name'] ?? 'My Farm';
              photoURL = data?['photoURL'];
            }

            return _buildProfileCardContent(
              name: name,
              farmName: farmName,
              email: email,
              photoURL: photoURL,
            );
          },
        );
      },
    );
  }

  Widget _buildProfileCardContent({
    required String name,
    required String farmName,
    required String email,
    required String? photoURL,
  }) {
    return GestureDetector(
      onTap: () => _navigateTo(const ProfileScreen()),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: ThemeColors.surface(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: ThemeColors.border(context)),
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
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: photoURL != null
                  ? ClipOval(
                      child: Image.network(
                        photoURL,
                        width: 70,
                        height: 70,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : 'U',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          );
                        },
                      ),
                    )
                  : Center(
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
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: ThemeColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    farmName,
                    style: TextStyle(
                      fontSize: 14,
                      color: ThemeColors.textSecondary(context).withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: TextStyle(
                      fontSize: 13,
                      color: ThemeColors.textSecondary(context).withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: ThemeColors.icon(context).withOpacity(0.5)),
          ],
        ),
      ),
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
          color: ThemeColors.textSecondary(context).withOpacity(0.5),
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
        color: ThemeColors.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ThemeColors.border(context)),
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
                Divider(height: 1, color: ThemeColors.border(context), indent: 60),
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
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: ThemeColors.textPrimary(context),
                    ),
                  ),
                  if (item.subtitle != null)
                    Text(
                      item.subtitle!,
                      style: TextStyle(
                        fontSize: 13,
                        color: ThemeColors.textSecondary(context).withOpacity(0.5),
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
                  color: ThemeColors.icon(context).withOpacity(0.3),
                  size: 22,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// ------------------------------------------------
  /// APPEARANCE CARD
  /// ------------------------------------------------
  Widget _buildAppearanceCard(AppLocalizations l10n) {
    final isDark = ThemeNotifier.instance.isDark;
    return Container(
      decoration: BoxDecoration(
        color: ThemeColors.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ThemeColors.border(context)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                color: AppColors.warning,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.t('Dark Mode'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: ThemeColors.textPrimary(context),
                    ),
                  ),
                  Text(
                    isDark ? l10n.t('On') : l10n.t('Off'),
                    style: TextStyle(
                      fontSize: 13,
                      color: ThemeColors.textSecondary(context).withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: isDark,
              onChanged: (_) => ThemeNotifier.instance.toggle(),
              activeColor: AppColors.primary,
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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.logout, size: 22),
            const SizedBox(width: 10),
            Text(
              AppLocalizations.of(context).t('Log Out'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
