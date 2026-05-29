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
import 'profile/profile_setup_screen.dart';
import 'farm/farm_details_screen.dart';
import 'farm/farm_location_screen.dart';
import 'notifications/notifications_screen.dart';
import 'preferences/language_screen.dart';
import 'preferences/alert_tone_screen.dart';
import 'preferences/change_password_screen.dart';
import 'logout/logout_dialog.dart';
import '../crop_management/crop_list_screen.dart';
import '../support/support_screen.dart';
import 'legal/terms_of_service_screen.dart';
import 'legal/privacy_policy_screen.dart';
import 'legal/licenses_screen.dart';

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
  _ProfileCompletion? _completion;

  @override
  void initState() {
    super.initState();
    final stream = _notificationService.getUnreadCountStream();
    if (stream != null) {
      _unreadSub = stream.listen((count) {
        if (mounted) setState(() => _unreadCount = count);
      });
    }
    _loadCompletion();
  }

  Future<void> _loadCompletion() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final userDoc = await UserCounterService().getUserByAuthUid(user.uid);
      if (userDoc == null || !userDoc.exists) return;

      final cid = userDoc.id;
      final data = userDoc.data() as Map<String, dynamic>? ?? {};

      // Load farm details + location in parallel
      final detailsFuture = _firestore
          .collection('users').doc(cid).collection('farm').doc('details').get();
      final locationFuture = _firestore
          .collection('users').doc(cid).collection('farm').doc('location').get();

      final farmDoc = await detailsFuture;
      final locDoc = await locationFuture;

      if (!mounted) return;
      setState(() {
        _completion = _ProfileCompletion(
          hasPhoto: (data['photoURL'] as String?)?.isNotEmpty == true,
          hasPhone: (data['phone'] as String?)?.isNotEmpty == true,
          hasFarmName: (data['farm_name'] as String?)?.isNotEmpty == true,
          hasFarmSize: farmDoc.exists &&
              (farmDoc.data()?['size'] as num?)?.toDouble() != null &&
              ((farmDoc.data()?['size'] as num?)?.toDouble() ?? 0) > 0,
          hasLocation: locDoc.exists &&
              locDoc.data()?['latitude'] != null,
        );
      });
    } catch (_) {}
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Text(
                  l10n.t('Settings'),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: ThemeColors.textPrimary(context),
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Profile Card ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildProfileCard(),
              ),

              // ── Profile Completion Card ──
              if (_completion != null && !_completion!.isComplete) ...[
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildCompletionCard(),
                ),
              ],
              const SizedBox(height: 28),

              // ── Account Section ──
              _buildSectionLabel(l10n.t('Farm Management')),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildMenuCard([
                  _MenuItem(
                    icon: Icons.agriculture_outlined,
                    iconColor: AppColors.warning,
                    title: l10n.t('My Farm'),
                    subtitle: l10n.t('Farm profile, location & details'),
                    onTap: () => _navigateAndRefresh(const FarmDetailsScreen()),
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
              ),
              const SizedBox(height: 24),

              // ── Support Section ──
              _buildSectionLabel('Support'),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildMenuCard([
                  _MenuItem(
                    icon: Icons.headset_mic_outlined,
                    iconColor: AppColors.info,
                    title: 'Help & Support',
                    subtitle: 'Report an issue or get help',
                    onTap: () => _navigateTo(const SupportScreen()),
                  ),
                ]),
              ),
              const SizedBox(height: 24),

              // ── Preferences Section (includes Dark Mode toggle) ──
              _buildSectionLabel(l10n.t('Preferences')),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildMenuCard([
                  _MenuItem(
                    icon: Icons.language_outlined,
                    iconColor: AppColors.info,
                    title: l10n.t('Language'),
                    subtitle: LanguageNotifier.instance.languageCode == 'ms'
                        ? 'Bahasa Melayu'
                        : 'English',
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
              ),
              const SizedBox(height: 24),

              // ── Appearance Section ──
              _buildSectionLabel(l10n.t('Appearance')),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildDarkModeCard(l10n),
              ),
              const SizedBox(height: 24),

              // ── About Section ──
              _buildSectionLabel(l10n.t('About')),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildMenuCard([
                  _MenuItem(
                    icon: Icons.description_outlined,
                    iconColor: Colors.grey,
                    title: l10n.t('Terms of Service'),
                    onTap: () => _navigateTo(const TermsOfServiceScreen()),
                  ),
                  _MenuItem(
                    icon: Icons.privacy_tip_outlined,
                    iconColor: Colors.grey,
                    title: l10n.t('Privacy Policy'),
                    onTap: () => _navigateTo(const PrivacyPolicyScreen()),
                  ),
                  _MenuItem(
                    icon: Icons.library_books_outlined,
                    iconColor: AppColors.soilMoisture,
                    title: 'Data Sources & Licenses',
                    subtitle: 'FAO-56, UF/IFAS, UC IPM, NHB India',
                    onTap: () => _navigateTo(const LicensesScreen()),
                  ),
                ]),
              ),
              const SizedBox(height: 24),

              // ── Logout Button ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildLogoutButton(),
              ),
              const SizedBox(height: 16),

              // ── App version footer ──
              Center(
                child: Text(
                  'AgroEzuran • v1.0.0',
                  style: TextStyle(
                    fontSize: 12,
                    color: ThemeColors.textSecondary(context).withOpacity(0.4),
                  ),
                ),
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────
  // PROFILE CARD
  // ──────────────────────────────────────────
  Widget _buildProfileCard() {
    final user = _auth.currentUser;

    return FutureBuilder<DocumentSnapshot?>(
      future: user != null
          ? UserCounterService().getUserByAuthUid(user.uid)
          : null,
      builder: (context, userDocSnapshot) {
        if (!userDocSnapshot.hasData || userDocSnapshot.data == null) {
          return _profileCardContent(
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

            return _profileCardContent(
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

  Widget _profileCardContent({
    required String name,
    required String farmName,
    required String email,
    required String? photoURL,
  }) {
    return GestureDetector(
      onTap: () => _navigateAndRefresh(const ProfileScreen()),
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

  // ──────────────────────────────────────────
  // SECTION LABEL
  // ──────────────────────────────────────────
  Widget _buildSectionLabel(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: ThemeColors.textSecondary(context).withOpacity(0.45),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  // ──────────────────────────────────────────
  // MENU CARD
  // ──────────────────────────────────────────
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
              _buildMenuRow(item),
              if (!isLast)
                Divider(
                  height: 1,
                  color: ThemeColors.border(context),
                  indent: 58,
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMenuRow(_MenuItem item) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: item.iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(item.icon, color: item.iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: ThemeColors.textPrimary(context),
                    ),
                  ),
                  if (item.subtitle != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      item.subtitle!,
                      style: TextStyle(
                        fontSize: 12,
                        color: ThemeColors.textSecondary(context).withOpacity(0.5),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (item.badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  item.badge!,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            if (item.showArrow)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Icon(
                  Icons.chevron_right,
                  color: ThemeColors.icon(context).withOpacity(0.25),
                  size: 20,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────
  // DARK MODE CARD
  // ──────────────────────────────────────────
  Widget _buildDarkModeCard(AppLocalizations l10n) {
    final isDark = ThemeNotifier.instance.isDark;
    return Container(
      decoration: BoxDecoration(
        color: ThemeColors.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ThemeColors.border(context)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                color: AppColors.warning,
                size: 20,
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
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: ThemeColors.textPrimary(context),
                    ),
                  ),
                  Text(
                    isDark ? l10n.t('On') : l10n.t('Off'),
                    style: TextStyle(
                      fontSize: 12,
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

  // ──────────────────────────────────────────
  // LOGOUT BUTTON
  // ──────────────────────────────────────────
  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: _showLogoutDialog,
        icon: const Icon(Icons.logout_rounded, size: 20),
        label: Text(AppLocalizations.of(context).t('Log Out')),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.error,
          side: BorderSide(color: AppColors.error.withOpacity(0.4)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────
  // PROFILE COMPLETION CARD
  // ──────────────────────────────────────────
  Widget _buildCompletionCard() {
    final c = _completion!;
    final score = c.score;
    final pct = (score / 5 * 100).round();

    // Missing items: label, icon, navigation target
    final missing = <({String label, IconData icon, VoidCallback onTap})>[];
    if (!c.hasPhoto) missing.add((
      label: 'Profile Photo',
      icon: Icons.camera_alt_rounded,
      onTap: () => _navigateAndRefresh(const ProfileScreen()),
    ));
    if (!c.hasPhone) missing.add((
      label: 'Phone Number',
      icon: Icons.phone_outlined,
      onTap: () => _navigateAndRefresh(const ProfileScreen()),
    ));
    if (!c.hasFarmName || !c.hasFarmSize) missing.add((
      label: 'Farm Details',
      icon: Icons.agriculture_outlined,
      onTap: () => _navigateAndRefresh(const FarmDetailsScreen()),
    ));
    if (!c.hasLocation) missing.add((
      label: 'Farm Location',
      icon: Icons.location_on_rounded,
      onTap: () => _navigateAndRefresh(const FarmLocationScreen()),
    ));

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ThemeColors.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.35)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.stars_rounded,
                  color: Color(0xFFF59E0B),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Complete Your Profile',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: ThemeColors.textPrimary(context),
                      ),
                    ),
                    Text(
                      '$pct% complete • $score of 5 items done',
                      style: TextStyle(
                        fontSize: 12,
                        color: ThemeColors.textSecondary(context).withOpacity(0.55),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 5,
              minHeight: 6,
              backgroundColor: ThemeColors.border(context),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
            ),
          ),

          const SizedBox(height: 14),

          // Missing items as tappable chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: missing.map((item) => GestureDetector(
              onTap: item.onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: ThemeColors.bg(context),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ThemeColors.border(context)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(item.icon, size: 13, color: const Color(0xFFF59E0B)),
                    const SizedBox(width: 5),
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 12,
                        color: ThemeColors.textSecondary(context).withOpacity(0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.add_circle_outline_rounded,
                      size: 12,
                      color: ThemeColors.textSecondary(context).withOpacity(0.4),
                    ),
                  ],
                ),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateAndRefresh(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) _loadCompletion(); // Refresh score after returning
  }

  void _navigateTo(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  void _showLogoutDialog() {
    showDialog(context: context, builder: (context) => const LogoutDialog());
  }
}

// ──────────────────────────────────────────
// PROFILE COMPLETION MODEL
// ──────────────────────────────────────────
class _ProfileCompletion {
  final bool hasPhoto;
  final bool hasPhone;
  final bool hasFarmName;
  final bool hasFarmSize;
  final bool hasLocation;

  const _ProfileCompletion({
    required this.hasPhoto,
    required this.hasPhone,
    required this.hasFarmName,
    required this.hasFarmSize,
    required this.hasLocation,
  });

  int get score =>
      (hasPhoto ? 1 : 0) +
      (hasPhone ? 1 : 0) +
      (hasFarmName ? 1 : 0) +
      (hasFarmSize ? 1 : 0) +
      (hasLocation ? 1 : 0);

  bool get isComplete => score == 5;
}

// ──────────────────────────────────────────
// MENU ITEM MODEL
// ──────────────────────────────────────────
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
