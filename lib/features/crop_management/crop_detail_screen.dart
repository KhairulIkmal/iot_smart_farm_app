import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../services/selected_crop_service.dart';
import '../navigation/main_navigation.dart';
import 'edit_crop_screen.dart';
import 'unclaim_device_dialog.dart';

/// ------------------------------------------------------------
/// CROP DETAIL SCREEN
/// Shows a summary of a single crop:
/// - Crop image / placeholder
/// - Crop info (type, field, age, notes)
/// - Device online status
/// - Live sensor readings (soil, pH, temp, humidity, water)
/// - Actions: Monitor, Edit, Delete
/// ------------------------------------------------------------
class CropDetailScreen extends StatefulWidget {
  final String cropId;
  final String cropType;
  final String deviceId;
  final String fieldName;
  final String notes;
  final String? imageUrl;
  final Timestamp? plantingDate;

  const CropDetailScreen({
    super.key,
    required this.cropId,
    required this.cropType,
    required this.deviceId,
    required this.fieldName,
    required this.notes,
    this.imageUrl,
    this.plantingDate,
  });

  @override
  State<CropDetailScreen> createState() => _CropDetailScreenState();
}

class _CropDetailScreenState extends State<CropDetailScreen> {
  final FirebaseDatabase _rtdb = FirebaseDatabase.instance;

  StreamSubscription<DatabaseEvent>? _sensorSub;

  // Device status
  bool _isOnline = false;
  String _lastSeenText = 'Never';

  // Sensor readings
  int _soil = 0;
  double _ph = 0.0;
  int _temp = 0;
  int _humidity = 0;
  int _waterLevel = 0;
  String _soilHealth = 'ok';
  String _phHealth = 'ok';
  String _waterHealth = 'ok';

  // Editable fields (may be updated after Edit)
  late String _cropType;
  late String _fieldName;
  late String _notes;
  String? _imageUrl;

  @override
  void initState() {
    super.initState();
    _cropType = widget.cropType;
    _fieldName = widget.fieldName;
    _notes = widget.notes;
    _imageUrl = widget.imageUrl;

    _startSensorListener();
  }

  @override
  void dispose() {
    _sensorSub?.cancel();
    super.dispose();
  }

  void _startSensorListener() {
    _sensorSub = _rtdb
        .ref('sensors/${widget.deviceId}')
        .onValue
        .listen((event) {
      if (!mounted || event.snapshot.value == null) return;
      final root = Map<String, dynamic>.from(event.snapshot.value as Map);
      final live = root['live'] != null
          ? Map<String, dynamic>.from(root['live'] as Map)
          : <String, dynamic>{};
      final health = root['sensorHealth'] != null
          ? Map<String, dynamic>.from(root['sensorHealth'] as Map)
          : <String, dynamic>{};

      bool online = false;
      String lastSeenText = 'Never';
      final lastSeenRaw = live['lastSeen'];
      if (lastSeenRaw != null) {
        final ms = (lastSeenRaw as num).toInt();
        final dt = DateTime.fromMillisecondsSinceEpoch(ms);
        final diff = DateTime.now().difference(dt);
        online = diff.inSeconds < 10;
        if (online) {
          lastSeenText = 'Just now';
        } else if (diff.inMinutes < 1) {
          lastSeenText = '${diff.inSeconds}s ago';
        } else if (diff.inMinutes < 60) {
          lastSeenText = '${diff.inMinutes}m ago';
        } else {
          lastSeenText = '${diff.inHours}h ago';
        }
      }

      setState(() {
        _isOnline = online;
        _lastSeenText = lastSeenText;
        _soil = live['soil'] != null ? (live['soil'] as num).toInt() : 0;
        _ph = live['ph'] != null ? (live['ph'] as num).toDouble() : 0.0;
        _temp = live['temperature'] != null
            ? (live['temperature'] as num).toInt()
            : (live['temp'] != null ? (live['temp'] as num).toInt() : 0);
        _humidity =
            live['humidity'] != null ? (live['humidity'] as num).toInt() : 0;
        _waterLevel = live['waterLevel'] != null
            ? (live['waterLevel'] as num).toInt()
            : 0;
        _soilHealth = health['soil']?.toString() ?? 'ok';
        _phHealth = health['ph']?.toString() ?? 'ok';
        _waterHealth = health['waterLevel']?.toString() ?? 'ok';
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCropInfoCard(),
                  const SizedBox(height: 16),
                  _buildDeviceStatusCard(),
                  const SizedBox(height: 16),
                  _buildSensorGrid(),
                  const SizedBox(height: 16),
                  if (_notes.isNotEmpty) ...[
                    _buildNotesCard(),
                    const SizedBox(height: 16),
                  ],
                  _buildActionButtons(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ------------------------------------------------
  /// SLIVER APP BAR with crop image
  /// ------------------------------------------------
  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 240,
      pinned: true,
      backgroundColor: AppColors.backgroundDark,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.black38,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: _imageUrl != null && _imageUrl!.isNotEmpty
            ? Image.network(
                _imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildImagePlaceholder(),
              )
            : _buildImagePlaceholder(),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _getCropColor(_cropType).withOpacity(0.4),
            AppColors.backgroundDark,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          _getCropIcon(_cropType),
          size: 80,
          color: _getCropColor(_cropType).withOpacity(0.4),
        ),
      ),
    );
  }

  /// ------------------------------------------------
  /// CROP INFO CARD
  /// ------------------------------------------------
  Widget _buildCropInfoCard() {
    final age = widget.plantingDate != null
        ? DateTime.now().difference(widget.plantingDate!.toDate())
        : null;
    final ageText = age == null
        ? 'Unknown'
        : age.inDays == 0
            ? 'Today'
            : age.inDays < 7
                ? '${age.inDays} days'
                : age.inDays < 30
                    ? '${age.inDays ~/ 7} weeks'
                    : '${age.inDays ~/ 30} months';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'ACTIVE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _cropType,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _fieldName,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildInfoChip(Icons.calendar_today, 'Age', ageText),
              const SizedBox(width: 12),
              _buildInfoChip(Icons.memory, 'Device', widget.deviceId),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.backgroundDark,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.5),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  /// ------------------------------------------------
  /// DEVICE STATUS CARD
  /// ------------------------------------------------
  Widget _buildDeviceStatusCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isOnline
              ? AppColors.primary.withOpacity(0.4)
              : AppColors.borderDark,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isOnline ? AppColors.primary : AppColors.error,
              boxShadow: _isOnline
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.5),
                        blurRadius: 8,
                        spreadRadius: 1,
                      )
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isOnline ? 'Device Online' : 'Device Offline',
                  style: TextStyle(
                    color: _isOnline ? AppColors.primary : AppColors.error,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Last seen: $_lastSeenText',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.sensors,
            color: _isOnline
                ? AppColors.primary
                : Colors.white.withOpacity(0.3),
            size: 22,
          ),
        ],
      ),
    );
  }

  /// ------------------------------------------------
  /// SENSOR READINGS GRID
  /// ------------------------------------------------
  Widget _buildSensorGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sensor Readings',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white.withOpacity(0.9),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSensorTile(
                icon: Icons.water_drop,
                label: 'Soil Moisture',
                value: '$_soil%',
                health: _soilHealth,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildSensorTile(
                icon: Icons.science,
                label: 'pH Level',
                value: _ph.toStringAsFixed(1),
                health: _phHealth,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildSensorTile(
                icon: Icons.thermostat,
                label: 'Temperature',
                value: '$_temp°C',
                health: 'ok',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildSensorTile(
                icon: Icons.air,
                label: 'Humidity',
                value: '$_humidity%',
                health: 'ok',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildWaterLevelTile(),
      ],
    );
  }

  Widget _buildSensorTile({
    required IconData icon,
    required String label,
    required String value,
    required String health,
  }) {
    final isError = health == 'error';
    final isWarning = health == 'warning';
    final statusColor = isError
        ? AppColors.error
        : isWarning
            ? AppColors.warning
            : AppColors.primary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isError
              ? AppColors.error.withOpacity(0.4)
              : AppColors.borderDark,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: statusColor, size: 20),
              if (isError || isWarning)
                Icon(
                  Icons.warning_amber_rounded,
                  color: statusColor,
                  size: 16,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: _isOnline ? Colors.white : Colors.white.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaterLevelTile() {
    final isError = _waterHealth == 'error';
    final isWarning = _waterHealth == 'warning';
    final statusColor = isError
        ? AppColors.error
        : isWarning
            ? AppColors.warning
            : AppColors.primary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isError
              ? AppColors.error.withOpacity(0.4)
              : AppColors.borderDark,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.water, color: statusColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Water Tank',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                    Text(
                      '$_waterLevel%',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _isOnline
                            ? Colors.white
                            : Colors.white.withOpacity(0.4),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _waterLevel / 100,
                    backgroundColor: AppColors.backgroundDark,
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                    minHeight: 6,
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
  /// NOTES CARD
  /// ------------------------------------------------
  Widget _buildNotesCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.notes, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                'Notes',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _notes,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.85),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  /// ------------------------------------------------
  /// ACTION BUTTONS
  /// ------------------------------------------------
  Widget _buildActionButtons() {
    return Column(
      children: [
        // Monitor Button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _openMonitoring,
            icon: const Icon(Icons.monitor_heart_outlined, size: 20),
            label: const Text(
              'Open Monitoring',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.backgroundDark,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            // Edit Button
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _openEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text(
                    'Edit',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: AppColors.borderDark),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Delete Button
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _openDelete,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text(
                    'Delete',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: BorderSide(color: AppColors.error.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// ------------------------------------------------
  /// ACTIONS
  /// ------------------------------------------------
  void _openMonitoring() {
    final selectedCropService = SelectedCropService();
    selectedCropService.updateSelectedCrop(
      cropId: widget.cropId,
      deviceId: widget.deviceId,
      cropType: _cropType,
    );
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainNavigation()),
      (route) => false,
    );
  }

  Future<void> _openEdit() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditCropScreen(
          cropId: widget.cropId,
          currentCropType: _cropType,
          currentFieldName: _fieldName,
          currentNotes: _notes,
          currentImageUrl: _imageUrl,
        ),
      ),
    );

    if (result == true && mounted) {
      // Reload updated fields from Firestore
      final doc = await FirebaseFirestore.instance
          .collection('crops')
          .doc(widget.cropId)
          .get();
      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _cropType = data['crop_type'] ?? _cropType;
          _fieldName = data['field_name'] ?? _fieldName;
          _notes = data['notes'] ?? '';
          _imageUrl = data['image_url'];
        });
      }
    }
  }

  Future<void> _openDelete() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => UnclaimDeviceDialog(
        cropId: widget.cropId,
        deviceId: widget.deviceId,
        cropType: _cropType,
      ),
    );

    if (result == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  /// ------------------------------------------------
  /// HELPERS
  /// ------------------------------------------------
  Color _getCropColor(String cropType) {
    switch (cropType.toLowerCase()) {
      case 'tomato':
      case 'pepper':
        return Colors.red;
      case 'corn':
      case 'wheat':
        return Colors.amber;
      case 'rice':
      case 'potato':
      case 'carrot':
        return Colors.orange;
      case 'lettuce':
      case 'cucumber':
        return Colors.green;
      case 'onion':
        return Colors.purple;
      default:
        return AppColors.primary;
    }
  }

  IconData _getCropIcon(String cropType) {
    switch (cropType.toLowerCase()) {
      case 'tomato':
      case 'pepper':
        return Icons.local_florist;
      case 'corn':
      case 'wheat':
      case 'rice':
        return Icons.grass;
      case 'potato':
      case 'carrot':
      case 'onion':
        return Icons.eco;
      case 'lettuce':
      case 'cucumber':
        return Icons.spa;
      default:
        return Icons.eco;
    }
  }
}
