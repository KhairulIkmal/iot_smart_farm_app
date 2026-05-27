import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../../core/app_localizations.dart';
import '../../../core/theme.dart';
import '../../../services/user_counter_service.dart';
import '../../crop_management/crop_detail_screen.dart';

/// ------------------------------------------------------------
/// FARM DETAILS SCREEN
///
/// Shows:
/// - Farm Name
/// - Farm Size
/// - Crop Types
/// - Device List
/// ------------------------------------------------------------
class FarmDetailsScreen extends StatefulWidget {
  const FarmDetailsScreen({super.key});

  @override
  State<FarmDetailsScreen> createState() => _FarmDetailsScreenState();
}

class _FarmDetailsScreenState extends State<FarmDetailsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final _formKey = GlobalKey<FormState>();
  final _farmNameController = TextEditingController();
  final _farmSizeController = TextEditingController();

  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadFarmData();
  }

  @override
  void dispose() {
    _farmNameController.dispose();
    _farmSizeController.dispose();
    super.dispose();
  }

  Future<void> _loadFarmData() async {
    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Get the custom user document by Auth UID
      final userCounterService = UserCounterService();
      final userDoc = await userCounterService.getUserByAuthUid(user.uid);

      if (userDoc == null || !userDoc.exists) return;

      final customUserId = userDoc.id;

      final doc = await _firestore
          .collection('users')
          .doc(customUserId)
          .collection('farm')
          .doc('details')
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        _farmNameController.text = data['name'] ?? '';
        _farmSizeController.text = data['size']?.toString() ?? '';
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveFarmDetails() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Get the custom user document by Auth UID
      final userCounterService = UserCounterService();
      final userDoc = await userCounterService.getUserByAuthUid(user.uid);

      if (userDoc == null || !userDoc.exists) return;

      final customUserId = userDoc.id;

      await _firestore
          .collection('users')
          .doc(customUserId)
          .collection('farm')
          .doc('details')
          .set({
            'name': _farmNameController.text.trim(),
            'size': double.tryParse(_farmSizeController.text.trim()) ?? 0,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      // Also update farm_name in user document
      await _firestore.collection('users').doc(customUserId).update({
        'farm_name': _farmNameController.text.trim(),
      });

      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text(l10n.t('Farm details saved')),
              ],
            ),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = _auth.currentUser;

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
              child: Icon(
                Icons.arrow_back,
                color: ThemeColors.icon(context),
                size: 24,
              ),
            ),
          ),
        ),
        title: Text(
          l10n.t('Farm Details'),
          style: TextStyle(color: ThemeColors.textPrimary(context), fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Farm Info Section
                    _buildSectionTitle(l10n.t('Farm Information')),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _farmNameController,
                      label: l10n.t('Farm Name'),
                      icon: Icons.agriculture,
                      validator: (v) =>
                          v?.isEmpty ?? true ? 'Farm name is required' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _farmSizeController,
                      label: l10n.t('Farm Size (acres)'),
                      icon: Icons.landscape,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 32),

                    // Active Crops Section
                    _buildSectionTitle(l10n.t('Active Crops')),
                    const SizedBox(height: 16),
                    _buildCropsList(user?.uid, l10n),
                    const SizedBox(height: 32),

                    // Connected Devices Section
                    _buildSectionTitle(l10n.t('Connected Devices')),
                    const SizedBox(height: 16),
                    _buildDevicesList(user?.uid, l10n),
                    const SizedBox(height: 32),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveFarmDetails,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Text(
                                l10n.t('Save Changes'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: ThemeColors.textSecondary(context).withOpacity(0.5),
        letterSpacing: 1,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: ThemeColors.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ThemeColors.border(context)),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        style: TextStyle(color: ThemeColors.textPrimary(context), fontSize: 16),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: ThemeColors.textSecondary(context).withOpacity(0.5)),
          prefixIcon: Icon(icon, color: AppColors.primary),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

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
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: ThemeColors.surface(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ThemeColors.border(context)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.eco_outlined,
                  color: ThemeColors.textSecondary(context).withOpacity(0.3),
                  size: 32,
                ),
                const SizedBox(width: 16),
                Text(
                  l10n.t('No active crops'),
                  style: TextStyle(
                    color: ThemeColors.textSecondary(context).withOpacity(0.5),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
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
                            child: const Icon(Icons.eco, color: AppColors.primary, size: 22),
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
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: ThemeColors.textSecondary(context).withOpacity(0.5),
                                  ),
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
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: ThemeColors.surface(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ThemeColors.border(context)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.devices_outlined,
                  color: ThemeColors.textSecondary(context).withOpacity(0.3),
                  size: 32,
                ),
                const SizedBox(width: 16),
                Text(
                  l10n.t('No devices connected'),
                  style: TextStyle(
                    color: ThemeColors.textSecondary(context).withOpacity(0.5),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }

        // Unique device IDs from active crops only
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

/// Stateful row that shows real online/offline status from RTDB
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
            child: const Icon(Icons.developer_board, color: AppColors.info, size: 22),
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
                  style: TextStyle(
                    fontSize: 13,
                    color: ThemeColors.textSecondary(context).withOpacity(0.5),
                  ),
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
