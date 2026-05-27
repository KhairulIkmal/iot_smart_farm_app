import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/app_localizations.dart';
import '../../core/theme.dart';
import '../../services/crop_counter_service.dart';

/// ------------------------------------------------------------
/// CLAIM DEVICE SCREEN
///
/// PURPOSE:
/// Binds ONE ESP32 device to ONE crop for ONE farmer.
/// Ensures system is in valid state before entering dashboard.
///
/// RECEIVES:
/// - deviceId (required)
/// - deviceName (optional)
///
/// FIRESTORE OPERATIONS:
/// 1. Check for existing active crop (single-active-crop rule)
/// 2. Create new crop document
/// 3. Update device status to "assigned"
///
/// NAVIGATION:
/// - After success: Navigator.pop()
/// - PostLoginRouter will re-evaluate and route to dashboard
///
/// DOES NOT:
/// - Read Realtime Database
/// - Read sensor values
/// - Call OpenWeather API
/// - Navigate directly to MainNavigation
/// ------------------------------------------------------------
class ClaimDeviceScreen extends StatefulWidget {
  final String deviceId;
  final String? deviceName;

  const ClaimDeviceScreen({super.key, required this.deviceId, this.deviceName});

  @override
  State<ClaimDeviceScreen> createState() => _ClaimDeviceScreenState();
}

class _ClaimDeviceScreenState extends State<ClaimDeviceScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CropCounterService _cropCounterService = CropCounterService();

  final _formKey = GlobalKey<FormState>();
  final _fieldNameController = TextEditingController();
  final _notesController = TextEditingController();

  String? _selectedCropType;
  bool _isLoading = false;
  bool _isCheckingDevice = true;
  String? _deviceStatus;
  Timestamp? _deviceLastSeen;

  // Available crop types
  final List<String> _cropTypes = [
    'Tomato',
    'Chili',
    'Lettuce',
    'Cabbage',
    'Cucumber',
    'Carrot',
    'Potato',
    'Corn',
    'Rice',
    'Wheat',
    'Onion',
    'Pepper',
    'Spinach',
    'Broccoli',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _checkDeviceStatus();
  }

  @override
  void dispose() {
    _fieldNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// Check device status from Firestore
  Future<void> _checkDeviceStatus() async {
    try {
      final deviceDoc = await _firestore
          .collection('devices')
          .doc(widget.deviceId)
          .get();

      if (deviceDoc.exists) {
        final data = deviceDoc.data()!;
        setState(() {
          _deviceStatus = data['status'] ?? 'unassigned';
          _deviceLastSeen = data['lastSeen'] as Timestamp?;
        });
      } else {
        setState(() {
          _deviceStatus = 'unassigned';
        });
      }
    } catch (e) {
      debugPrint('Error checking device: $e');
      setState(() {
        _deviceStatus = 'unknown';
      });
    } finally {
      setState(() {
        _isCheckingDevice = false;
      });
    }
  }

  /// Main claim device function
  Future<void> _claimDevice() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCropType == null) {
      _showErrorSnackBar('Please select a crop type');
      return;
    }

    final user = _auth.currentUser;
    if (user == null) {
      _showErrorSnackBar('User not authenticated');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // STEP 1: Check if device is already assigned to another farmer
      final deviceDoc = await _firestore
          .collection('devices')
          .doc(widget.deviceId)
          .get();

      if (deviceDoc.exists) {
        final deviceData = deviceDoc.data()!;
        final assignedTo = deviceData['assigned_to'];

        if (deviceData['status'] == 'assigned' &&
            assignedTo != null &&
            assignedTo != user.uid) {
          _showErrorSnackBar(
            'This device has already been assigned to another farm.',
          );
          setState(() => _isLoading = false);
          return;
        }
      }

      // STEP 2: Generate next crop ID
      final cropId = await _cropCounterService.getNextCropId();

      // STEP 3: Perform atomic write (transaction)
      await _firestore.runTransaction((transaction) async {
        // Create new crop document with sequential ID
        final cropRef = _firestore.collection('crops').doc(cropId);
        transaction.set(cropRef, {
          'farmer_id': user.uid,
          'device_id': widget.deviceId,
          'crop_type': _selectedCropType,
          'field_name': _fieldNameController.text.trim().isNotEmpty
              ? _fieldNameController.text.trim()
              : 'Field A',
          'notes': _notesController.text.trim(),
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Update device status
        final deviceRef = _firestore.collection('devices').doc(widget.deviceId);
        transaction.set(deviceRef, {
          'status': 'assigned',
          'assigned_to': user.uid,
          'assigned_crop_id': cropId,
          'assignedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });

      // SUCCESS - Show message and pop
      if (mounted) {
        _showSuccessSnackBar('Device assigned successfully!');

        // Navigate back - PostLoginRouter will re-evaluate and route to dashboard
        Navigator.pop(context);
      }
    } on FirebaseException catch (e) {
      _showErrorSnackBar('Firebase error: ${e.message}');
    } catch (e) {
      _showErrorSnackBar('Error claiming device: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
          l10n.t('Assign Device'),
          style: TextStyle(color: ThemeColors.textPrimary(context), fontWeight: FontWeight.bold),
        ),
      ),
      body: _isCheckingDevice
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
                    // Device Information Card (READ-ONLY)
                    _buildDeviceInfoCard(l10n),
                    const SizedBox(height: 24),

                    // Crop Selection (REQUIRED)
                    _buildSectionTitle('Crop Type'),
                    const SizedBox(height: 4),
                    Text(
                      l10n.t('Select the crop you will grow with this device'),
                      style: TextStyle(
                        fontSize: 13,
                        color: ThemeColors.textSecondary(context).withOpacity(0.5),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildCropSelector(),
                    const SizedBox(height: 24),

                    // Optional Metadata
                    _buildSectionTitle(l10n.t('Field Details (Optional)')),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _fieldNameController,
                      label: 'Field Name',
                      hint: l10n.t('e.g., Greenhouse A, Field 1'),
                      icon: Icons.landscape_outlined,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _notesController,
                      label: 'Notes',
                      hint: l10n.t('Optional notes about this crop'),
                      icon: Icons.notes_outlined,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 32),

                    // Info Card
                    _buildInfoCard(l10n),
                    const SizedBox(height: 24),

                    // Claim Button
                    _buildClaimButton(l10n),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  /// ------------------------------------------------
  /// DEVICE INFORMATION CARD (READ-ONLY)
  /// ------------------------------------------------
  Widget _buildDeviceInfoCard(AppLocalizations l10n) {
    final isAssigned = _deviceStatus == 'assigned';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ThemeColors.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isAssigned
              ? AppColors.warning.withOpacity(0.5)
              : AppColors.primary.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Device Icon
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.developer_board,
                  color: AppColors.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              // Device Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.deviceName ?? l10n.t('ESP32 Controller'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: ThemeColors.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.deviceId,
                      style: TextStyle(
                        fontSize: 14,
                        color: ThemeColors.textSecondary(context).withOpacity(0.5),
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Divider
          Divider(color: ThemeColors.border(context), height: 1),
          const SizedBox(height: 16),
          // Status Row
          Row(
            children: [
              Expanded(
                child: _buildInfoRow(
                  'Status',
                  _deviceStatus ?? 'Unknown',
                  _deviceStatus == 'unassigned'
                      ? AppColors.primary
                      : AppColors.warning,
                ),
              ),
              Container(width: 1, height: 30, color: ThemeColors.border(context)),
              Expanded(child: _buildInfoRow('Type', 'ESP32', ThemeColors.textPrimary(context))),
            ],
          ),
          // Warning if already assigned
          if (isAssigned) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber,
                    color: AppColors.warning,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.t('This device is already assigned. Assigning will reassign it.'),
                      style: TextStyle(fontSize: 13, color: AppColors.warning),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: ThemeColors.textSecondary(context).withOpacity(0.5)),
        ),
        const SizedBox(height: 4),
        Text(
          value.toUpperCase(),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: valueColor,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  /// ------------------------------------------------
  /// CROP SELECTOR
  /// ------------------------------------------------
  Widget _buildCropSelector() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: _selectedCropType,
        dropdownColor: ThemeColors.surface(context),
        decoration: InputDecoration(
          filled: false,
          prefixIcon: Icon(
            Icons.eco_outlined,
            color: _selectedCropType != null
                ? AppColors.primary
                : ThemeColors.textSecondary(context).withOpacity(0.5),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        hint: Text(
          'Select crop type',
          style: TextStyle(color: ThemeColors.textSecondary(context).withOpacity(0.5)),
        ),
        style: TextStyle(color: ThemeColors.textPrimary(context), fontSize: 16),
        icon: Icon(
          Icons.keyboard_arrow_down,
          color: ThemeColors.textSecondary(context).withOpacity(0.5),
        ),
        items: _cropTypes.map((crop) {
          return DropdownMenuItem<String>(value: crop, child: Text(crop));
        }).toList(),
        onChanged: (value) {
          setState(() {
            _selectedCropType = value;
          });
        },
        validator: (value) {
          if (value == null) {
            return 'Please select a crop type';
          }
          return null;
        },
      ),
    );
  }

  /// ------------------------------------------------
  /// TEXT FIELD
  /// ------------------------------------------------
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        style: TextStyle(color: ThemeColors.textPrimary(context), fontSize: 16),
        decoration: InputDecoration(
          filled: false,
          labelText: label,
          hintText: hint,
          labelStyle: TextStyle(color: ThemeColors.textSecondary(context).withOpacity(0.5)),
          hintStyle: TextStyle(color: ThemeColors.textSecondary(context).withOpacity(0.3)),
          prefixIcon: Icon(icon, color: ThemeColors.textSecondary(context).withOpacity(0.5)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  /// ------------------------------------------------
  /// INFO CARD
  /// ------------------------------------------------
  Widget _buildInfoCard(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.info.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.info.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppColors.info, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.t('What happens after assigning?'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.info,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '• ${l10n.t('Device will be linked to your account')}\n'
                  '• ${l10n.t('You can assign multiple devices for different crops')}\n'
                  '• ${l10n.t('AI will provide crop-specific recommendations')}\n'
                  '• ${l10n.t('Switch between crops in the dashboard')}',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.info.withOpacity(0.8),
                    height: 1.5,
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
  /// CLAIM BUTTON
  /// ------------------------------------------------
  Widget _buildClaimButton(AppLocalizations l10n) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _claimDevice,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.link, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    l10n.t('Assign Device'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
      ),
    );
  }

  /// ------------------------------------------------
  /// SECTION TITLE
  /// ------------------------------------------------
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: ThemeColors.textPrimary(context),
      ),
    );
  }

  /// ------------------------------------------------
  /// SNACKBARS
  /// ------------------------------------------------
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
