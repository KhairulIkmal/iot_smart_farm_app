import 'package:cloud_firestore/cloud_firestore.dart';

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
  });

  /// Create from Firestore document
  factory CropModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
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
    );
  }

  /// Create from Map
  factory CropModel.fromMap(Map<String, dynamic> map, String cropId) {
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
    );
  }

  /// Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'farmer_id': farmerId,
      'device_id': deviceId,
      'crop_type': cropType,
      'field_name': fieldName,
      'notes': notes,
      'status': status.value,
    };
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
    );
  }

  /// Check if crop is active
  bool get isActive => status == CropStatus.active;

  /// Check if crop is inactive
  bool get isInactive => status == CropStatus.inactive;

  /// Check if crop was unclaimed (vs harvested/completed)
  bool get wasUnclaimed => unclaimed == true;

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
