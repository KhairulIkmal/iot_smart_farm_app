import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/theme.dart';

/// ------------------------------------------------------------
/// AI CHATBOT SCREEN (AI ASSIST TAB)
/// Smart Crop Recommendations
/// ------------------------------------------------------------
class AiChatbotScreen extends StatefulWidget {
  const AiChatbotScreen({super.key});

  @override
  State<AiChatbotScreen> createState() => _AiChatbotScreenState();
}

class _AiChatbotScreenState extends State<AiChatbotScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _selectedCrop = 'Tomato';
  bool _isLoading = false;
  Map<String, dynamic>? _recommendations;
  String? _userCropId;

  final List<String> _cropTypes = [
    'Tomato',
    'Cabbage',
    'Carrots',
    'Corn',
    'Wheat',
    'Rice',
    'Potato',
    'Lettuce',
    'Cucumber',
    'Pepper',
    'Onion',
  ];

  final Map<String, Map<String, dynamic>> _cropDatabase = {
    'Tomato': {
      'moistureMin': 60,
      'moistureMax': 80,
      'phMin': 6.0,
      'phMax': 6.8,
      'bestTime': '06:00 AM',
      'frequency': 'Daily',
      'tip':
          'Tomatoes need consistent moisture. Avoid wetting leaves to prevent disease.',
    },
    'Cabbage': {
      'moistureMin': 60,
      'moistureMax': 75,
      'phMin': 6.0,
      'phMax': 7.5,
      'bestTime': '06:00 AM',
      'frequency': 'Every 2 Days',
      'tip':
          'Cabbage needs consistent moisture for head formation. Mulch to retain soil moisture.',
    },
    'Carrots': {
      'moistureMin': 60,
      'moistureMax': 75,
      'phMin': 6.0,
      'phMax': 6.8,
      'bestTime': '06:00 AM',
      'frequency': 'Every 2 Days',
      'tip':
          'Carrots require consistent moisture during germination. Avoid over-watering to prevent root rot.',
    },
    'Corn': {
      'moistureMin': 50,
      'moistureMax': 70,
      'phMin': 5.8,
      'phMax': 7.0,
      'bestTime': '07:00 AM',
      'frequency': 'Every 2-3 Days',
      'tip':
          'Corn needs deep watering. Critical periods are tasseling and ear development.',
    },
    'Wheat': {
      'moistureMin': 40,
      'moistureMax': 60,
      'phMin': 6.0,
      'phMax': 7.5,
      'bestTime': '06:30 AM',
      'frequency': 'Every 3-4 Days',
      'tip':
          'Wheat is drought-tolerant but needs moisture during flowering and grain filling.',
    },
    'Rice': {
      'moistureMin': 80,
      'moistureMax': 95,
      'phMin': 5.5,
      'phMax': 6.5,
      'bestTime': '05:00 AM',
      'frequency': 'Continuous',
      'tip':
          'Rice requires flooded conditions. Maintain 2-5cm water depth during growing season.',
    },
    'Potato': {
      'moistureMin': 60,
      'moistureMax': 80,
      'phMin': 5.0,
      'phMax': 6.0,
      'bestTime': '06:00 AM',
      'frequency': 'Every 2-3 Days',
      'tip':
          'Potatoes need consistent moisture. Irregular watering causes misshapen tubers.',
    },
    'Lettuce': {
      'moistureMin': 65,
      'moistureMax': 80,
      'phMin': 6.0,
      'phMax': 7.0,
      'bestTime': '05:30 AM',
      'frequency': 'Daily',
      'tip':
          'Lettuce has shallow roots. Keep soil consistently moist but not waterlogged.',
    },
    'Cucumber': {
      'moistureMin': 65,
      'moistureMax': 85,
      'phMin': 6.0,
      'phMax': 7.0,
      'bestTime': '06:00 AM',
      'frequency': 'Daily',
      'tip':
          'Cucumbers need consistent moisture. Mulch helps retain soil moisture.',
    },
    'Pepper': {
      'moistureMin': 55,
      'moistureMax': 70,
      'phMin': 6.0,
      'phMax': 6.8,
      'bestTime': '06:30 AM',
      'frequency': 'Every 2 Days',
      'tip':
          'Peppers prefer deep, infrequent watering. Avoid wet foliage to prevent disease.',
    },
    'Onion': {
      'moistureMin': 50,
      'moistureMax': 70,
      'phMin': 6.0,
      'phMax': 7.0,
      'bestTime': '06:00 AM',
      'frequency': 'Every 3 Days',
      'tip':
          'Onions need consistent moisture early on. Reduce watering as bulbs mature.',
    },
  };

  @override
  void initState() {
    super.initState();
    _loadUserCrop();
    _recommendations = _cropDatabase[_selectedCrop];
  }

  Future<void> _loadUserCrop() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final crops = await _firestore
        .collection('crops')
        .where('farmer_id', isEqualTo: user.uid)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();

    if (crops.docs.isNotEmpty) {
      final cropData = crops.docs.first.data();
      setState(() {
        _userCropId = crops.docs.first.id;
        _selectedCrop = cropData['crop_type'] ?? 'Tomato';
        _recommendations = _cropDatabase[_selectedCrop];
      });
    }
  }

  void _getRecommendations() {
    setState(() => _isLoading = true);

    Future.delayed(const Duration(milliseconds: 800), () {
      setState(() {
        _recommendations = _cropDatabase[_selectedCrop];
        _isLoading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildCropSelectorCard(),
              const SizedBox(height: 24),
              if (_recommendations != null) ...[
                _buildOptimalSettingsCard(),
                const SizedBox(height: 16),
                _buildTipCard(),
                const SizedBox(height: 24),
                _buildApplyButton(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'AI Assistant',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Smart Crop Recommendations',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderDark),
          ),
          child: const Icon(
            Icons.help_outline,
            color: AppColors.textSecondaryDark,
            size: 22,
          ),
        ),
      ],
    );
  }

  Widget _buildCropSelectorCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.eco, color: AppColors.primary, size: 22),
              const SizedBox(width: 8),
              const Text(
                'Select Crop',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Vegetable Type',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.backgroundDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderDark),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedCrop,
                isExpanded: true,
                dropdownColor: AppColors.surfaceDark,
                icon: const Icon(
                  Icons.keyboard_arrow_down,
                  color: AppColors.textSecondaryDark,
                ),
                items: _cropTypes.map((crop) {
                  return DropdownMenuItem<String>(
                    value: crop,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.eco,
                          color: AppColors.primary,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          crop,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedCrop = value);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              onPressed: _isLoading ? null : _getRecommendations,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.borderDark),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                    )
                  : const Text(
                      'Get Recommendations',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptimalSettingsCard() {
    if (_recommendations == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                color: AppColors.primary,
                size: 22,
              ),
              const SizedBox(width: 8),
              const Text(
                'Optimal Settings',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildSettingTile(
                  icon: Icons.water_drop,
                  iconColor: AppColors.soilMoisture,
                  label: 'Moisture Range',
                  value:
                      '${_recommendations!['moistureMin']} - ${_recommendations!['moistureMax']}%',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSettingTile(
                  icon: Icons.science,
                  iconColor: AppColors.phLevel,
                  label: 'Ideal pH',
                  value:
                      '${_recommendations!['phMin']} - ${_recommendations!['phMax']}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSettingTile(
                  icon: Icons.wb_sunny,
                  iconColor: AppColors.warning,
                  label: 'Best Time',
                  value: _recommendations!['bestTime'],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSettingTile(
                  icon: Icons.calendar_today,
                  iconColor: AppColors.primary,
                  label: 'Frequency',
                  value: _recommendations!['frequency'],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.backgroundDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTipCard() {
    if (_recommendations == null) return const SizedBox.shrink();

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
          Icon(Icons.info_outline, color: AppColors.info, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _recommendations!['tip'],
              style: TextStyle(
                fontSize: 14,
                color: AppColors.info,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApplyButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _applyToIrrigation,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.backgroundDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 22),
            SizedBox(width: 8),
            Text(
              'Apply to Auto-Irrigation',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _applyToIrrigation() async {
    if (_recommendations == null || _userCropId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No crop selected'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    try {
      final existing = await _firestore
          .collection('irrigation_rules')
          .where('crop_id', isEqualTo: _userCropId)
          .limit(1)
          .get();

      final ruleData = {
        'crop_id': _userCropId,
        'mode': 'auto',
        'soil_min': _recommendations!['moistureMin'],
        'soil_max': _recommendations!['moistureMax'],
        'ph_min': _recommendations!['phMin'],
        'ph_max': _recommendations!['phMax'],
        'schedule': 'morning',
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (existing.docs.isNotEmpty) {
        await existing.docs.first.reference.update(ruleData);
      } else {
        await _firestore.collection('irrigation_rules').add(ruleData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Settings applied to auto-irrigation'),
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
            content: const Text('Failed to apply settings'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }
}
