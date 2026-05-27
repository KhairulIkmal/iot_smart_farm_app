import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'dart:io';

import '../../../core/app_localizations.dart';
import '../../../core/theme.dart';
import '../../../widgets/index.dart';
import '../../../services/user_counter_service.dart';

/// ------------------------------------------------------------
/// PROFILE SCREEN
///
/// Shows:
/// - User Avatar
/// - Name, Email, Phone
/// - Farm Name
/// - Edit Profile Form
/// ------------------------------------------------------------
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _farmNameController = TextEditingController();

  bool _isLoading = false;
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;
  String? _photoURL;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _farmNameController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Get the custom user document by Auth UID
      final userCounterService = UserCounterService();
      final userDoc = await userCounterService.getUserByAuthUid(user.uid);

      if (userDoc == null || !userDoc.exists) return;

      // Load user data from the document
      final data = userDoc.data() as Map<String, dynamic>;
      _nameController.text = data['name'] ?? data['displayName'] ?? '';
      _phoneController.text = data['phone'] ?? '';
      _farmNameController.text = data['farm_name'] ?? '';
      _photoURL = data['photoURL'];
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Get the custom user document
      final userCounterService = UserCounterService();
      final userDoc = await userCounterService.getUserByAuthUid(user.uid);

      if (userDoc == null) return;
      final customUserId = userDoc.id;

      // Update user document with custom ID
      await _firestore.collection('users').doc(customUserId).set({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'farm_name': _farmNameController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Also update farm details to keep them in sync
      await _firestore
          .collection('users')
          .doc(customUserId)
          .collection('farm')
          .doc('details')
          .set({
        'name': _farmNameController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      setState(() => _isEditing = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Profile updated successfully'),
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
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  /// ------------------------------------------------
  /// PHOTO UPLOAD - SHOW BOTTOM SHEET
  /// ------------------------------------------------
  Future<void> _showPhotoOptions() async {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: ThemeColors.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: ThemeColors.border(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Profile Photo',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: ThemeColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.camera_alt, color: AppColors.primary),
              ),
              title: Text(
                l10n.t('Take Photo'),
                style: TextStyle(color: ThemeColors.textPrimary(context), fontWeight: FontWeight.w500),
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
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.photo_library, color: AppColors.primary),
              ),
              title: Text(
                l10n.t('Choose from Gallery'),
                style: TextStyle(color: ThemeColors.textPrimary(context), fontWeight: FontWeight.w500),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            if (_photoURL != null)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.delete, color: AppColors.error),
                ),
                title: Text(
                  l10n.t('Remove Photo'),
                  style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w500),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _removePhoto();
                },
              ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  /// ------------------------------------------------
  /// PICK IMAGE FROM CAMERA OR GALLERY
  /// ------------------------------------------------
  Future<void> _pickImage(ImageSource source) async {
    try {
      // Step 1: Pick image from camera or gallery
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 100, // Keep high quality before cropping
      );

      if (image == null) return;

      // Step 2: Crop the image
      final CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: image.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressQuality: 85,
        maxWidth: 512,
        maxHeight: 512,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Profile Photo',
            toolbarColor: AppColors.surfaceDark,
            toolbarWidgetColor: Colors.white,
            backgroundColor: AppColors.backgroundDark,
            activeControlsWidgetColor: AppColors.primary,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            hideBottomControls: false,
          ),
          IOSUiSettings(
            title: 'Crop Profile Photo',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            aspectRatioPickerButtonHidden: true,
          ),
        ],
      );

      // If user cancels cropping, return
      if (croppedFile == null) return;

      setState(() => _isUploadingPhoto = true);

      final user = _auth.currentUser;
      if (user == null) return;

      // Get the custom user document
      final userCounterService = UserCounterService();
      final userDoc = await userCounterService.getUserByAuthUid(user.uid);
      if (userDoc == null) return;
      final customUserId = userDoc.id;

      // Step 3: Upload to Firebase Storage
      final storageRef = _storage.ref().child('profile_photos/$customUserId');
      await storageRef.putFile(File(croppedFile.path));

      // Get download URL
      final downloadURL = await storageRef.getDownloadURL();

      // Update Firestore with custom user ID
      await _firestore.collection('users').doc(customUserId).set({
        'photoURL': downloadURL,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      setState(() {
        _photoURL = downloadURL;
        _isUploadingPhoto = false;
      });

      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text(l10n.t('Profile photo updated')),
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
      setState(() => _isUploadingPhoto = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading photo: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// ------------------------------------------------
  /// REMOVE PHOTO
  /// ------------------------------------------------
  Future<void> _removePhoto() async {
    setState(() => _isUploadingPhoto = true);

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Get the custom user document
      final userCounterService = UserCounterService();
      final userDoc = await userCounterService.getUserByAuthUid(user.uid);
      if (userDoc == null) return;
      final customUserId = userDoc.id;

      // Delete from Storage
      try {
        final storageRef = _storage.ref().child('profile_photos/$customUserId');
        await storageRef.delete();
      } catch (_) {
        // Photo might not exist in storage
      }

      // Update Firestore with custom user ID
      await _firestore.collection('users').doc(customUserId).set({
        'photoURL': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      setState(() {
        _photoURL = null;
        _isUploadingPhoto = false;
      });

      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text(l10n.t('Profile photo removed')),
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
      setState(() => _isUploadingPhoto = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing photo: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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
          l10n.t('Profile'),
          style: TextStyle(color: ThemeColors.textPrimary(context), fontWeight: FontWeight.bold),
        ),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
              onPressed: () => setState(() => _isEditing = true),
            ),
        ],
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
                  children: [
                    // Avatar
                    _buildAvatar(),
                    const SizedBox(height: 24),

                    // Email (non-editable)
                    _buildInfoCard(
                      icon: Icons.email_outlined,
                      label: l10n.t('Email'),
                      value: user?.email ?? 'Not set',
                    ),
                    const SizedBox(height: 16),

                    // Name Field
                    CustomTextField(
                      controller: _nameController,
                      label: l10n.t('Full Name'),
                      icon: Icons.person_outline,
                      enabled: _isEditing,
                      validator: (v) =>
                          v?.isEmpty ?? true ? 'Name is required' : null,
                    ),
                    const SizedBox(height: 16),

                    // Phone Field
                    CustomTextField.phone(
                      controller: _phoneController,
                      label: l10n.t('Phone Number'),
                      enabled: _isEditing,
                    ),
                    const SizedBox(height: 16),

                    // Farm Name Field
                    CustomTextField(
                      controller: _farmNameController,
                      label: l10n.t('Farm Name'),
                      icon: Icons.agriculture_outlined,
                      enabled: _isEditing,
                    ),
                    const SizedBox(height: 32),

                    // Save / Cancel Buttons
                    if (_isEditing) ...[
                      CustomButton.primary(
                        text: l10n.t('Save Changes'),
                        onPressed: _isSaving ? null : _saveProfile,
                        isLoading: _isSaving,
                        size: CustomButtonSize.large,
                      ),
                      const SizedBox(height: 12),
                      CustomButton.secondary(
                        text: l10n.t('Cancel'),
                        onPressed: () {
                          _loadUserData();
                          setState(() => _isEditing = false);
                        },
                        size: CustomButtonSize.large,
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildAvatar() {
    final name = _nameController.text;
    return Stack(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.primary.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: _isUploadingPhoto
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    strokeWidth: 3,
                  ),
                )
              : _photoURL != null
                  ? ClipOval(
                      child: Image.network(
                        _photoURL!,
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : 'U',
                              style: const TextStyle(
                                fontSize: 40,
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
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: GestureDetector(
            onTap: _isUploadingPhoto ? null : _showPhotoOptions,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: ThemeColors.bg(context), width: 3),
              ),
              child: const Icon(
                Icons.camera_alt,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
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
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: ThemeColors.textSecondary(context).withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: ThemeColors.textPrimary(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

}
