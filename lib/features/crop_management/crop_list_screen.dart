import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../core/theme.dart';
import '../../auth/auth_service.dart';
import '../../services/selected_crop_service.dart';
import '../navigation/main_navigation.dart';
import 'claim_device_screen.dart';
import 'unclaim_device_dialog.dart';

/// ------------------------------------------------------------
/// CROP LIST SCREEN (CROP MANAGEMENT)
/// Shows:
/// - Stats (Active Plots, Available Devices)
/// - Available Devices (unclaimed ESP32)
/// - My Crops (user's claimed crops)
/// ------------------------------------------------------------
class CropListScreen extends StatefulWidget {
  final bool showBackButton;

  const CropListScreen({
    super.key,
    this.showBackButton = true,
  });

  @override
  State<CropListScreen> createState() => _CropListScreenState();
}

class _CropListScreenState extends State<CropListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseDatabase _rtdb = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();

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
              _buildHeader(),
              const SizedBox(height: 20),

              // Stats Cards
              _buildStatsCards(),
              const SizedBox(height: 24),

              // Available Devices Section
              _buildAvailableDevicesSection(),
              const SizedBox(height: 24),

              // My Crops Section
              _buildMyCropsSection(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  /// ------------------------------------------------
  /// HEADER
  /// ------------------------------------------------
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            if (widget.showBackButton)
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderDark),
                  ),
                  child: const Icon(
                    Icons.arrow_back,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
              ),
            if (widget.showBackButton) const SizedBox(width: 12),
            const Text(
              'Crop Management',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        if (!widget.showBackButton)
          GestureDetector(
            onTap: _handleLogout,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderDark),
              ),
              child: const Icon(
                Icons.logout,
                color: AppColors.error,
                size: 24,
              ),
            ),
          ),
      ],
    );
  }

  /// ------------------------------------------------
  /// STATS CARDS (Active Plots & Available Devices)
  /// ------------------------------------------------
  Widget _buildStatsCards() {
    final user = _auth.currentUser;

    return Row(
      children: [
        // Active Plots Card
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('crops')
                .where('farmer_id', isEqualTo: user?.uid)
                .where('status', isEqualTo: 'active')
                .snapshots(),
            builder: (context, snapshot) {
              final count = snapshot.data?.docs.length ?? 0;
              return _buildStatCard(
                icon: Icons.check_circle_outline,
                iconColor: AppColors.primary,
                label: 'ACTIVE',
                value: '$count Plots',
                backgroundColor: AppColors.primary.withOpacity(0.15),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        // Available Devices Card
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('devices')
                .where('status', isEqualTo: 'unassigned')
                .snapshots(),
            builder: (context, snapshot) {
              final count = snapshot.data?.docs.length ?? 0;
              return _buildStatCard(
                icon: Icons.sensors,
                iconColor: AppColors.primary,
                label: 'DEVICES',
                value: '$count Available',
                backgroundColor: AppColors.surfaceDark,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required Color backgroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.7),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// ------------------------------------------------
  /// AVAILABLE DEVICES SECTION
  /// ------------------------------------------------
  Widget _buildAvailableDevicesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Available Devices',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'New Found',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('devices')
              .where('status', isEqualTo: 'unassigned')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingCard();
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _buildEmptyDevicesCard();
            }

            final devices = snapshot.data!.docs;
            return Column(
              children: devices.map((device) {
                final deviceId = device.id;

                return _buildDeviceCard(deviceId: deviceId);
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDeviceCard({
    required String deviceId,
  }) {
    return StreamBuilder<DatabaseEvent>(
      stream: _rtdb.ref('sensors/$deviceId/live/lastSeen').onValue.asBroadcastStream(),
      builder: (context, snapshot) {
        bool isOnline = false;
        String statusText = 'No Signal';
        Color statusColor = AppColors.error;

        if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
          final lastSeen = snapshot.data!.snapshot.value as int;
          final lastSeenDate = DateTime.fromMillisecondsSinceEpoch(lastSeen);
          final diff = DateTime.now().difference(lastSeenDate);

          // Consider online if last seen within 10 seconds (same as dashboard)
          isOnline = diff.inSeconds < 10;

          if (isOnline) {
            statusText = 'Online';
            statusColor = AppColors.primary;
          } else if (diff.inMinutes < 5) {
            statusText = 'Weak Signal';
            statusColor = AppColors.warning;
          } else {
            statusText = 'No Signal';
            statusColor = AppColors.error;
          }
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderDark),
          ),
          child: Row(
            children: [
              // Device Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.backgroundDark,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.memory, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 14),
              // Device Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deviceId,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.wifi,
                          size: 14,
                          color: statusColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Assign Button
              ElevatedButton(
                onPressed: () => _navigateToClaimDevice(deviceId),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.backgroundDark,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Assign',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyDevicesCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Row(
        children: [
          Icon(
            Icons.devices_other,
            color: Colors.white.withOpacity(0.3),
            size: 32,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'No Devices Available',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'All ESP32 devices are currently assigned',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// ------------------------------------------------
  /// MY CROPS SECTION
  /// ------------------------------------------------
  Widget _buildMyCropsSection() {
    final user = _auth.currentUser;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'My Crops',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            TextButton(
              onPressed: () {
                // TODO: Navigate to all crops view
              },
              child: const Text(
                'View All',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('crops')
              .where('farmer_id', isEqualTo: user?.uid)
              .where('status', isEqualTo: 'active')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingCard();
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _buildEmptyCropsCard();
            }

            final crops = snapshot.data!.docs;
            return Column(
              children: crops.map((crop) {
                final cropId = crop.id;
                final data = crop.data() as Map<String, dynamic>;
                final cropType = data['crop_type'] as String? ?? 'Unknown';
                final deviceId = data['device_id'] as String? ?? '';
                final plantingDate = data['planting_date'] as Timestamp?;

                return _buildCropCard(
                  cropId: cropId,
                  cropType: cropType,
                  deviceId: deviceId,
                  plantingDate: plantingDate,
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCropCard({
    required String cropId,
    required String cropType,
    required String deviceId,
    Timestamp? plantingDate,
  }) {
    return GestureDetector(
      onTap: () => _navigateToDashboard(
        cropId: cropId,
        deviceId: deviceId,
        cropType: cropType,
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderDark),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Background Image
              Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      _getCropColor(cropType).withOpacity(0.3),
                      AppColors.backgroundDark,
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Icon(
                      _getCropIcon(cropType),
                      size: 80,
                      color: _getCropColor(cropType).withOpacity(0.3),
                    ),
                  ),
                ),
              ),
              // Content Overlay
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        AppColors.backgroundDark.withOpacity(0.9),
                        AppColors.backgroundDark,
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Monitoring Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'MONITORING',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Crop Name & Actions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$cropType - Field A',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.link,
                                      size: 14,
                                      color: AppColors.textSecondaryDark,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      deviceId,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondaryDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // More Options Button
                          Row(
                            children: [
                              // Unclaim Button
                              ElevatedButton(
                                onPressed: () => _showUnclaimDialog(
                                  cropId: cropId,
                                  deviceId: deviceId,
                                  cropType: cropType,
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.error.withOpacity(
                                    0.2,
                                  ),
                                  foregroundColor: AppColors.error,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  elevation: 0,
                                ),
                                child: const Text(
                                  'Delete',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceDark,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.more_horiz,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ],
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

  Widget _buildEmptyCropsCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Column(
        children: [
          Icon(
            Icons.eco_outlined,
            size: 48,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Crops Yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Assign an ESP32 device above to start\nmonitoring your first crop',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.5),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      ),
    );
  }

  /// ------------------------------------------------
  /// NAVIGATION & ACTIONS
  /// ------------------------------------------------
  Future<void> _navigateToClaimDevice(String deviceId) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ClaimDeviceScreen(deviceId: deviceId)),
    );

    // If assign was successful, navigate to main navigation (Dashboard tab)
    if (result == true && mounted) {
      // Replace the current screen with MainNavigation and go to Dashboard
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainNavigation()),
        (route) => false,
      );
    }
  }

  void _navigateToDashboard({
    required String cropId,
    required String deviceId,
    required String cropType,
  }) {
    // Update the selected crop via the service
    final selectedCropService = SelectedCropService();
    selectedCropService.updateSelectedCrop(
      cropId: cropId,
      deviceId: deviceId,
      cropType: cropType,
    );

    // Navigate back to main navigation (Dashboard tab)
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainNavigation()),
      (route) => false,
    );
  }

  Future<void> _showUnclaimDialog({
    required String cropId,
    required String deviceId,
    required String cropType,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => UnclaimDeviceDialog(
        cropId: cropId,
        deviceId: deviceId,
        cropType: cropType,
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Text('$cropType crop has been deleted'),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Logout', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(color: AppColors.textSecondaryDark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondaryDark),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Logout',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _authService.signOut();
      // Pop all routes back to AuthWrapper so it can redirect to LoginScreen
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  /// ------------------------------------------------
  /// HELPER METHODS
  /// ------------------------------------------------
  Color _getCropColor(String cropType) {
    switch (cropType.toLowerCase()) {
      case 'tomato':
        return Colors.red;
      case 'corn':
        return Colors.amber;
      case 'wheat':
        return Colors.orange;
      case 'rice':
        return Colors.brown;
      case 'potato':
        return Colors.brown;
      case 'carrot':
        return Colors.orange;
      case 'lettuce':
        return Colors.green;
      case 'cucumber':
        return Colors.green;
      case 'pepper':
        return Colors.red;
      case 'onion':
        return Colors.purple;
      default:
        return AppColors.primary;
    }
  }

  IconData _getCropIcon(String cropType) {
    switch (cropType.toLowerCase()) {
      case 'tomato':
      case 'pepper':
        return Icons.local_florist;
      case 'corn':
      case 'wheat':
      case 'rice':
        return Icons.grass;
      case 'potato':
      case 'carrot':
      case 'onion':
        return Icons.eco;
      case 'lettuce':
      case 'cucumber':
        return Icons.spa;
      default:
        return Icons.eco;
    }
  }
}
