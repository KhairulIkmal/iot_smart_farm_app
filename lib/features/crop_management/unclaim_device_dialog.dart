import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/theme.dart';

/// ------------------------------------------------------------
/// REMOVE CROP DIALOG
///
/// PURPOSE:
/// Permanently delete a crop and release its ESP32 device
/// while keeping the system in a valid state.
///
/// DELETING MEANS:
/// - Device is no longer owned (status = available)
/// - Crop is permanently deleted from Firestore
/// - Dashboard access is blocked again
///
/// RECEIVES:
/// - cropId (required)
/// - deviceId (required)
/// - cropType (optional - for display)
/// - deviceCode (optional - human-readable code for display)
///
/// FIRESTORE OPERATIONS (ATOMIC):
/// 1. Delete crop document
/// 2. Update device status to "available", clear farmer fields
///
/// AFTER SUCCESS:
/// - Close dialog
/// - PostLoginRouter re-evaluates → routes to CropManagement
///
/// DOES NOT:
/// - Delete device document
/// - Touch Realtime Database
/// - Navigate manually
/// - Reassign another device
/// ------------------------------------------------------------
class UnclaimDeviceDialog extends StatefulWidget {
  final String cropId;
  final String deviceId;
  final String? cropType;
  final String? deviceCode;

  const UnclaimDeviceDialog({
    super.key,
    required this.cropId,
    required this.deviceId,
    this.cropType,
    this.deviceCode,
  });

  /// Show the dialog
  static Future<bool?> show({
    required BuildContext context,
    required String cropId,
    required String deviceId,
    String? cropType,
    String? deviceCode,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => UnclaimDeviceDialog(
        cropId: cropId,
        deviceId: deviceId,
        cropType: cropType,
        deviceCode: deviceCode,
      ),
    );
  }

  @override
  State<UnclaimDeviceDialog> createState() => _UnclaimDeviceDialogState();
}

class _UnclaimDeviceDialogState extends State<UnclaimDeviceDialog> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;

  /// Perform atomic delete operation
  Future<void> _unclaimDevice() async {
    setState(() => _isLoading = true);

    try {
      // Use Firestore batch for atomic operation
      final batch = _firestore.batch();

      // Update 1 — Delete Crop
      final cropRef = _firestore.collection('crops').doc(widget.cropId);
      batch.delete(cropRef);

      // Update 2 — Reset Device Status
      final deviceRef = _firestore.collection('devices').doc(widget.deviceId);
      batch.update(deviceRef, {
        'status': 'available',
        'assigned_to': FieldValue.delete(),
        'farmer_name': FieldValue.delete(),
        'claimed_at': FieldValue.delete(),
        'assigned_crop_id': FieldValue.delete(),
      });

      // Commit both operations atomically
      await batch.commit();

      // SUCCESS - Close dialog with true result
      if (mounted) {
        Navigator.pop(context, true);
      }
    } on FirebaseException catch (e) {
      _showErrorSnackBar('Firebase error: ${e.message}');
    } catch (e) {
      _showErrorSnackBar('Failed to remove crop. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final displayCode = widget.deviceCode ?? widget.deviceId;

    return Dialog(
      backgroundColor: ThemeColors.surface(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Warning Icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.link_off,
                color: AppColors.error,
                size: 36,
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              'Remove Crop?',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: ThemeColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 8),

            // Device/Crop Info chip
            if (widget.cropType != null || displayCode.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: ThemeColors.bg(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.developer_board,
                      size: 18,
                      color: ThemeColors.textSecondary(context).withOpacity(0.7),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      displayCode,
                      style: TextStyle(
                        fontSize: 14,
                        color: ThemeColors.textSecondary(context).withOpacity(0.7),
                      ),
                    ),
                    if (widget.cropType != null) ...[
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: ThemeColors.textSecondary(context).withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                      ),
                      Icon(
                        Icons.eco,
                        size: 18,
                        color: AppColors.primary.withOpacity(0.7),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        widget.cropType!,
                        style: TextStyle(
                          fontSize: 14,
                          color: ThemeColors.textSecondary(context).withOpacity(0.7),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

            // Warning Message
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.error.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  _buildWarningItem(
                    Icons.delete_forever,
                    'Crop data will be permanently deleted',
                  ),
                  const SizedBox(height: 10),
                  _buildWarningItem(
                    Icons.sensors_off,
                    'Sensor monitoring will stop',
                  ),
                  const SizedBox(height: 10),
                  _buildWarningItem(
                    Icons.people_outline,
                    'Device becomes available to others',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Irreversible Warning
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.warning_amber, size: 16, color: AppColors.warning),
                const SizedBox(width: 6),
                Text(
                  'This action cannot be undone',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.warning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Buttons
            Row(
              children: [
                // Cancel Button
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ThemeColors.textPrimary(context),
                        side: BorderSide(color: ThemeColors.border(context)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Remove Button (Destructive - Red)
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _unclaimDevice,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.error.withOpacity(
                          0.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.link_off, size: 18),
                                SizedBox(width: 6),
                                Text(
                                  'Remove',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWarningItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.error.withOpacity(0.8)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: ThemeColors.textPrimary(context).withOpacity(0.8),
            ),
          ),
        ),
      ],
    );
  }
}
