import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/app_localizations.dart';
import '../../core/theme.dart';
import '../../models/crop_model.dart';
import '../../services/firestore_service.dart';
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
  final FirestoreService _firestoreService = FirestoreService();

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

  // Device unique code (AGR-XXXX-XXXX)
  String? _deviceCode;

  // New feature state
  DateTime? _plantingDate;
  DateTime? _expectedHarvestDate;
  String? _growthStage;
  double? _customSoilMin;
  double? _customSoilMax;
  double? _customPhMin;
  double? _customPhMax;
  double? _customTempMin;
  double? _customTempMax;
  List<CropNote> _cropNotes = [];
  List<HarvestEntry> _harvestLog = [];

  @override
  void initState() {
    super.initState();
    _cropType = widget.cropType;
    _fieldName = widget.fieldName;
    _notes = widget.notes;
    _imageUrl = widget.imageUrl;

    _startSensorListener();
    _loadCropData();
  }

  @override
  void dispose() {
    _sensorSub?.cancel();
    super.dispose();
  }

  Future<void> _loadCropData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('crops')
          .doc(widget.cropId)
          .get();
      if (!mounted || !doc.exists) return;
      final data = doc.data()!;

      // Fetch the AGR-XXXX-XXXX code from the device document
      try {
        final deviceDoc = await FirebaseFirestore.instance
            .collection('devices')
            .doc(widget.deviceId)
            .get();
        if (deviceDoc.exists) {
          final code = deviceDoc.data()?['unique_code'] as String?;
          if (mounted && code != null) setState(() => _deviceCode = code);
        }
      } catch (_) {}

      setState(() {
        _plantingDate = (data['planting_date'] as Timestamp?)?.toDate();
        _expectedHarvestDate = (data['expected_harvest_date'] as Timestamp?)?.toDate();
        _growthStage = data['growth_stage'] as String?;
        _customSoilMin = (data['custom_soil_min'] as num?)?.toDouble();
        _customSoilMax = (data['custom_soil_max'] as num?)?.toDouble();
        _customPhMin = (data['custom_ph_min'] as num?)?.toDouble();
        _customPhMax = (data['custom_ph_max'] as num?)?.toDouble();
        _customTempMin = (data['custom_temp_min'] as num?)?.toDouble();
        _customTempMax = (data['custom_temp_max'] as num?)?.toDouble();
        final notesRaw = data['crop_notes'] as List<dynamic>?;
        _cropNotes = notesRaw
            ?.map((e) => CropNote.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList()
          ?? [];
        _cropNotes.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        final harvestRaw = data['harvest_log'] as List<dynamic>?;
        _harvestLog = harvestRaw
            ?.map((e) => HarvestEntry.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList()
          ?? [];
        _harvestLog.sort((a, b) => b.harvestDate.compareTo(a.harvestDate));
      });
    } catch (_) {
      // silently fail; UI will show empty state
    }
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
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: ThemeColors.bg(context),
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCropInfoCard(l10n),
                  const SizedBox(height: 16),
                  _buildLifecycleCard(l10n),
                  const SizedBox(height: 16),
                  _buildDeviceStatusCard(l10n),
                  const SizedBox(height: 16),
                  _buildSensorGrid(l10n),
                  const SizedBox(height: 16),
                  _buildThresholdsCard(l10n),
                  const SizedBox(height: 16),
                  _buildNotesTimeline(l10n),
                  if (_harvestLog.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildHarvestLogCard(l10n),
                  ],
                  const SizedBox(height: 16),
                  _buildActionButtons(l10n),
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
      backgroundColor: ThemeColors.bg(context),
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
            ThemeColors.bg(context),
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
  Widget _buildCropInfoCard(AppLocalizations l10n) {
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
        color: ThemeColors.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ThemeColors.border(context)),
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
                    Text(
                      l10n.t('ACTIVE'),
                      style: const TextStyle(
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
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: ThemeColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _fieldName,
            style: TextStyle(
              fontSize: 14,
              color: ThemeColors.textSecondary(context).withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildInfoChip(Icons.calendar_today, l10n.t('Age'), ageText),
              const SizedBox(width: 12),
              _buildInfoChip(Icons.memory, l10n.t('Device'), _deviceCode ?? '—'),
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
          color: ThemeColors.bg(context),
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
                    color: ThemeColors.textSecondary(context).withOpacity(0.5),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: ThemeColors.textPrimary(context),
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
  /// LIFECYCLE CARD
  /// ------------------------------------------------
  Widget _buildLifecycleCard(AppLocalizations l10n) {
    final stages = [
      ('seedling', '🌱', 'Seedling'),
      ('vegetative', '🌿', 'Vegetative'),
      ('flowering', '🌸', 'Flowering'),
      ('fruiting', '🍅', 'Fruiting'),
      ('ready', '✅', 'Ready'),
    ];

    final daysToHarvest = _expectedHarvestDate != null
        ? _expectedHarvestDate!.difference(DateTime.now()).inDays
        : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ThemeColors.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ThemeColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                const Icon(Icons.timeline, color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Text('Growth Stage', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ThemeColors.textSecondary(context).withOpacity(0.7))),
              ]),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: stages.map((s) {
                final isSelected = _growthStage == s.$1;
                return GestureDetector(
                  onTap: () => _setGrowthStage(s.$1),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary.withOpacity(0.15) : ThemeColors.bg(context),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isSelected ? AppColors.primary : ThemeColors.border(context)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(s.$2, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Text(s.$3, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400, color: isSelected ? AppColors.primary : ThemeColors.textSecondary(context))),
                    ]),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _buildDateChip(
                icon: Icons.eco_outlined,
                label: 'Planted',
                value: _plantingDate != null ? DateFormat('d MMM y').format(_plantingDate!) : 'Tap to set',
                onTap: () => _pickPlantingDate(),
                isSet: _plantingDate != null,
              )),
              const SizedBox(width: 10),
              Expanded(child: _buildDateChip(
                icon: Icons.agriculture_outlined,
                label: 'Est. Harvest',
                value: _expectedHarvestDate != null ? DateFormat('d MMM y').format(_expectedHarvestDate!) : 'Tap to set',
                onTap: () => _pickExpectedHarvestDate(),
                isSet: _expectedHarvestDate != null,
              )),
            ],
          ),
          if (daysToHarvest != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: daysToHarvest <= 7
                    ? AppColors.warning.withOpacity(0.1)
                    : AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                Icon(Icons.hourglass_bottom, size: 16, color: daysToHarvest <= 7 ? AppColors.warning : AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  daysToHarvest < 0
                      ? 'Harvest overdue by ${(-daysToHarvest)} days'
                      : daysToHarvest == 0
                          ? 'Harvest due today!'
                          : '$daysToHarvest days until harvest',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: daysToHarvest <= 7 ? AppColors.warning : AppColors.primary),
                ),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDateChip({required IconData icon, required String label, required String value, required VoidCallback onTap, required bool isSet}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ThemeColors.bg(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ThemeColors.border(context)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 14, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 11, color: ThemeColors.textSecondary(context).withOpacity(0.5), fontWeight: FontWeight.w500)),
          ]),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 12, color: isSet ? ThemeColors.textPrimary(context) : AppColors.primary, fontWeight: isSet ? FontWeight.w600 : FontWeight.w500)),
        ]),
      ),
    );
  }

  /// ------------------------------------------------
  /// DEVICE STATUS CARD
  /// ------------------------------------------------
  Widget _buildDeviceStatusCard(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: ThemeColors.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isOnline
              ? AppColors.primary.withOpacity(0.4)
              : ThemeColors.border(context),
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
                  _isOnline ? l10n.t('Device Online') : l10n.t('Device Offline'),
                  style: TextStyle(
                    color: _isOnline ? AppColors.primary : AppColors.error,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${l10n.t('Last seen:')} $_lastSeenText',
                  style: TextStyle(
                    color: ThemeColors.textSecondary(context).withOpacity(0.4),
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
                : ThemeColors.textSecondary(context).withOpacity(0.3),
            size: 22,
          ),
        ],
      ),
    );
  }

  /// ------------------------------------------------
  /// SENSOR READINGS GRID
  /// ------------------------------------------------
  Widget _buildSensorGrid(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.t('Sensor Readings'),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: ThemeColors.textPrimary(context).withOpacity(0.9),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSensorTile(
                icon: Icons.water_drop,
                label: l10n.t('Soil Moisture'),
                value: '$_soil%',
                health: _soilHealth,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildSensorTile(
                icon: Icons.science,
                label: l10n.t('pH Level'),
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
                label: l10n.t('Temperature'),
                value: '$_temp°C',
                health: 'ok',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildSensorTile(
                icon: Icons.air,
                label: l10n.t('Humidity'),
                value: '$_humidity%',
                health: 'ok',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildWaterLevelTile(l10n),
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
        color: ThemeColors.surface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isError
              ? AppColors.error.withOpacity(0.4)
              : ThemeColors.border(context),
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
              color: _isOnline ? ThemeColors.textPrimary(context) : ThemeColors.textSecondary(context).withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: ThemeColors.textSecondary(context).withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaterLevelTile(AppLocalizations l10n) {
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
        color: ThemeColors.surface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isError
              ? AppColors.error.withOpacity(0.4)
              : ThemeColors.border(context),
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
                      l10n.t('Water Tank'),
                      style: TextStyle(
                        fontSize: 13,
                        color: ThemeColors.textSecondary(context).withOpacity(0.6),
                      ),
                    ),
                    Text(
                      '$_waterLevel%',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _isOnline
                            ? ThemeColors.textPrimary(context)
                            : ThemeColors.textSecondary(context).withOpacity(0.4),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _waterLevel / 100,
                    backgroundColor: ThemeColors.bg(context),
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
  /// THRESHOLDS CARD
  /// ------------------------------------------------
  Widget _buildThresholdsCard(AppLocalizations l10n) {
    final preset = CropPreset.getPreset(_cropType);
    final hasCustom = _customSoilMin != null || _customSoilMax != null || _customPhMin != null || _customPhMax != null || _customTempMin != null || _customTempMax != null;
    final soilMin = _customSoilMin ?? preset?.soilMin ?? 40;
    final soilMax = _customSoilMax ?? preset?.soilMax ?? 70;
    final phMin = _customPhMin ?? preset?.phMin ?? 6.0;
    final phMax = _customPhMax ?? preset?.phMax ?? 7.0;
    final tempMin = _customTempMin ?? preset?.tempMin ?? 20;
    final tempMax = _customTempMax ?? preset?.tempMax ?? 30;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ThemeColors.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ThemeColors.border(context)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            const Icon(Icons.tune, color: AppColors.primary, size: 18),
            const SizedBox(width: 8),
            Text('Thresholds', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ThemeColors.textSecondary(context).withOpacity(0.7))),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: hasCustom ? AppColors.warning.withOpacity(0.1) : AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                hasCustom ? 'Custom' : 'Preset',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: hasCustom ? AppColors.warning : AppColors.primary),
              ),
            ),
          ]),
          GestureDetector(
            onTap: _showThresholdEditor,
            child: const Text('Edit', style: TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _buildThresholdChip(Icons.water_drop, 'Soil', '${soilMin.toInt()}–${soilMax.toInt()}%', AppColors.soilMoisture)),
          const SizedBox(width: 8),
          Expanded(child: _buildThresholdChip(Icons.science, 'pH', '${phMin.toStringAsFixed(1)}–${phMax.toStringAsFixed(1)}', AppColors.phLevel)),
          const SizedBox(width: 8),
          Expanded(child: _buildThresholdChip(Icons.thermostat, 'Temp', '${tempMin.toInt()}–${tempMax.toInt()}°C', AppColors.temperature)),
        ]),
      ]),
    );
  }

  Widget _buildThresholdChip(IconData icon, String label, String range, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(height: 4),
        Text(range, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ThemeColors.textPrimary(context))),
        Text(label, style: TextStyle(fontSize: 10, color: ThemeColors.textSecondary(context).withOpacity(0.5))),
      ]),
    );
  }

  /// ------------------------------------------------
  /// NOTES TIMELINE
  /// ------------------------------------------------
  Widget _buildNotesTimeline(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ThemeColors.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ThemeColors.border(context)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            const Icon(Icons.notes, color: AppColors.primary, size: 18),
            const SizedBox(width: 8),
            Text('Field Notes', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ThemeColors.textSecondary(context).withOpacity(0.7))),
            if (_cropNotes.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                child: Text('${_cropNotes.length}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary)),
              ),
            ],
          ]),
          GestureDetector(
            onTap: _showAddNoteDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add, size: 14, color: AppColors.primary),
                SizedBox(width: 4),
                Text('Add', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
              ]),
            ),
          ),
        ]),
        if (_cropNotes.isEmpty && _notes.isEmpty) ...[
          const SizedBox(height: 20),
          Center(child: Text('No notes yet. Tap Add to record an observation.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: ThemeColors.textSecondary(context).withOpacity(0.4)))),
          const SizedBox(height: 4),
        ] else ...[
          const SizedBox(height: 14),
          if (_cropNotes.isEmpty && _notes.isNotEmpty)
            _buildNoteEntry(timestamp: widget.plantingDate?.toDate() ?? DateTime.now(), content: _notes, isLegacy: true)
          else
            ..._cropNotes.map((note) => _buildNoteEntry(timestamp: note.timestamp, content: note.content, isLegacy: false)),
        ],
      ]),
    );
  }

  Widget _buildNoteEntry({required DateTime timestamp, required String content, required bool isLegacy}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Column(children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: isLegacy ? ThemeColors.textSecondary(context).withOpacity(0.3) : AppColors.primary, shape: BoxShape.circle)),
          if (!isLegacy) Container(width: 1, height: 40, color: ThemeColors.border(context)),
        ]),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(DateFormat('d MMM y, h:mm a').format(timestamp), style: TextStyle(fontSize: 11, color: ThemeColors.textSecondary(context).withOpacity(0.45), fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(content, style: TextStyle(fontSize: 13, color: ThemeColors.textPrimary(context).withOpacity(0.85), height: 1.5)),
        ])),
      ]),
    );
  }

  /// ------------------------------------------------
  /// HARVEST LOG CARD
  /// ------------------------------------------------
  Widget _buildHarvestLogCard(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ThemeColors.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ThemeColors.border(context)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.agriculture, color: AppColors.warning, size: 18),
          const SizedBox(width: 8),
          Text('Harvest Log', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ThemeColors.textSecondary(context).withOpacity(0.7))),
        ]),
        const SizedBox(height: 14),
        ..._harvestLog.map((entry) => _buildHarvestEntry(entry)),
      ]),
    );
  }

  Widget _buildHarvestEntry(HarvestEntry entry) {
    final stars = List.generate(5, (i) => Icon(i < entry.qualityRating ? Icons.star : Icons.star_border, size: 14, color: AppColors.warning));
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ThemeColors.bg(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(DateFormat('d MMM y').format(entry.harvestDate), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ThemeColors.textPrimary(context))),
          Row(children: stars),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          const Icon(Icons.scale, size: 14, color: AppColors.primary),
          const SizedBox(width: 4),
          Text('${entry.yieldKg.toStringAsFixed(1)} kg', style: TextStyle(fontSize: 13, color: ThemeColors.textPrimary(context), fontWeight: FontWeight.w500)),
        ]),
        if (entry.notes.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(entry.notes, style: TextStyle(fontSize: 12, color: ThemeColors.textSecondary(context).withOpacity(0.6))),
        ],
      ]),
    );
  }

  /// ------------------------------------------------
  /// ACTION BUTTONS
  /// ------------------------------------------------
  Widget _buildActionButtons(AppLocalizations l10n) {
    return Column(
      children: [
        // Log Harvest Button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: _showLogHarvestDialog,
            icon: const Icon(Icons.agriculture, size: 18),
            label: const Text('Log Harvest', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.warning,
              side: BorderSide(color: AppColors.warning.withOpacity(0.5)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Monitor Button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _openMonitoring,
            icon: const Icon(Icons.monitor_heart_outlined, size: 20),
            label: Text(
              l10n.t('Open Monitoring'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: ThemeColors.bg(context),
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
                  label: Text(
                    l10n.t('Edit'),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ThemeColors.textPrimary(context),
                    side: BorderSide(color: ThemeColors.border(context)),
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
                  label: Text(
                    l10n.t('Delete'),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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
        deviceCode: _deviceCode,
      ),
    );

    if (result == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _setGrowthStage(String stage) async {
    setState(() => _growthStage = stage);
    await _firestoreService.updateCropLifecycle(widget.cropId, growthStage: stage);
  }

  Future<void> _pickPlantingDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _plantingDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(data: Theme.of(context), child: child!),
    );
    if (picked == null || !mounted) return;
    setState(() => _plantingDate = picked);
    await _firestoreService.updateCropLifecycle(widget.cropId, plantingDate: picked);
  }

  Future<void> _pickExpectedHarvestDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expectedHarvestDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(data: Theme.of(context), child: child!),
    );
    if (picked == null || !mounted) return;
    setState(() => _expectedHarvestDate = picked);
    await _firestoreService.updateCropLifecycle(widget.cropId, expectedHarvestDate: picked);
  }

  Future<void> _showAddNoteDialog() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThemeColors.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Add Field Note', style: TextStyle(color: ThemeColors.textPrimary(context), fontSize: 16, fontWeight: FontWeight.w600)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          style: TextStyle(color: ThemeColors.textPrimary(context)),
          decoration: InputDecoration(
            hintText: 'e.g. Noticed yellowing on lower leaves...',
            hintStyle: TextStyle(color: ThemeColors.textSecondary(context).withOpacity(0.4)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: ThemeColors.border(context))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: ThemeColors.border(context))),
            focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)), borderSide: BorderSide(color: AppColors.primary)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: ThemeColors.textSecondary(context)))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final content = controller.text.trim();
    if (content.isEmpty) return;

    final note = CropNote(id: DateTime.now().millisecondsSinceEpoch.toString(), timestamp: DateTime.now(), content: content);
    await _firestoreService.addCropNote(widget.cropId, note.toMap());
    if (!mounted) return;
    setState(() {
      _cropNotes.insert(0, note);
    });
  }

  Future<void> _showLogHarvestDialog() async {
    double yieldKg = 0;
    int qualityRating = 3;
    final notesController = TextEditingController();
    final yieldController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: ThemeColors.surface(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Log Harvest', style: TextStyle(color: ThemeColors.textPrimary(context), fontSize: 16, fontWeight: FontWeight.w600)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Yield (kg)', style: TextStyle(fontSize: 13, color: ThemeColors.textSecondary(context).withOpacity(0.7), fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              TextField(
                controller: yieldController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(color: ThemeColors.textPrimary(context)),
                onChanged: (v) => yieldKg = double.tryParse(v) ?? 0,
                decoration: InputDecoration(
                  hintText: '0.0',
                  hintStyle: TextStyle(color: ThemeColors.textSecondary(context).withOpacity(0.4)),
                  suffixText: 'kg',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: ThemeColors.border(context))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: ThemeColors.border(context))),
                  focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)), borderSide: BorderSide(color: AppColors.primary)),
                ),
              ),
              const SizedBox(height: 14),
              Text('Quality Rating', style: TextStyle(fontSize: 13, color: ThemeColors.textSecondary(context).withOpacity(0.7), fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              Row(mainAxisAlignment: MainAxisAlignment.start, children: List.generate(5, (i) => GestureDetector(
                onTap: () => setDialogState(() => qualityRating = i + 1),
                child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(i < qualityRating ? Icons.star : Icons.star_border, color: AppColors.warning, size: 28),
                ),
              ))),
              const SizedBox(height: 14),
              Text('Notes (optional)', style: TextStyle(fontSize: 13, color: ThemeColors.textSecondary(context).withOpacity(0.7), fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              TextField(
                controller: notesController,
                maxLines: 2,
                style: TextStyle(color: ThemeColors.textPrimary(context)),
                decoration: InputDecoration(
                  hintText: 'Any observations...',
                  hintStyle: TextStyle(color: ThemeColors.textSecondary(context).withOpacity(0.4)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: ThemeColors.border(context))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: ThemeColors.border(context))),
                  focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)), borderSide: BorderSide(color: AppColors.primary)),
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: ThemeColors.textSecondary(context)))),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Log', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;
    final entry = HarvestEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      harvestDate: DateTime.now(),
      yieldKg: yieldKg,
      qualityRating: qualityRating,
      notes: notesController.text.trim(),
    );
    await _firestoreService.addHarvestEntry(widget.cropId, entry.toMap());
    if (!mounted) return;
    setState(() => _harvestLog.insert(0, entry));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Harvest logged successfully'),
      backgroundColor: ThemeColors.surface(context),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Future<void> _showThresholdEditor() async {
    final preset = CropPreset.getPreset(_cropType);
    final soilMinC = TextEditingController(text: (_customSoilMin ?? preset?.soilMin ?? 40).toInt().toString());
    final soilMaxC = TextEditingController(text: (_customSoilMax ?? preset?.soilMax ?? 70).toInt().toString());
    final phMinC = TextEditingController(text: (_customPhMin ?? preset?.phMin ?? 6.0).toStringAsFixed(1));
    final phMaxC = TextEditingController(text: (_customPhMax ?? preset?.phMax ?? 7.0).toStringAsFixed(1));
    final tempMinC = TextEditingController(text: (_customTempMin ?? preset?.tempMin ?? 20).toInt().toString());
    final tempMaxC = TextEditingController(text: (_customTempMax ?? preset?.tempMax ?? 30).toInt().toString());

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: ThemeColors.surface(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Custom Thresholds', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: ThemeColors.textPrimary(context))),
              TextButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _firestoreService.updateCropThresholds(widget.cropId, clearCustom: true);
                  if (!mounted) return;
                  setState(() {
                    _customSoilMin = _customSoilMax = _customPhMin = _customPhMax = _customTempMin = _customTempMax = null;
                  });
                },
                child: const Text('Reset to Preset', style: TextStyle(color: AppColors.error, fontSize: 13)),
              ),
            ]),
            const SizedBox(height: 4),
            Text('Set min/max for alerts and auto-irrigation', style: TextStyle(fontSize: 12, color: ThemeColors.textSecondary(context).withOpacity(0.5))),
            const SizedBox(height: 20),
            _buildThresholdRow('Soil Moisture (%)', soilMinC, soilMaxC, AppColors.soilMoisture),
            const SizedBox(height: 12),
            _buildThresholdRow('pH Level', phMinC, phMaxC, AppColors.phLevel),
            const SizedBox(height: 12),
            _buildThresholdRow('Temperature (°C)', tempMinC, tempMaxC, AppColors.temperature),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final sm = double.tryParse(soilMinC.text);
                  final sM = double.tryParse(soilMaxC.text);
                  final pm = double.tryParse(phMinC.text);
                  final pM = double.tryParse(phMaxC.text);
                  final tm = double.tryParse(tempMinC.text);
                  final tM = double.tryParse(tempMaxC.text);
                  await _firestoreService.updateCropThresholds(widget.cropId, soilMin: sm, soilMax: sM, phMin: pm, phMax: pM, tempMin: tm, tempMax: tM);
                  if (!mounted) return;
                  setState(() { _customSoilMin = sm; _customSoilMax = sM; _customPhMin = pm; _customPhMax = pM; _customTempMin = tm; _customTempMax = tM; });
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: ThemeColors.bg(context), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                child: const Text('Save Thresholds', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  Widget _buildThresholdRow(String label, TextEditingController minC, TextEditingController maxC, Color color) {
    final fieldStyle = TextStyle(color: ThemeColors.textPrimary(context), fontSize: 14);
    final border = OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: ThemeColors.border(context)));
    const focusBorder = OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8)), borderSide: BorderSide(color: AppColors.primary));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: ThemeColors.textSecondary(context).withOpacity(0.6))),
      ]),
      const SizedBox(height: 6),
      Row(children: [
        Expanded(child: TextField(controller: minC, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: fieldStyle, decoration: InputDecoration(labelText: 'Min', labelStyle: TextStyle(color: ThemeColors.textSecondary(context).withOpacity(0.5)), border: border, enabledBorder: border, focusedBorder: focusBorder, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10), isDense: true))),
        const SizedBox(width: 8),
        Text('—', style: TextStyle(color: ThemeColors.textSecondary(context))),
        const SizedBox(width: 8),
        Expanded(child: TextField(controller: maxC, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: fieldStyle, decoration: InputDecoration(labelText: 'Max', labelStyle: TextStyle(color: ThemeColors.textSecondary(context).withOpacity(0.5)), border: border, enabledBorder: border, focusedBorder: focusBorder, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10), isDense: true))),
      ]),
    ]);
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
