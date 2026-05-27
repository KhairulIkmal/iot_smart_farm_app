import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../../core/app_localizations.dart';
import '../../../core/theme.dart';
import '../../../services/user_counter_service.dart';
import '../../crop_management/crop_detail_screen.dart';
import 'farm_location_screen.dart';

/// ------------------------------------------------------------
/// MY FARM SCREEN
///
/// Shows:
/// - Farm profile card (name, type, size) with edit sheet
/// - Overview stats (active plots, devices, total yield)
/// - Active Crops list (tappable → CropDetailScreen)
/// - Connected Devices list (real-time online/offline)
/// ------------------------------------------------------------
class FarmDetailsScreen extends StatefulWidget {
  const FarmDetailsScreen({super.key});

  @override
  State<FarmDetailsScreen> createState() => _FarmDetailsScreenState();
}

class _FarmDetailsScreenState extends State<FarmDetailsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;
  String? _customUserId;

  // Farm profile data
  String _farmName = '';
  String _farmSize = '';
  String _farmType = 'Open Field';

  // Location
  String _locationAddress = '';

  // Stats
  double _totalYieldKg = 0;

  static const _farmTypes = [
    'Open Field',
    'Greenhouse',
    'Hydroponics',
    'Mixed',
  ];

  static const _farmTypeIcons = {
    'Open Field': Icons.landscape,
    'Greenhouse': Icons.home_work_outlined,
    'Hydroponics': Icons.water_outlined,
    'Mixed': Icons.grid_view_outlined,
  };

  @override
  void initState() {
    super.initState();
    _loadFarmData();
  }

  Future<void> _loadFarmData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final userDoc = await UserCounterService().getUserByAuthUid(user.uid);
      if (userDoc == null || !userDoc.exists) return;

      _customUserId = userDoc.id;

      final doc = await _firestore
          .collection('users')
          .doc(_customUserId)
          .collection('farm')
          .doc('details')
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        _farmName = data['name'] as String? ?? '';
        _farmSize = (data['size'] as num?)?.toString() ?? '';
        _farmType = data['farm_type'] as String? ?? 'Open Field';
      }

      // Load farm location address
      final locationDoc = await _firestore
          .collection('users')
          .doc(_customUserId)
          .collection('farm')
          .doc('location')
          .get();

      if (locationDoc.exists) {
        _locationAddress = locationDoc.data()?['address'] as String? ?? '';
      }

      // Compute total yield from all crops' harvest_log
      final cropsSnap = await _firestore
          .collection('crops')
          .where('farmer_id', isEqualTo: user.uid)
          .get();

      double total = 0;
      for (final doc in cropsSnap.docs) {
        final harvestRaw = doc.data()['harvest_log'] as List<dynamic>?;
        if (harvestRaw != null) {
          for (final e in harvestRaw) {
            total += ((e as Map)['yield_kg'] as num?)?.toDouble() ?? 0;
          }
        }
      }
      _totalYieldKg = total;
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveFarmDetails({
    required String name,
    required String size,
    required String type,
  }) async {
    if (_customUserId == null) return;

    await _firestore
        .collection('users')
        .doc(_customUserId)
        .collection('farm')
        .doc('details')
        .set({
          'name': name.trim(),
          'size': double.tryParse(size.trim()) ?? 0,
          'farm_type': type,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

    await _firestore.collection('users').doc(_customUserId).update({
      'farm_name': name.trim(),
    });

    setState(() {
      _farmName = name.trim();
      _farmSize = size.trim();
      _farmType = type;
    });
  }

  void _openEditSheet() {
    final nameC = TextEditingController(text: _farmName);
    final sizeC = TextEditingController(text: _farmSize);
    String selectedType = _farmType;
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (ctx, setSheetState) => Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            decoration: BoxDecoration(
              color: ThemeColors.surface(context),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: ThemeColors.border(context),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Edit Farm Info',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: ThemeColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 20),

                // Farm Name
                _sheetTextField(
                  controller: nameC,
                  label: 'Farm Name',
                  icon: Icons.agriculture_outlined,
                ),
                const SizedBox(height: 14),

                // Farm Size
                _sheetTextField(
                  controller: sizeC,
                  label: 'Farm Size (acres)',
                  icon: Icons.landscape_outlined,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 14),

                // Farm Type
                Text(
                  'Farm Type',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: ThemeColors.textSecondary(context).withOpacity(0.5),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _farmTypes.map((type) {
                    final selected = selectedType == type;
                    return GestureDetector(
                      onTap: () => setSheetState(() => selectedType = type),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primary.withOpacity(0.15)
                              : ThemeColors.bg(context),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selected ? AppColors.primary : ThemeColors.border(context),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _farmTypeIcons[type] ?? Icons.eco_outlined,
                              size: 14,
                              color: selected ? AppColors.primary : ThemeColors.textSecondary(context).withOpacity(0.5),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              type,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                                color: selected ? AppColors.primary : ThemeColors.textSecondary(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: saving
                        ? null
                        : () async {
                            setSheetState(() => saving = true);
                            try {
                              await _saveFarmDetails(
                                name: nameC.text,
                                size: sizeC.text,
                                type: selectedType,
                              );
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: const Row(children: [
                                    Icon(Icons.check_circle, color: Colors.white),
                                    SizedBox(width: 10),
                                    Text('Farm info saved'),
                                  ]),
                                  backgroundColor: AppColors.primary,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ));
                              }
                            } finally {
                              if (ctx.mounted) setSheetState(() => saving = false);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation(Colors.white)),
                          )
                        : const Text('Save Changes', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sheetTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: ThemeColors.bg(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ThemeColors.border(context)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: TextStyle(color: ThemeColors.textPrimary(context), fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: ThemeColors.textSecondary(context).withOpacity(0.5)),
          prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final userId = _auth.currentUser?.uid;

    return Scaffold(
      backgroundColor: ThemeColors.bg(context),
      appBar: AppBar(
        backgroundColor: ThemeColors.bg(context),
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: ThemeColors.surface(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ThemeColors.border(context)),
              ),
              child: Icon(Icons.arrow_back, color: ThemeColors.icon(context), size: 22),
            ),
          ),
        ),
        title: Text(
          'My Farm',
          style: TextStyle(color: ThemeColors.textPrimary(context), fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppColors.primary)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Farm Profile Card ──
                  _buildProfileCard(l10n),
                  const SizedBox(height: 20),

                  // ── Location ──
                  _buildSectionTitle('Location'),
                  const SizedBox(height: 12),
                  _buildLocationCard(),
                  const SizedBox(height: 24),

                  // ── Overview Stats ──
                  _buildSectionTitle('Overview'),
                  const SizedBox(height: 12),
                  _buildOverviewStats(userId, l10n),
                  const SizedBox(height: 24),

                  // ── Active Crops ──
                  _buildSectionTitle(l10n.t('Active Crops')),
                  const SizedBox(height: 12),
                  _buildCropsList(userId, l10n),
                  const SizedBox(height: 24),

                  // ── Connected Devices ──
                  _buildSectionTitle(l10n.t('Connected Devices')),
                  const SizedBox(height: 12),
                  _buildDevicesList(userId, l10n),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  /// ── Farm Profile Card ──
  Widget _buildProfileCard(AppLocalizations l10n) {
    final typeIcon = _farmTypeIcons[_farmType] ?? Icons.eco_outlined;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ThemeColors.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ThemeColors.border(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Farm icon
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(typeIcon, color: AppColors.primary, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _farmName.isNotEmpty ? _farmName : 'My Farm',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: ThemeColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _infoPill(Icons.landscape_outlined, _farmSize.isNotEmpty ? '${_farmSize} acres' : 'Size not set'),
                    const SizedBox(width: 8),
                    _infoPill(typeIcon, _farmType),
                  ],
                ),
              ],
            ),
          ),
          // Edit button
          GestureDetector(
            onTap: _openEditSheet,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ThemeColors.bg(context),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: ThemeColors.textSecondary(context).withOpacity(0.5)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: ThemeColors.textSecondary(context).withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  /// ── Overview Stats ──
  Widget _buildOverviewStats(String? userId, AppLocalizations l10n) {
    if (userId == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('crops')
          .where('farmer_id', isEqualTo: userId)
          .where('status', isEqualTo: 'active')
          .snapshots(),
      builder: (context, snapshot) {
        final activePlots = snapshot.data?.docs.length ?? 0;
        final deviceCount = snapshot.data?.docs
                .map((d) => (d.data() as Map<String, dynamic>)['device_id'])
                .where((id) => id != null)
                .toSet()
                .length ??
            0;

        return Row(
          children: [
            Expanded(child: _statCard(
              icon: Icons.eco_outlined,
              color: AppColors.primary,
              value: '$activePlots',
              label: 'Active\nPlots',
            )),
            const SizedBox(width: 10),
            Expanded(child: _statCard(
              icon: Icons.developer_board_outlined,
              color: AppColors.info,
              value: '$deviceCount',
              label: 'Connected\nDevices',
            )),
            const SizedBox(width: 10),
            Expanded(child: _statCard(
              icon: Icons.scale_outlined,
              color: AppColors.warning,
              value: '${_totalYieldKg.toStringAsFixed(1)} kg',
              label: 'Total\nYield',
            )),
          ],
        );
      },
    );
  }

  Widget _statCard({
    required IconData icon,
    required Color color,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: ThemeColors.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ThemeColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: ThemeColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: ThemeColors.textSecondary(context).withOpacity(0.5),
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  /// ── Location Card ──
  Widget _buildLocationCard() {
    final hasLocation = _locationAddress.isNotEmpty;
    return InkWell(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const FarmLocationScreen()),
        );
        // Reload location address after returning
        if (_customUserId != null && mounted) {
          final doc = await _firestore
              .collection('users')
              .doc(_customUserId)
              .collection('farm')
              .doc('location')
              .get();
          if (mounted) {
            setState(() {
              _locationAddress = doc.data()?['address'] as String? ?? '';
            });
          }
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ThemeColors.surface(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ThemeColors.border(context)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.location_on_outlined, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasLocation ? _locationAddress.split(',').first : 'Location not set',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: hasLocation
                          ? ThemeColors.textPrimary(context)
                          : ThemeColors.textSecondary(context).withOpacity(0.5),
                    ),
                  ),
                  if (hasLocation && _locationAddress.contains(','))
                    Text(
                      _locationAddress.substring(_locationAddress.indexOf(',') + 2),
                      style: TextStyle(
                        fontSize: 12,
                        color: ThemeColors.textSecondary(context).withOpacity(0.5),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  else
                    Text(
                      'Tap to set farm location for weather',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primary.withOpacity(0.7),
                      ),
                    ),
                ],
              ),
            ),
            Text(
              hasLocation ? 'Change' : 'Set',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: ThemeColors.icon(context).withOpacity(0.3), size: 20),
          ],
        ),
      ),
    );
  }

  /// ── Section Title ──
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: ThemeColors.textSecondary(context).withOpacity(0.5),
          letterSpacing: 1,
        ),
      ),
    );
  }

  /// ── Active Crops List ──
  Widget _buildCropsList(String? userId, AppLocalizations l10n) {
    if (userId == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('crops')
          .where('farmer_id', isEqualTo: userId)
          .where('status', isEqualTo: 'active')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _emptyCard(Icons.eco_outlined, l10n.t('No active crops'));
        }

        final docs = snapshot.data!.docs;
        return Container(
          decoration: BoxDecoration(
            color: ThemeColors.surface(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ThemeColors.border(context)),
          ),
          child: Column(
            children: docs.asMap().entries.map((entry) {
              final index = entry.key;
              final doc = entry.value;
              final data = doc.data() as Map<String, dynamic>;
              final cropType = data['crop_type'] as String? ?? 'Unknown';
              final fieldName = data['field_name'] as String? ?? '';
              final deviceId = data['device_id'] as String? ?? 'N/A';
              final growthStage = data['growth_stage'] as String?;
              final isLast = index == docs.length - 1;

              return Column(
                children: [
                  InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CropDetailScreen(
                          cropId: doc.id,
                          cropType: cropType,
                          deviceId: deviceId,
                          fieldName: fieldName,
                          notes: data['notes'] as String? ?? '',
                          imageUrl: data['image_url'] as String?,
                          plantingDate: data['createdAt'] as Timestamp?,
                        ),
                      ),
                    ),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.eco, color: AppColors.primary, size: 20),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      cropType,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: ThemeColors.textPrimary(context),
                                      ),
                                    ),
                                    if (growthStage != null) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          _stageLabel(growthStage),
                                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primary),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  fieldName.isNotEmpty ? fieldName : deviceId,
                                  style: TextStyle(fontSize: 13, color: ThemeColors.textSecondary(context).withOpacity(0.5)),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, color: ThemeColors.icon(context).withOpacity(0.3), size: 20),
                        ],
                      ),
                    ),
                  ),
                  if (!isLast)
                    Divider(height: 1, color: ThemeColors.border(context), indent: 60),
                ],
              );
            }).toList(),
          ),
        );
      },
    );
  }

  /// ── Connected Devices List ──
  Widget _buildDevicesList(String? userId, AppLocalizations l10n) {
    if (userId == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('crops')
          .where('farmer_id', isEqualTo: userId)
          .where('status', isEqualTo: 'active')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _emptyCard(Icons.devices_outlined, l10n.t('No devices connected'));
        }

        final deviceIds = snapshot.data!.docs
            .map((doc) => (doc.data() as Map<String, dynamic>)['device_id'] as String?)
            .where((id) => id != null)
            .cast<String>()
            .toSet()
            .toList();

        return Container(
          decoration: BoxDecoration(
            color: ThemeColors.surface(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ThemeColors.border(context)),
          ),
          child: Column(
            children: deviceIds.asMap().entries.map((entry) {
              final index = entry.key;
              final deviceId = entry.value;
              final isLast = index == deviceIds.length - 1;
              return Column(
                children: [
                  _DeviceStatusRow(deviceId: deviceId, l10n: l10n),
                  if (!isLast)
                    Divider(height: 1, color: ThemeColors.border(context), indent: 60),
                ],
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _emptyCard(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ThemeColors.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ThemeColors.border(context)),
      ),
      child: Row(
        children: [
          Icon(icon, color: ThemeColors.textSecondary(context).withOpacity(0.3), size: 28),
          const SizedBox(width: 14),
          Text(
            text,
            style: TextStyle(color: ThemeColors.textSecondary(context).withOpacity(0.5), fontSize: 15),
          ),
        ],
      ),
    );
  }

  String _stageLabel(String stage) {
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

/// ── Real-time device status row ──
class _DeviceStatusRow extends StatefulWidget {
  final String deviceId;
  final AppLocalizations l10n;

  const _DeviceStatusRow({required this.deviceId, required this.l10n});

  @override
  State<_DeviceStatusRow> createState() => _DeviceStatusRowState();
}

class _DeviceStatusRowState extends State<_DeviceStatusRow> {
  bool _isOnline = false;
  StreamSubscription<DatabaseEvent>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = FirebaseDatabase.instance
        .ref('sensors/${widget.deviceId}/live/lastSeen')
        .onValue
        .listen((event) {
      if (!mounted) return;
      final val = event.snapshot.value;
      bool online = false;
      if (val != null) {
        final ms = (val as num).toInt();
        final diff = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ms));
        online = diff.inSeconds < 10;
      }
      setState(() => _isOnline = online);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.info.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.developer_board, color: AppColors.info, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.deviceId,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: ThemeColors.textPrimary(context),
                  ),
                ),
                Text(
                  widget.l10n.t('ESP32 Controller'),
                  style: TextStyle(fontSize: 13, color: ThemeColors.textSecondary(context).withOpacity(0.5)),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _isOnline ? AppColors.primary : AppColors.error,
                  shape: BoxShape.circle,
                  boxShadow: _isOnline
                      ? [BoxShadow(color: AppColors.primary.withOpacity(0.5), blurRadius: 6)]
                      : null,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _isOnline ? 'Online' : 'Offline',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _isOnline ? AppColors.primary : AppColors.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
