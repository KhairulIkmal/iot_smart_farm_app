import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/theme.dart';

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
      // STEP 1: Check for existing active crop (single-active-crop rule)
      final existingCrops = await _firestore
          .collection('crops')
          .where('farmer_id', isEqualTo: user.uid)
          .where('status', isEqualTo: 'active')
          .get();

      if (existingCrops.docs.isNotEmpty) {
        // Show confirmation dialog
        final shouldContinue = await _showDeactivateDialog();
        if (!shouldContinue) {
          setState(() => _isLoading = false);
          return;
        }
      }

      // STEP 2: Check if device is already assigned to another farmer
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

      // STEP 3: Perform atomic write (transaction)
      await _firestore.runTransaction((transaction) async {
        // Deactivate existing active crops
        for (final doc in existingCrops.docs) {
          transaction.update(doc.reference, {
            'status': 'inactive',
            'deactivatedAt': FieldValue.serverTimestamp(),
          });
        }

        // Create new crop document
        final cropRef = _firestore.collection('crops').doc();
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
          'assigned_crop_id': cropRef.id,
          'assignedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });

      // SUCCESS - Show message and pop
      if (mounted) {
        _showSuccessSnackBar('Device claimed successfully!');

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

  /// Show dialog when user already has an active crop
  Future<bool> _showDeactivateDialog() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => Dialog(
            backgroundColor: AppColors.surfaceDark,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Warning Icon
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.warning,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Title
                  const Text(
                    'Active Crop Exists',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Message
                  Text(
                    'You already have an active crop. Claiming a new device will deactivate the previous crop.\n\nDo you want to continue?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white.withOpacity(0.7),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context, false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(color: AppColors.borderDark),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.warning,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Continue',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Claim Device',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                    _buildDeviceInfoCard(),
                    const SizedBox(height: 24),

                    // Crop Selection (REQUIRED)
                    _buildSectionTitle('Crop Type'),
                    const SizedBox(height: 4),
                    Text(
                      'Select the crop you will grow with this device',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.5),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildCropSelector(),
                    const SizedBox(height: 24),

                    // Optional Metadata
                    _buildSectionTitle('Field Details (Optional)'),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _fieldNameController,
                      label: 'Field Name',
                      hint: 'e.g., Greenhouse A, Field 1',
                      icon: Icons.landscape_outlined,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _notesController,
                      label: 'Notes',
                      hint: 'Optional notes about this crop',
                      icon: Icons.notes_outlined,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 32),

                    // Info Card
                    _buildInfoCard(),
                    const SizedBox(height: 24),

                    // Claim Button
                    _buildClaimButton(),
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
  Widget _buildDeviceInfoCard() {
    final isAssigned = _deviceStatus == 'assigned';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
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
                      widget.deviceName ?? 'ESP32 Controller',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.deviceId,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.5),
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
          Divider(color: AppColors.borderDark, height: 1),
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
              Container(width: 1, height: 30, color: AppColors.borderDark),
              Expanded(child: _buildInfoRow('Type', 'ESP32', Colors.white)),
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
                      'This device is already assigned. Claiming will reassign it.',
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
          style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5)),
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
        dropdownColor: AppColors.surfaceDark,
        decoration: InputDecoration(
          filled: false,
          prefixIcon: Icon(
            Icons.eco_outlined,
            color: _selectedCropType != null
                ? AppColors.primary
                : Colors.white.withOpacity(0.5),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        hint: Text(
          'Select crop type',
          style: TextStyle(color: Colors.white.withOpacity(0.5)),
        ),
        style: const TextStyle(color: Colors.white, fontSize: 16),
        icon: Icon(
          Icons.keyboard_arrow_down,
          color: Colors.white.withOpacity(0.5),
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
        style: const TextStyle(color: Colors.white, fontSize: 16),
        decoration: InputDecoration(
          filled: false,
          labelText: label,
          hintText: hint,
          labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
          prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.5)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  /// ------------------------------------------------
  /// INFO CARD
  /// ------------------------------------------------
  Widget _buildInfoCard() {
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
                const Text(
                  'What happens after claiming?',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.info,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '• Device will be linked to your account\n'
                  '• AI will provide crop-specific recommendations\n'
                  '• Irrigation thresholds will be optimized\n'
                  '• You can view real-time sensor data',
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
  Widget _buildClaimButton() {
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
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.link, size: 22),
                  SizedBox(width: 10),
                  Text(
                    'Claim Device',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Colors.white,
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
