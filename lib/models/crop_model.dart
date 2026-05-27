import 'package:cloud_firestore/cloud_firestore.dart';

class CropNote {
  final String id;
  final DateTime timestamp;
  final String content;

  const CropNote({required this.id, required this.timestamp, required this.content});

  factory CropNote.fromMap(Map<String, dynamic> map) {
    return CropNote(
      id: map['id'] as String? ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      content: map['content'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'timestamp': Timestamp.fromDate(timestamp),
    'content': content,
  };
}

class HarvestEntry {
  final String id;
  final DateTime harvestDate;
  final double yieldKg;
  final int qualityRating;
  final String notes;

  const HarvestEntry({
    required this.id,
    required this.harvestDate,
    required this.yieldKg,
    required this.qualityRating,
    this.notes = '',
  });

  factory HarvestEntry.fromMap(Map<String, dynamic> map) {
    return HarvestEntry(
      id: map['id'] as String? ?? '',
      harvestDate: (map['harvest_date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      yieldKg: (map['yield_kg'] as num?)?.toDouble() ?? 0.0,
      qualityRating: (map['quality_rating'] as num?)?.toInt() ?? 3,
      notes: map['notes'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'harvest_date': Timestamp.fromDate(harvestDate),
    'yield_kg': yieldKg,
    'quality_rating': qualityRating,
    'notes': notes,
  };
}

/// ------------------------------------------------------------
/// CROP MODEL
///
/// Represents: Active or historical crop
/// Source: Firestore (`crops/{cropId}`)
///
/// Used in:
/// - Crop management
/// - Dashboard context
/// - AI recommendations
/// - Claim/Unclaim device flow
/// ------------------------------------------------------------
class CropModel {
  final String cropId;
  final String farmerId;
  final String deviceId;
  final String cropType;
  final String? fieldName;
  final String? notes;
  final String? imageUrl;
  final CropStatus status;
  final DateTime? createdAt;
  final DateTime? deactivatedAt;
  final bool? unclaimed;
  final DateTime? plantingDate;
  final DateTime? expectedHarvestDate;
  final String? growthStage;
  final double? customSoilMin;
  final double? customSoilMax;
  final double? customPhMin;
  final double? customPhMax;
  final double? customTempMin;
  final double? customTempMax;
  final List<CropNote> cropNotes;
  final List<HarvestEntry> harvestLog;

  const CropModel({
    required this.cropId,
    required this.farmerId,
    required this.deviceId,
    required this.cropType,
    this.fieldName,
    this.notes,
    this.imageUrl,
    this.status = CropStatus.active,
    this.createdAt,
    this.deactivatedAt,
    this.unclaimed,
    this.plantingDate,
    this.expectedHarvestDate,
    this.growthStage,
    this.customSoilMin,
    this.customSoilMax,
    this.customPhMin,
    this.customPhMax,
    this.customTempMin,
    this.customTempMax,
    this.cropNotes = const [],
    this.harvestLog = const [],
  });

  /// Create from Firestore document
  factory CropModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final notesRaw = data['crop_notes'] as List<dynamic>?;
    final harvestRaw = data['harvest_log'] as List<dynamic>?;
    return CropModel(
      cropId: doc.id,
      farmerId: data['farmer_id'] ?? '',
      deviceId: data['device_id'] ?? '',
      cropType: data['crop_type'] ?? '',
      fieldName: data['field_name'],
      notes: data['notes'],
      imageUrl: data['image_url'],
      status: CropStatus.fromString(data['status']),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      deactivatedAt: (data['deactivatedAt'] as Timestamp?)?.toDate(),
      unclaimed: data['unclaimed'],
      plantingDate: (data['planting_date'] as Timestamp?)?.toDate(),
      expectedHarvestDate: (data['expected_harvest_date'] as Timestamp?)?.toDate(),
      growthStage: data['growth_stage'] as String?,
      customSoilMin: (data['custom_soil_min'] as num?)?.toDouble(),
      customSoilMax: (data['custom_soil_max'] as num?)?.toDouble(),
      customPhMin: (data['custom_ph_min'] as num?)?.toDouble(),
      customPhMax: (data['custom_ph_max'] as num?)?.toDouble(),
      customTempMin: (data['custom_temp_min'] as num?)?.toDouble(),
      customTempMax: (data['custom_temp_max'] as num?)?.toDouble(),
      cropNotes: notesRaw?.map((e) => CropNote.fromMap(Map<String, dynamic>.from(e as Map))).toList() ?? [],
      harvestLog: harvestRaw?.map((e) => HarvestEntry.fromMap(Map<String, dynamic>.from(e as Map))).toList() ?? [],
    );
  }

  /// Create from Map
  factory CropModel.fromMap(Map<String, dynamic> map, String cropId) {
    final notesRaw = map['crop_notes'] as List<dynamic>?;
    final harvestRaw = map['harvest_log'] as List<dynamic>?;
    return CropModel(
      cropId: cropId,
      farmerId: map['farmer_id'] ?? '',
      deviceId: map['device_id'] ?? '',
      cropType: map['crop_type'] ?? '',
      fieldName: map['field_name'],
      notes: map['notes'],
      imageUrl: map['image_url'],
      status: CropStatus.fromString(map['status']),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      deactivatedAt: (map['deactivatedAt'] as Timestamp?)?.toDate(),
      unclaimed: map['unclaimed'],
      plantingDate: (map['planting_date'] as Timestamp?)?.toDate(),
      expectedHarvestDate: (map['expected_harvest_date'] as Timestamp?)?.toDate(),
      growthStage: map['growth_stage'] as String?,
      customSoilMin: (map['custom_soil_min'] as num?)?.toDouble(),
      customSoilMax: (map['custom_soil_max'] as num?)?.toDouble(),
      customPhMin: (map['custom_ph_min'] as num?)?.toDouble(),
      customPhMax: (map['custom_ph_max'] as num?)?.toDouble(),
      customTempMin: (map['custom_temp_min'] as num?)?.toDouble(),
      customTempMax: (map['custom_temp_max'] as num?)?.toDouble(),
      cropNotes: notesRaw?.map((e) => CropNote.fromMap(Map<String, dynamic>.from(e as Map))).toList() ?? [],
      harvestLog: harvestRaw?.map((e) => HarvestEntry.fromMap(Map<String, dynamic>.from(e as Map))).toList() ?? [],
    );
  }

  /// Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'farmer_id': farmerId,
      'device_id': deviceId,
      'crop_type': cropType,
      'field_name': fieldName,
      'notes': notes,
      'status': status.value,
    };
    if (plantingDate != null) map['planting_date'] = Timestamp.fromDate(plantingDate!);
    if (expectedHarvestDate != null) map['expected_harvest_date'] = Timestamp.fromDate(expectedHarvestDate!);
    if (growthStage != null) map['growth_stage'] = growthStage;
    if (customSoilMin != null) map['custom_soil_min'] = customSoilMin;
    if (customSoilMax != null) map['custom_soil_max'] = customSoilMax;
    if (customPhMin != null) map['custom_ph_min'] = customPhMin;
    if (customPhMax != null) map['custom_ph_max'] = customPhMax;
    if (customTempMin != null) map['custom_temp_min'] = customTempMin;
    if (customTempMax != null) map['custom_temp_max'] = customTempMax;
    return map;
  }

  /// Convert to Map for creation
  Map<String, dynamic> toCreateMap() {
    return {...toMap(), 'createdAt': FieldValue.serverTimestamp()};
  }

  /// Create a copy with updated fields
  CropModel copyWith({
    String? cropId,
    String? farmerId,
    String? deviceId,
    String? cropType,
    String? fieldName,
    String? notes,
    String? imageUrl,
    CropStatus? status,
    DateTime? createdAt,
    DateTime? deactivatedAt,
    bool? unclaimed,
    DateTime? plantingDate,
    DateTime? expectedHarvestDate,
    String? growthStage,
    double? customSoilMin,
    double? customSoilMax,
    double? customPhMin,
    double? customPhMax,
    double? customTempMin,
    double? customTempMax,
    List<CropNote>? cropNotes,
    List<HarvestEntry>? harvestLog,
  }) {
    return CropModel(
      cropId: cropId ?? this.cropId,
      farmerId: farmerId ?? this.farmerId,
      deviceId: deviceId ?? this.deviceId,
      cropType: cropType ?? this.cropType,
      fieldName: fieldName ?? this.fieldName,
      notes: notes ?? this.notes,
      imageUrl: imageUrl ?? this.imageUrl,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      deactivatedAt: deactivatedAt ?? this.deactivatedAt,
      unclaimed: unclaimed ?? this.unclaimed,
      plantingDate: plantingDate ?? this.plantingDate,
      expectedHarvestDate: expectedHarvestDate ?? this.expectedHarvestDate,
      growthStage: growthStage ?? this.growthStage,
      customSoilMin: customSoilMin ?? this.customSoilMin,
      customSoilMax: customSoilMax ?? this.customSoilMax,
      customPhMin: customPhMin ?? this.customPhMin,
      customPhMax: customPhMax ?? this.customPhMax,
      customTempMin: customTempMin ?? this.customTempMin,
      customTempMax: customTempMax ?? this.customTempMax,
      cropNotes: cropNotes ?? this.cropNotes,
      harvestLog: harvestLog ?? this.harvestLog,
    );
  }

  /// Check if crop is active
  bool get isActive => status == CropStatus.active;

  /// Check if crop is inactive
  bool get isInactive => status == CropStatus.inactive;

  /// Check if crop was unclaimed (vs harvested/completed)
  bool get wasUnclaimed => unclaimed == true;

  double get effectiveSoilMin => customSoilMin ?? CropPreset.getPreset(cropType)?.soilMin ?? 40;
  double get effectiveSoilMax => customSoilMax ?? CropPreset.getPreset(cropType)?.soilMax ?? 70;
  double get effectivePhMin => customPhMin ?? CropPreset.getPreset(cropType)?.phMin ?? 6.0;
  double get effectivePhMax => customPhMax ?? CropPreset.getPreset(cropType)?.phMax ?? 7.0;
  double get effectiveTempMin => customTempMin ?? CropPreset.getPreset(cropType)?.tempMin ?? 20;
  double get effectiveTempMax => customTempMax ?? CropPreset.getPreset(cropType)?.tempMax ?? 30;
  bool get hasCustomThresholds => customSoilMin != null || customSoilMax != null || customPhMin != null || customPhMax != null || customTempMin != null || customTempMax != null;

  int? get daysToHarvest {
    if (expectedHarvestDate == null) return null;
    return expectedHarvestDate!.difference(DateTime.now()).inDays;
  }

  /// Get display name (crop type + field name)
  String get displayName {
    if (fieldName != null && fieldName!.isNotEmpty) {
      return '$cropType - $fieldName';
    }
    return cropType;
  }

  /// Get age of crop in days
  int? get ageInDays {
    if (createdAt == null) return null;
    return DateTime.now().difference(createdAt!).inDays;
  }

  /// Get formatted age string
  String get ageString {
    final days = ageInDays;
    if (days == null) return 'Unknown';
    if (days == 0) return 'Today';
    if (days == 1) return '1 day';
    if (days < 7) return '$days days';
    if (days < 30) return '${days ~/ 7} weeks';
    return '${days ~/ 30} months';
  }

  @override
  String toString() {
    return 'CropModel(cropId: $cropId, cropType: $cropType, status: ${status.value})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CropModel && other.cropId == cropId;
  }

  @override
  int get hashCode => cropId.hashCode;
}

/// Crop status enum
enum CropStatus {
  active('active'),
  inactive('inactive'),
  harvested('harvested');

  final String value;
  const CropStatus(this.value);

  factory CropStatus.fromString(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
        return CropStatus.active;
      case 'inactive':
        return CropStatus.inactive;
      case 'harvested':
        return CropStatus.harvested;
      default:
        return CropStatus.inactive;
    }
  }
}

/// Crop type presets with optimal thresholds
class CropPreset {
  final String name;
  final double soilMin;
  final double soilMax;
  final double phMin;
  final double phMax;
  final double tempMin;
  final double tempMax;

  const CropPreset({
    required this.name,
    required this.soilMin,
    required this.soilMax,
    required this.phMin,
    required this.phMax,
    required this.tempMin,
    required this.tempMax,
  });

  /// Get preset by crop type
  static CropPreset? getPreset(String cropType) {
    return presets[cropType.toLowerCase()];
  }

  /// Available presets
  static const Map<String, CropPreset> presets = {
    'tomato': CropPreset(
      name: 'Tomato',
      soilMin: 40,
      soilMax: 70,
      phMin: 6.0,
      phMax: 6.8,
      tempMin: 20,
      tempMax: 30,
    ),
    'chili': CropPreset(
      name: 'Chili',
      soilMin: 40,
      soilMax: 60,
      phMin: 6.0,
      phMax: 7.0,
      tempMin: 20,
      tempMax: 35,
    ),
    'lettuce': CropPreset(
      name: 'Lettuce',
      soilMin: 50,
      soilMax: 70,
      phMin: 6.0,
      phMax: 7.0,
      tempMin: 15,
      tempMax: 25,
    ),
    'cabbage': CropPreset(
      name: 'Cabbage',
      soilMin: 60,
      soilMax: 80,
      phMin: 6.0,
      phMax: 7.5,
      tempMin: 15,
      tempMax: 25,
    ),
    'cucumber': CropPreset(
      name: 'Cucumber',
      soilMin: 50,
      soilMax: 70,
      phMin: 6.0,
      phMax: 7.0,
      tempMin: 20,
      tempMax: 30,
    ),
    'carrot': CropPreset(
      name: 'Carrot',
      soilMin: 50,
      soilMax: 70,
      phMin: 6.0,
      phMax: 6.8,
      tempMin: 15,
      tempMax: 25,
    ),
    'potato': CropPreset(
      name: 'Potato',
      soilMin: 60,
      soilMax: 80,
      phMin: 5.5,
      phMax: 6.5,
      tempMin: 15,
      tempMax: 22,
    ),
    'corn': CropPreset(
      name: 'Corn',
      soilMin: 50,
      soilMax: 75,
      phMin: 5.8,
      phMax: 7.0,
      tempMin: 20,
      tempMax: 35,
    ),
    'rice': CropPreset(
      name: 'Rice',
      soilMin: 70,
      soilMax: 90,
      phMin: 5.5,
      phMax: 7.0,
      tempMin: 25,
      tempMax: 35,
    ),
  };
}
