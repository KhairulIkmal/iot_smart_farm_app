import 'package:cloud_firestore/cloud_firestore.dart';

/// ------------------------------------------------------------
/// FARM MODEL
///
/// Represents: Farm metadata and location
/// Source: Firestore (`users/{uid}/farm/location` and `users/{uid}/farm/details`)
///
/// Used in:
/// - Weather prediction
/// - Farm settings
/// - Farm location screen
/// - Admin overview
/// ------------------------------------------------------------
class FarmModel {
  final String farmId;
  final String ownerId;
  final String? name;
  final double? latitude;
  final double? longitude;
  final String? address;
  final double? size; // in acres
  final DateTime? updatedAt;

  const FarmModel({
    required this.farmId,
    required this.ownerId,
    this.name,
    this.latitude,
    this.longitude,
    this.address,
    this.size,
    this.updatedAt,
  });

  /// Create from Firestore location document
  factory FarmModel.fromLocationDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
    String ownerId,
  ) {
    final data = doc.data() ?? {};
    return FarmModel(
      farmId: doc.id,
      ownerId: ownerId,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      address: data['address'],
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Create from combined location and details data
  factory FarmModel.fromMaps({
    required String ownerId,
    Map<String, dynamic>? locationData,
    Map<String, dynamic>? detailsData,
  }) {
    return FarmModel(
      farmId: ownerId, // Using ownerId as farmId for simplicity
      ownerId: ownerId,
      name: detailsData?['name'],
      latitude: (locationData?['latitude'] as num?)?.toDouble(),
      longitude: (locationData?['longitude'] as num?)?.toDouble(),
      address: locationData?['address'],
      size: (detailsData?['size'] as num?)?.toDouble(),
      updatedAt:
          (locationData?['updatedAt'] as Timestamp?)?.toDate() ??
          (detailsData?['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Convert location to Map for Firestore
  Map<String, dynamic> toLocationMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Convert details to Map for Firestore
  Map<String, dynamic> toDetailsMap() {
    return {
      'name': name,
      'size': size,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Create a copy with updated fields
  FarmModel copyWith({
    String? farmId,
    String? ownerId,
    String? name,
    double? latitude,
    double? longitude,
    String? address,
    double? size,
    DateTime? updatedAt,
  }) {
    return FarmModel(
      farmId: farmId ?? this.farmId,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      size: size ?? this.size,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Check if location is set
  bool get hasLocation => latitude != null && longitude != null;

  /// Check if coordinates are valid
  bool get hasValidCoordinates {
    if (latitude == null || longitude == null) return false;
    return latitude! >= -90 &&
        latitude! <= 90 &&
        longitude! >= -180 &&
        longitude! <= 180;
  }

  /// Get formatted coordinates string
  String get coordinatesString {
    if (!hasLocation) return 'Not set';
    return '${latitude!.toStringAsFixed(6)}, ${longitude!.toStringAsFixed(6)}';
  }

  /// Get formatted size string
  String get sizeString {
    if (size == null) return 'Not set';
    return '${size!.toStringAsFixed(1)} acres';
  }

  /// Get display name
  String get displayName => name ?? 'My Farm';

  @override
  String toString() {
    return 'FarmModel(farmId: $farmId, ownerId: $ownerId, name: $name, lat: $latitude, lng: $longitude)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FarmModel && other.farmId == farmId;
  }

  @override
  int get hashCode => farmId.hashCode;
}

/// Lightweight location-only model
class FarmLocation {
  final double latitude;
  final double longitude;
  final String? address;

  const FarmLocation({
    required this.latitude,
    required this.longitude,
    this.address,
  });

  factory FarmLocation.fromMap(Map<String, dynamic> map) {
    return FarmLocation(
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      address: map['address'],
    );
  }

  Map<String, dynamic> toMap() {
    return {'latitude': latitude, 'longitude': longitude, 'address': address};
  }

  @override
  String toString() => 'FarmLocation($latitude, $longitude)';
}
