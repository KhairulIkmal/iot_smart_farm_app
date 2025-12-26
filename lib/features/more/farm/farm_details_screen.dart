import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/theme.dart';

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

      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
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

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('farm')
          .doc('details')
          .set({
            'name': _farmNameController.text.trim(),
            'size': double.tryParse(_farmSizeController.text.trim()) ?? 0,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      // Also update farm_name in user document
      await _firestore.collection('users').doc(user.uid).update({
        'farm_name': _farmNameController.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Farm details saved'),
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
    final user = _auth.currentUser;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderDark),
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ),
        title: const Text(
          'Farm Details',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                    _buildSectionTitle('Farm Information'),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _farmNameController,
                      label: 'Farm Name',
                      icon: Icons.agriculture,
                      validator: (v) =>
                          v?.isEmpty ?? true ? 'Farm name is required' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _farmSizeController,
                      label: 'Farm Size (acres)',
                      icon: Icons.landscape,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 32),

                    // Active Crops Section
                    _buildSectionTitle('Active Crops'),
                    const SizedBox(height: 16),
                    _buildCropsList(user?.uid),
                    const SizedBox(height: 32),

                    // Connected Devices Section
                    _buildSectionTitle('Connected Devices'),
                    const SizedBox(height: 16),
                    _buildDevicesList(user?.uid),
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
                            : const Text(
                                'Save Changes',
                                style: TextStyle(
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
        color: Colors.white.withOpacity(0.5),
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
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
          prefixIcon: Icon(icon, color: AppColors.primary),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  Widget _buildCropsList(String? userId) {
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
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderDark),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.eco_outlined,
                  color: Colors.white.withOpacity(0.3),
                  size: 32,
                ),
                const SizedBox(width: 16),
                Text(
                  'No active crops',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderDark),
          ),
          child: Column(
            children: snapshot.data!.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final cropType = data['crop_type'] ?? 'Unknown';
              final deviceId = data['device_id'] ?? 'N/A';

              return Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.eco,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cropType,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Device: $deviceId',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Active',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildDevicesList(String? userId) {
    if (userId == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('crops')
          .where('farmer_id', isEqualTo: userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderDark),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.devices_outlined,
                  color: Colors.white.withOpacity(0.3),
                  size: 32,
                ),
                const SizedBox(width: 16),
                Text(
                  'No devices connected',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }

        // Get unique device IDs
        final deviceIds = snapshot.data!.docs
            .map((doc) => (doc.data() as Map<String, dynamic>)['device_id'])
            .where((id) => id != null)
            .toSet()
            .toList();

        return Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderDark),
          ),
          child: Column(
            children: deviceIds.map((deviceId) {
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
                      child: const Icon(
                        Icons.developer_board,
                        color: AppColors.info,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            deviceId.toString(),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'ESP32 Controller',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.5),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
