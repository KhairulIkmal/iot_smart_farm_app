import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/app_localizations.dart';
import '../../core/theme.dart';

/// ------------------------------------------------------------
/// EDIT CROP SCREEN
/// Allows farmers to update crop details:
/// - Crop Image (camera or gallery)
/// - Crop Type
/// - Field Name
/// - Notes
/// ------------------------------------------------------------
class EditCropScreen extends StatefulWidget {
  final String cropId;
  final String currentCropType;
  final String currentFieldName;
  final String currentNotes;
  final String? currentImageUrl;

  const EditCropScreen({
    super.key,
    required this.cropId,
    required this.currentCropType,
    required this.currentFieldName,
    required this.currentNotes,
    this.currentImageUrl,
  });

  @override
  State<EditCropScreen> createState() => _EditCropScreenState();
}

class _EditCropScreenState extends State<EditCropScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  late TextEditingController _cropTypeController;
  late TextEditingController _fieldNameController;
  late TextEditingController _notesController;

  bool _isLoading = false;
  bool _isUploadingImage = false;
  File? _pickedImage;
  String? _imageUrl;

  // Available crop types — synced with claim_device_screen
  final List<String> _cropTypes = [
    'Tomato',
    'Chili',
    'Lettuce',
    'Cabbage',
    'Cucumber',
    'Carrot',
    'Potato',
    'Onion',
    'Pepper',
    'Spinach',
    'Broccoli',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _cropTypeController = TextEditingController(text: widget.currentCropType);
    _fieldNameController = TextEditingController(text: widget.currentFieldName);
    _notesController = TextEditingController(text: widget.currentNotes);
    _imageUrl = widget.currentImageUrl;
  }

  @override
  void dispose() {
    _cropTypeController.dispose();
    _fieldNameController.dispose();
    _notesController.dispose();
    super.dispose();
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
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: ThemeColors.surface(context),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ThemeColors.border(context)),
              ),
              child: Icon(
                Icons.arrow_back,
                color: AppColors.primary,
                size: 20,
              ),
            ),
          ),
        ),
        title: Text(
          l10n.t('Edit Crop Details'),
          style: TextStyle(
            color: ThemeColors.textPrimary(context),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status Banner
                _buildStatusBanner(),
                const SizedBox(height: 20),

                // Crop Image Picker
                _buildImagePicker(l10n),
                const SizedBox(height: 24),

                // Crop Type Dropdown
                _buildSectionTitle(l10n.t('Crop Type')),
                const SizedBox(height: 12),
                _buildCropTypeDropdown(l10n),
                const SizedBox(height: 20),

                // Field Name Input
                _buildSectionTitle(l10n.t('Field Name')),
                const SizedBox(height: 12),
                _buildStyledTextField(
                  controller: _fieldNameController,
                  hint: l10n.t('e.g., Field A, North Plot, etc.'),
                  icon: Icons.location_on,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a field name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Notes Input
                _buildSectionTitle(l10n.t('Notes (Optional)')),
                const SizedBox(height: 12),
                _buildStyledTextField(
                  controller: _notesController,
                  hint: l10n.t('Add any notes about this crop...'),
                  icon: Icons.notes,
                  maxLines: 4,
                  prefixIconAlignTop: true,
                ),
                const SizedBox(height: 32),

                // Update Button
                _buildUpdateButton(l10n),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// ------------------------------------------------
  /// STATUS BANNER
  /// ------------------------------------------------
  Widget _buildStatusBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.edit_note,
            color: AppColors.primary,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Editing: ${widget.currentCropType} — ${widget.currentFieldName}',
              style: TextStyle(
                fontSize: 13,
                color: ThemeColors.textSecondary(context).withOpacity(0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ------------------------------------------------
  /// SECTION TITLE with green left-border accent
  /// ------------------------------------------------
  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 2,
          height: 20,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Text(
          title,
          style: TextStyle(
            color: ThemeColors.textPrimary(context),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// ------------------------------------------------
  /// CROP TYPE DROPDOWN
  /// ------------------------------------------------
  Widget _buildCropTypeDropdown(AppLocalizations l10n) {
    final currentValue = _cropTypes.contains(_cropTypeController.text)
        ? _cropTypeController.text
        : 'Other';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: DropdownButtonFormField<String>(
        value: currentValue,
        dropdownColor: ThemeColors.surface(context),
        decoration: InputDecoration(
          filled: false,
          prefixIcon: const Icon(Icons.eco, color: AppColors.primary),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        style: TextStyle(color: ThemeColors.textPrimary(context), fontSize: 16),
        icon: Icon(
          Icons.keyboard_arrow_down,
          color: ThemeColors.textSecondary(context).withOpacity(0.5),
        ),
        items: _cropTypes.map((String crop) {
          return DropdownMenuItem<String>(
            value: crop,
            child: Text(crop),
          );
        }).toList(),
        onChanged: (String? newValue) {
          if (newValue != null) {
            setState(() {
              _cropTypeController.text = newValue;
            });
          }
        },
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please select a crop type';
          }
          return null;
        },
      ),
    );
  }

  /// ------------------------------------------------
  /// STYLED TEXT FIELD
  /// ------------------------------------------------
  Widget _buildStyledTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    bool prefixIconAlignTop = false,
    String? Function(String?)? validator,
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
          hintText: hint,
          hintStyle: TextStyle(
            color: ThemeColors.textSecondary(context).withOpacity(0.4),
            fontSize: 14,
          ),
          prefixIcon: prefixIconAlignTop && maxLines > 1
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 60),
                  child: Icon(icon, color: AppColors.primary),
                )
              : Icon(icon, color: AppColors.primary),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
        validator: validator,
      ),
    );
  }

  /// ------------------------------------------------
  /// UPDATE BUTTON
  /// ------------------------------------------------
  Widget _buildUpdateButton(AppLocalizations l10n) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleUpdateCrop,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_rounded, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    l10n.t('Update Crop'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  /// ------------------------------------------------
  /// IMAGE PICKER WIDGET
  /// ------------------------------------------------
  Widget _buildImagePicker(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(l10n.t('Crop Photo (Optional)')),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _isUploadingImage ? null : _showImageSourceSheet,
          child: Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              color: ThemeColors.surface(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _pickedImage != null || _imageUrl != null
                    ? AppColors.primary.withOpacity(0.5)
                    : AppColors.primary.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: _buildImageContent(l10n),
            ),
          ),
        ),
        if (_pickedImage != null || _imageUrl != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextButton.icon(
              onPressed: _removeImage,
              icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 18),
              label: Text(
                l10n.t('Remove photo'),
                style: const TextStyle(color: AppColors.error, fontSize: 13),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildImageContent(AppLocalizations l10n) {
    if (_isUploadingImage) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.t('Uploading...'),
              style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 13),
            ),
          ],
        ),
      );
    }

    // Show locally picked image
    if (_pickedImage != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.file(_pickedImage!, fit: BoxFit.cover),
          Positioned(
            right: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.edit, color: Colors.white, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    l10n.t('Change'),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // Show existing image from Firestore
    if (_imageUrl != null && _imageUrl!.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            _imageUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildEmptyImagePlaceholder(l10n),
          ),
          Positioned(
            right: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.edit, color: Colors.white, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    l10n.t('Change'),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // Empty placeholder
    return _buildEmptyImagePlaceholder(l10n);
  }

  Widget _buildEmptyImagePlaceholder(AppLocalizations l10n) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.add_photo_alternate_outlined,
          size: 48,
          color: ThemeColors.textSecondary(context).withOpacity(0.3),
        ),
        const SizedBox(height: 10),
        Text(
          l10n.t('Tap to add a photo'),
          style: TextStyle(
            color: ThemeColors.textSecondary(context).withOpacity(0.5),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.t('Camera or Gallery'),
          style: TextStyle(
            color: ThemeColors.textSecondary(context).withOpacity(0.3),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  /// ------------------------------------------------
  /// IMAGE ACTIONS
  /// ------------------------------------------------
  void _showImageSourceSheet() {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: ThemeColors.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: ThemeColors.textSecondary(context).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.t('Choose Photo Source'),
                style: TextStyle(
                  color: ThemeColors.textPrimary(context),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.camera_alt, color: AppColors.primary),
                ),
                title: Text(
                  l10n.t('Take a Photo'),
                  style: TextStyle(
                    color: ThemeColors.textPrimary(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  l10n.t('Use your camera'),
                  style: TextStyle(
                    color: ThemeColors.textSecondary(context).withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.photo_library, color: AppColors.primary),
                ),
                title: Text(
                  l10n.t('Choose from Gallery'),
                  style: TextStyle(
                    color: ThemeColors.textPrimary(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  l10n.t('Pick from your photos'),
                  style: TextStyle(
                    color: ThemeColors.textSecondary(context).withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? file = await _picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1080,
    );
    if (file == null) return;

    setState(() {
      _pickedImage = File(file.path);
    });
  }

  void _removeImage() {
    setState(() {
      _pickedImage = null;
      _imageUrl = null;
    });
  }

  /// Upload picked image to Firebase Storage and return the download URL
  Future<String?> _uploadImage() async {
    if (_pickedImage == null) return _imageUrl;

    setState(() => _isUploadingImage = true);
    try {
      final ref = _storage
          .ref()
          .child('crop_images')
          .child('${widget.cropId}.jpg');

      await ref.putFile(_pickedImage!);
      final url = await ref.getDownloadURL();
      return url;
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _handleUpdateCrop() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Upload image if a new one was picked
      final uploadedUrl = await _uploadImage();

      final Map<String, dynamic> updateData = {
        'crop_type': _cropTypeController.text.trim(),
        'field_name': _fieldNameController.text.trim(),
        'notes': _notesController.text.trim(),
        'updated_at': FieldValue.serverTimestamp(),
      };

      // Only update image_url if changed (set or removed)
      if (_pickedImage != null && uploadedUrl != null) {
        updateData['image_url'] = uploadedUrl;
      } else if (_imageUrl == null && widget.currentImageUrl != null) {
        // User removed the image
        updateData['image_url'] = FieldValue.delete();
      }

      await _firestore.collection('crops').doc(widget.cropId).update(updateData);

      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text(l10n.t('Crop updated successfully')),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );

        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Failed to update crop: ${e.toString()}'),
                ),
              ],
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
