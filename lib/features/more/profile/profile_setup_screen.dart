import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';

import '../../../core/app_localizations.dart';
import '../../../core/theme.dart';
import '../../../services/user_counter_service.dart';

/// ------------------------------------------------------------
/// PROFILE SETUP SCREEN
///
/// Used in two contexts:
///  - [isSetupMode] = true  → new-user onboarding step
///  - [isSetupMode] = false → standalone edit (not currently used)
///
/// Saves to:
///  - users/{customId}              : name, phone, photoURL
///  - users/{customId}/farm/details : name, size, farm_type
/// ------------------------------------------------------------
class ProfileSetupScreen extends StatefulWidget {
  final bool isSetupMode;

  const ProfileSetupScreen({super.key, this.isSetupMode = false});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _farmNameController = TextEditingController();
  final _farmSizeController = TextEditingController();

  String _farmType = 'Open Field';
  String? _photoURL;
  bool _isUploadingPhoto = false;
  bool _isSaving = false;
  bool _isLoading = true;
  String? _customUserId;

  static const _farmTypes = ['Open Field', 'Greenhouse', 'Hydroponics', 'Mixed'];

  static const _farmTypeIcons = {
    'Open Field': Icons.landscape_rounded,
    'Greenhouse': Icons.home_work_outlined,
    'Hydroponics': Icons.water_outlined,
    'Mixed': Icons.grid_view_outlined,
  };

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _farmNameController.dispose();
    _farmSizeController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Pre-fill name from Firebase Auth
      _nameController.text = user.displayName ?? '';

      final userDoc = await UserCounterService().getUserByAuthUid(user.uid);
      if (userDoc == null || !userDoc.exists) return;

      _customUserId = userDoc.id;
      final data = userDoc.data() as Map<String, dynamic>? ?? {};

      _nameController.text = data['name'] ?? user.displayName ?? '';
      _phoneController.text = data['phone'] ?? '';
      _farmNameController.text = data['farm_name'] ?? '';
      _photoURL = data['photoURL'];

      // Load farm details
      final farmDoc = await _firestore
          .collection('users')
          .doc(_customUserId)
          .collection('farm')
          .doc('details')
          .get();

      if (farmDoc.exists) {
        final farmData = farmDoc.data()!;
        if (_farmNameController.text.isEmpty) {
          _farmNameController.text = farmData['name'] ?? '';
        }
        _farmSizeController.text =
            (farmData['size'] as num?)?.toString() ?? '';
        _farmType = farmData['farm_type'] ?? 'Open Field';
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      String? cid = _customUserId;
      if (cid == null) {
        final doc = await UserCounterService().getUserByAuthUid(user.uid);
        cid = doc?.id;
      }
      if (cid == null) return;

      final name = _nameController.text.trim();
      final phone = _phoneController.text.trim();
      final farmName = _farmNameController.text.trim();
      final farmSize = double.tryParse(_farmSizeController.text.trim()) ?? 0;

      // Update auth display name
      if (name.isNotEmpty) await user.updateDisplayName(name);

      // Save to users collection
      await _firestore.collection('users').doc(cid).set({
        'name': name,
        'phone': phone,
        'farm_name': farmName,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Save farm details
      await _firestore
          .collection('users')
          .doc(cid)
          .collection('farm')
          .doc('details')
          .set({
        'name': farmName,
        'size': farmSize,
        'farm_type': _farmType,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to save. Please try again.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ─────────────────────────────────────────────
  // PHOTO UPLOAD
  // ─────────────────────────────────────────────
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 100,
      );
      if (image == null) return;

      final CroppedFile? cropped = await ImageCropper().cropImage(
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
          ),
          IOSUiSettings(
            title: 'Crop Profile Photo',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            aspectRatioPickerButtonHidden: true,
          ),
        ],
      );
      if (cropped == null) return;

      setState(() => _isUploadingPhoto = true);

      final user = _auth.currentUser;
      if (user == null) return;

      String? cid = _customUserId;
      if (cid == null) {
        final doc = await UserCounterService().getUserByAuthUid(user.uid);
        cid = doc?.id;
        _customUserId = cid;
      }
      if (cid == null) return;

      final ref = _storage.ref().child('profile_photos/$cid');
      await ref.putFile(File(cropped.path));
      final url = await ref.getDownloadURL();

      await _firestore.collection('users').doc(cid).set({
        'photoURL': url,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) setState(() => _photoURL = url);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to upload photo'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: ThemeColors.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: ThemeColors.border(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Profile Photo',
              style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w700,
                color: ThemeColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 16),
            _photoOptionTile(
              icon: Icons.camera_alt_rounded,
              label: 'Take Photo',
              onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); },
            ),
            _photoOptionTile(
              icon: Icons.photo_library_rounded,
              label: 'Choose from Gallery',
              onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); },
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoOptionTile({required IconData icon, required String label, required VoidCallback onTap}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(label, style: TextStyle(
        color: ThemeColors.textPrimary(context), fontWeight: FontWeight.w500,
      )),
      onTap: onTap,
    );
  }

  // ─────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF1B5E20),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: ThemeColors.bg(context),
      body: Column(
        children: [
          _buildHero(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 28),
                    _buildPhotoSection(),
                    const SizedBox(height: 28),
                    _buildSectionHeader(
                      icon: Icons.person_outline_rounded,
                      title: 'Personal Details',
                    ),
                    const SizedBox(height: 14),
                    _buildField(
                      controller: _nameController,
                      label: 'Full Name',
                      hint: 'e.g. Ahmad Rizal',
                      icon: Icons.person_outline_rounded,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Name is required';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildField(
                      controller: _phoneController,
                      label: 'Phone Number',
                      hint: 'e.g. 0123456789',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                    const SizedBox(height: 28),
                    _buildSectionHeader(
                      icon: Icons.agriculture_outlined,
                      title: 'Farm Details',
                    ),
                    const SizedBox(height: 14),
                    _buildField(
                      controller: _farmNameController,
                      label: 'Farm Name',
                      hint: 'e.g. Ladang Hijau Permai',
                      icon: Icons.agriculture_outlined,
                    ),
                    const SizedBox(height: 14),
                    _buildField(
                      controller: _farmSizeController,
                      label: 'Farm Size (acres)',
                      hint: 'e.g. 2.5',
                      icon: Icons.landscape_outlined,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildFarmTypeSelector(),
                    const SizedBox(height: 32),
                    _buildSaveButton(),
                    if (widget.isSetupMode) ...[
                      const SizedBox(height: 14),
                      Center(
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context, false),
                          child: Text(
                            'Set up later',
                            style: TextStyle(
                              fontSize: 13,
                              color: ThemeColors.textSecondary(context).withOpacity(0.5),
                              decoration: TextDecoration.underline,
                              decorationColor:
                                  ThemeColors.textSecondary(context).withOpacity(0.3),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // HERO BAND
  // ─────────────────────────────────────────────
  Widget _buildHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context, widget.isSetupMode ? false : null),
                child: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.isSetupMode)
                      Container(
                        margin: const EdgeInsets.only(bottom: 3),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF69F0AE).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF69F0AE).withOpacity(0.4)),
                        ),
                        child: const Text(
                          'Almost done!',
                          style: TextStyle(
                            color: Color(0xFF69F0AE),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    const Text(
                      'Complete Your Profile',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.isSetupMode)
                GestureDetector(
                  onTap: () => Navigator.pop(context, false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Text(
                      'Skip',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Add your details so we can personalise\nyour farming experience.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.72),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // PHOTO SECTION
  // ─────────────────────────────────────────────
  Widget _buildPhotoSection() {
    return Center(
      child: GestureDetector(
        onTap: _isUploadingPhoto ? null : _showPhotoOptions,
        child: Stack(
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.1),
                border: Border.all(color: AppColors.primary.withOpacity(0.35), width: 2),
              ),
              child: ClipOval(
                child: _photoURL != null
                    ? Image.network(_photoURL!, fit: BoxFit.cover)
                    : const Icon(Icons.person_rounded, size: 44, color: AppColors.primary),
              ),
            ),
            // Upload indicator overlay
            if (_isUploadingPhoto)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withOpacity(0.45),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 24, height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            // Camera badge
            if (!_isUploadingPhoto)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: ThemeColors.bg(context), width: 2),
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: Colors.black, size: 15),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // SECTION HEADER
  // ─────────────────────────────────────────────
  Widget _buildSectionHeader({required IconData icon, required String title}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primary, size: 16),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: ThemeColors.textPrimary(context),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // FIELD
  // ─────────────────────────────────────────────
  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: ThemeColors.textSecondary(context).withOpacity(0.7),
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: TextStyle(color: ThemeColors.textPrimary(context), fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: ThemeColors.textSecondary(context).withOpacity(0.3),
              fontSize: 14,
            ),
            prefixIcon: Icon(icon, color: AppColors.primary.withOpacity(0.6), size: 20),
            filled: true,
            fillColor: ThemeColors.surface(context),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: ThemeColors.border(context)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: ThemeColors.border(context)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.error, width: 2),
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // FARM TYPE SELECTOR
  // ─────────────────────────────────────────────
  Widget _buildFarmTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Farm Type',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: ThemeColors.textSecondary(context).withOpacity(0.7),
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _farmTypes.map((type) {
            final selected = _farmType == type;
            return GestureDetector(
              onTap: () => setState(() => _farmType = type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary.withOpacity(0.12)
                      : ThemeColors.surface(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected ? AppColors.primary : ThemeColors.border(context),
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _farmTypeIcons[type] ?? Icons.landscape_rounded,
                      size: 15,
                      color: selected ? AppColors.primary : ThemeColors.textSecondary(context).withOpacity(0.5),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      type,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                        color: selected
                            ? AppColors.primary
                            : ThemeColors.textSecondary(context).withOpacity(0.65),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // SAVE BUTTON
  // ─────────────────────────────────────────────
  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.black,
          disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: _isSaving
            ? const SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_rounded, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    widget.isSetupMode ? 'Save & Continue' : 'Save Profile',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
      ),
    );
  }
}
