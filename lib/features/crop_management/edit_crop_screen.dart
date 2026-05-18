import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

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

  // Available crop types
  final List<String> _cropTypes = [
    'Tomato',
    'Corn',
    'Wheat',
    'Rice',
    'Potato',
    'Carrot',
    'Lettuce',
    'Cucumber',
    'Pepper',
    'Onion',
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
          'Edit Crop Details',
          style: TextStyle(
            color: Colors.white,
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
                // Crop Image Picker
                _buildImagePicker(),
                const SizedBox(height: 24),

                // Info Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: AppColors.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Update your crop information below',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Crop Type Dropdown
                _buildLabel('Crop Type'),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _cropTypes.contains(_cropTypeController.text)
                      ? _cropTypeController.text
                      : 'Other',
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.surfaceDark,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.borderDark),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.borderDark),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary, width: 2),
                    ),
                    prefixIcon: const Icon(Icons.eco, color: AppColors.primary),
                  ),
                  dropdownColor: AppColors.surfaceDark,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
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
                const SizedBox(height: 20),

                // Field Name Input
                _buildLabel('Field Name'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _fieldNameController,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.surfaceDark,
                    hintText: 'e.g., Field A, North Plot, etc.',
                    hintStyle: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(Icons.location_on, color: AppColors.primary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.borderDark),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.borderDark),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a field name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Notes Input
                _buildLabel('Notes (Optional)'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _notesController,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  maxLines: 4,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.surfaceDark,
                    hintText: 'Add any notes about this crop...',
                    hintStyle: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 14,
                    ),
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(bottom: 60),
                      child: Icon(Icons.notes, color: AppColors.primary),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.borderDark),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.borderDark),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Update Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleUpdateCrop,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.backgroundDark,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.backgroundDark,
                              ),
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle, size: 24),
                              SizedBox(width: 8),
                              Text(
                                'Update Crop',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// ------------------------------------------------
  /// IMAGE PICKER WIDGET
  /// ------------------------------------------------
  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Crop Photo (Optional)'),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _isUploadingImage ? null : _showImageSourceSheet,
          child: Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _pickedImage != null || _imageUrl != null
                    ? AppColors.primary.withOpacity(0.5)
                    : AppColors.borderDark,
                width: 1.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: _buildImageContent(),
            ),
          ),
        ),
        if (_pickedImage != null || _imageUrl != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextButton.icon(
              onPressed: _removeImage,
              icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 18),
              label: const Text(
                'Remove photo',
                style: TextStyle(color: AppColors.error, fontSize: 13),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildImageContent() {
    if (_isUploadingImage) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
            SizedBox(height: 12),
            Text(
              'Uploading...',
              style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 13),
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
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit, color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'Change',
                    style: TextStyle(color: Colors.white, fontSize: 12),
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
            errorBuilder: (_, __, ___) => _buildEmptyImagePlaceholder(),
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
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit, color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'Change',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // Empty placeholder
    return _buildEmptyImagePlaceholder();
  }

  Widget _buildEmptyImagePlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.add_photo_alternate_outlined,
          size: 48,
          color: Colors.white.withOpacity(0.3),
        ),
        const SizedBox(height: 10),
        Text(
          'Tap to add a photo',
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Camera or Gallery',
          style: TextStyle(
            color: Colors.white.withOpacity(0.3),
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
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
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
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Choose Photo Source',
                style: TextStyle(
                  color: Colors.white,
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
                title: const Text(
                  'Take a Photo',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  'Use your camera',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
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
                title: const Text(
                  'Choose from Gallery',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  'Pick from your photos',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
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

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Crop updated successfully'),
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
