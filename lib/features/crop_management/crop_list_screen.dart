import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/app_localizations.dart';
import '../../core/theme.dart';
import '../../auth/auth_service.dart';
import '../navigation/main_navigation.dart';
import 'claim_device_screen.dart';
import 'crop_detail_screen.dart';

/// ------------------------------------------------------------
/// CROP LIST SCREEN (CROP MANAGEMENT)
/// Shows:
/// - Stats (Active Plots, Connected Devices)
/// - Connect New Device card (enter AGR-XXXX-XXXX code)
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
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();

  // Cache: Firestore doc ID → AGR-XXXX-XXXX code
  final Map<String, String> _deviceCodeCache = {};

  Future<void> _prefetchDeviceCodes(List<String> deviceIds) async {
    final missing = deviceIds.where((id) => id.isNotEmpty && !_deviceCodeCache.containsKey(id)).toList();
    if (missing.isEmpty) return;
    for (final id in missing) {
      try {
        final doc = await _firestore.collection('devices').doc(id).get();
        final code = doc.data()?['unique_code'] as String?;
        if (code != null && mounted) {
          setState(() => _deviceCodeCache[id] = code);
        }
      } catch (_) {}
    }
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
              _buildHeader(l10n),
              const SizedBox(height: 20),
              _buildStatsCards(l10n),
              const SizedBox(height: 24),
              _buildConnectDeviceSection(l10n),
              const SizedBox(height: 24),
              _buildMyCropsSection(l10n),
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
  Widget _buildHeader(AppLocalizations l10n) {
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
                    color: ThemeColors.surface(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ThemeColors.border(context)),
                  ),
                  child: const Icon(Icons.arrow_back, color: AppColors.primary, size: 24),
                ),
              ),
            if (widget.showBackButton) const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.t('Crop Management'),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: ThemeColors.textPrimary(context),
                  ),
                ),
                Text(
                  'Monitor and manage your farm plots',
                  style: TextStyle(
                    fontSize: 13,
                    color: ThemeColors.textSecondary(context).withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ],
        ),
        if (!widget.showBackButton)
          GestureDetector(
            onTap: _handleLogout,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: ThemeColors.surface(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ThemeColors.border(context)),
              ),
              child: const Icon(Icons.logout, color: AppColors.error, size: 24),
            ),
          ),
      ],
    );
  }

  /// ------------------------------------------------
  /// STATS CARDS — Active Plots & Connected Devices
  /// Both derived from the farmer's active crops stream.
  /// ------------------------------------------------
  Widget _buildStatsCards(AppLocalizations l10n) {
    final user = _auth.currentUser;

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('crops')
          .where('farmer_id', isEqualTo: user?.uid)
          .where('status', isEqualTo: 'active')
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        final activePlots = docs.length;
        final deviceCount = docs
            .map((d) => (d.data() as Map<String, dynamic>)['device_id'] as String?)
            .where((id) => id != null && id.isNotEmpty)
            .toSet()
            .length;

        return Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.eco_outlined,
                iconColor: AppColors.primary,
                label: l10n.t('ACTIVE'),
                value: '$activePlots ${l10n.t('Plots')}',
                backgroundColor: AppColors.primary.withOpacity(0.12),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                icon: Icons.developer_board_outlined,
                iconColor: AppColors.info,
                label: l10n.t('DEVICES'),
                value: '$deviceCount ${l10n.t('Connected')}',
                backgroundColor: ThemeColors.surface(context),
              ),
            ),
          ],
        );
      },
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
        border: Border.all(color: ThemeColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: ThemeColors.textSecondary(context).withOpacity(0.6),
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: ThemeColors.textPrimary(context),
            ),
          ),
        ],
      ),
    );
  }

  /// ------------------------------------------------
  /// CONNECT NEW DEVICE SECTION
  /// Farmer enters AGR-XXXX-XXXX code purchased from admin.
  /// ------------------------------------------------
  Widget _buildConnectDeviceSection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Device Connection',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: ThemeColors.textPrimary(context),
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => _showConnectDeviceDialog(l10n),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: ThemeColors.surface(context),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary.withOpacity(0.35)),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.add_link, color: AppColors.primary, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Connect New Device',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: ThemeColors.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Enter the device code from your IoT device purchase',
                        style: TextStyle(
                          fontSize: 13,
                          color: ThemeColors.textSecondary(context).withOpacity(0.5),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.arrow_forward, color: Colors.white, size: 16),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showConnectDeviceDialog(AppLocalizations l10n) async {
    final codeController = TextEditingController();
    String? errorMsg;
    bool loading = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: ThemeColors.surface(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          actionsPadding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.memory, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Connect Device',
                style: TextStyle(
                  color: ThemeColors.textPrimary(context),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter the unique code provided with your IoT device purchase (e.g. AGR-1234-ABCD).',
                style: TextStyle(
                  fontSize: 13,
                  color: ThemeColors.textSecondary(context).withOpacity(0.6),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: ThemeColors.bg(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: errorMsg != null ? AppColors.error : ThemeColors.border(context),
                    width: errorMsg != null ? 1.5 : 1,
                  ),
                ),
                child: TextField(
                  controller: codeController,
                  textCapitalization: TextCapitalization.characters,
                  style: TextStyle(
                    color: ThemeColors.textPrimary(context),
                    fontSize: 18,
                    letterSpacing: 2.5,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: 'AGR-XXXX-XXXX',
                    hintStyle: TextStyle(
                      color: ThemeColors.textSecondary(context).withOpacity(0.25),
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w400,
                      fontSize: 16,
                    ),
                    prefixIcon: const Icon(Icons.qr_code_rounded, color: AppColors.primary, size: 20),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
              if (errorMsg != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.error_outline, size: 14, color: AppColors.error),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        errorMsg!,
                        style: const TextStyle(fontSize: 12, color: AppColors.error, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 4),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: TextStyle(color: ThemeColors.textSecondary(context).withOpacity(0.5)),
              ),
            ),
            ElevatedButton(
              onPressed: loading
                  ? null
                  : () async {
                      final code = codeController.text.trim().toUpperCase();
                      if (code.isEmpty) {
                        setDialogState(() => errorMsg = 'Please enter your device code');
                        return;
                      }
                      setDialogState(() {
                        loading = true;
                        errorMsg = null;
                      });
                      try {
                        final snap = await _firestore
                            .collection('devices')
                            .where('unique_code', isEqualTo: code)
                            .where('status', isEqualTo: 'available')
                            .limit(1)
                            .get();

                        if (snap.docs.isEmpty) {
                          setDialogState(() {
                            loading = false;
                            errorMsg = 'Device not found or already claimed';
                          });
                          return;
                        }

                        final deviceDocId = snap.docs.first.id;
                        if (ctx.mounted) Navigator.pop(ctx);
                        await _navigateToClaimDevice(deviceDocId);
                      } catch (_) {
                        setDialogState(() {
                          loading = false;
                          errorMsg = 'Something went wrong. Please try again.';
                        });
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Connect', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
    // Dispose after the dialog's widget tree has fully unmounted.
    // Calling dispose() immediately causes '_dependents.isEmpty' assertion
    // because the TextField's animation is still tearing down.
    WidgetsBinding.instance.addPostFrameCallback((_) => codeController.dispose());
  }

  /// ------------------------------------------------
  /// MY CROPS SECTION
  /// ------------------------------------------------
  Widget _buildMyCropsSection(AppLocalizations l10n) {
    final user = _auth.currentUser;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.t('My Crops'),
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: ThemeColors.textPrimary(context),
          ),
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
              return _buildEmptyCropsCard(l10n);
            }

            final crops = snapshot.data!.docs;

            // Kick off unique_code fetches for any unseen device IDs
            final allDeviceIds = crops
                .map((c) => (c.data() as Map<String, dynamic>)['device_id'] as String? ?? '')
                .toList();
            _prefetchDeviceCodes(allDeviceIds);

            return Column(
              children: crops.map((crop) {
                final cropId = crop.id;
                final data = crop.data() as Map<String, dynamic>;
                final cropType = data['crop_type'] as String? ?? 'Unknown';
                final deviceId = data['device_id'] as String? ?? '';
                final plantingDate = data['planting_date'] as Timestamp?;
                final fieldName = data['field_name'] as String? ?? 'Field A';
                final notes = data['notes'] as String? ?? '';
                final imageUrl = data['image_url'] as String?;
                final growthStage = data['growth_stage'] as String?;
                final deviceCode = _deviceCodeCache[deviceId] ?? deviceId;

                return _buildCropCard(
                  cropId: cropId,
                  cropType: cropType,
                  deviceId: deviceId,
                  deviceCode: deviceCode,
                  plantingDate: plantingDate,
                  fieldName: fieldName,
                  notes: notes,
                  imageUrl: imageUrl,
                  growthStage: growthStage,
                  l10n: l10n,
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
    required String deviceCode,
    Timestamp? plantingDate,
    required String fieldName,
    required String notes,
    String? imageUrl,
    String? growthStage,
    required AppLocalizations l10n,
  }) {
    return GestureDetector(
      onTap: () => _openCropDetail(
        cropId: cropId,
        cropType: cropType,
        deviceId: deviceId,
        fieldName: fieldName,
        notes: notes,
        imageUrl: imageUrl,
        plantingDate: plantingDate,
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: ThemeColors.border(context)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Background Image / Placeholder
              SizedBox(
                height: 180,
                width: double.infinity,
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildCropCardPlaceholder(cropType),
                      )
                    : _buildCropCardPlaceholder(cropType),
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
                        ThemeColors.bg(context).withOpacity(0.92),
                        ThemeColors.bg(context),
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status row
                      Row(
                        children: [
                          _monitoringBadge(l10n),
                          if (growthStage != null) ...[
                            const SizedBox(width: 8),
                            _stageBadge(growthStage),
                          ],
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Crop Name & Arrow
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$cropType — $fieldName',
                                  style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.bold,
                                    color: ThemeColors.textPrimary(context),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.memory, size: 13, color: AppColors.textSecondaryDark),
                                    const SizedBox(width: 4),
                                    Text(
                                      deviceCode,
                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryDark),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.arrow_forward_ios, color: ThemeColors.icon(context), size: 15),
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

  Widget _monitoringBadge(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            l10n.t('MONITORING'),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stageBadge(String stage) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _getStageLabel(stage),
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white),
      ),
    );
  }

  Widget _buildCropCardPlaceholder(String cropType) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _getCropColor(cropType).withOpacity(0.35),
            ThemeColors.bg(context),
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
    );
  }

  Widget _buildEmptyCropsCard(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: BoxDecoration(
        color: ThemeColors.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ThemeColors.border(context)),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(Icons.eco_outlined, size: 32, color: AppColors.primary.withOpacity(0.5)),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.t('No Crops Yet'),
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: ThemeColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Connect an IoT device above using\nyour device code to get started',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: ThemeColors.textSecondary(context).withOpacity(0.5),
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
        color: ThemeColors.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ThemeColors.border(context)),
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

    if (result == true && mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainNavigation()),
        (route) => false,
      );
    }
  }

  Future<void> _openCropDetail({
    required String cropId,
    required String cropType,
    required String deviceId,
    required String fieldName,
    required String notes,
    String? imageUrl,
    Timestamp? plantingDate,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CropDetailScreen(
          cropId: cropId,
          cropType: cropType,
          deviceId: deviceId,
          fieldName: fieldName,
          notes: notes,
          imageUrl: imageUrl,
          plantingDate: plantingDate,
        ),
      ),
    );
  }

  Future<void> _handleLogout() async {
    final l10n = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ThemeColors.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Logout', style: TextStyle(color: ThemeColors.textPrimary(context))),
        content: Text(
          l10n.t('Are you sure you want to logout?'),
          style: const TextStyle(color: AppColors.textSecondaryDark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.t('Cancel'), style: const TextStyle(color: AppColors.textSecondaryDark)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _authService.signOut();
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
      case 'pepper':
        return Colors.red;
      case 'corn':
      case 'wheat':
        return Colors.amber;
      case 'rice':
      case 'potato':
        return Colors.brown;
      case 'carrot':
        return Colors.orange;
      case 'lettuce':
      case 'cucumber':
        return Colors.green;
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

  String _getStageLabel(String stage) {
    switch (stage) {
      case 'seedling': return '🌱 Seedling';
      case 'vegetative': return '🌿 Vegetative';
      case 'flowering': return '🌸 Flowering';
      case 'fruiting': return '🍅 Fruiting';
      case 'ready': return '✅ Ready';
      default: return stage;
    }
  }
}
