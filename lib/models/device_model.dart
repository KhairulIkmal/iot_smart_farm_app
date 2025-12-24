import 'package:cloud_firestore/cloud_firestore.dart';

/// ------------------------------------------------------------
/// DEVICE MODEL
///
/// Represents: ESP32 device metadata (NOT sensor values)
/// Source: Firestore (`devices/{deviceId}`)
///
/// Used in:
/// - Claim device screen
/// - Admin monitoring
/// - Connectivity checks
/// - Device management
///
/// Does NOT contain:
/// - Sensor readings (that's SensorModel from RTDB)
/// ------------------------------------------------------------
class DeviceModel {
  final String deviceId;
  final String? deviceName;
  final String deviceType;
  final DeviceStatus status;
  final String? assignedTo;
  final String? assignedCropId;
  final String? firmwareVersion;
  final DateTime? registeredAt;
  final DateTime? assignedAt;
  final DateTime? unassignedAt;

  const DeviceModel({
    required this.deviceId,
    this.deviceName,
    this.deviceType = 'ESP32',
    this.status = DeviceStatus.unassigned,
    this.assignedTo,
    this.assignedCropId,
    this.firmwareVersion,
    this.registeredAt,
    this.assignedAt,
    this.unassignedAt,
  });

  /// Create from Firestore document
  factory DeviceModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return DeviceModel(
      deviceId: doc.id,
      deviceName: data['device_name'],
      deviceType: data['device_type'] ?? 'ESP32',
      status: DeviceStatus.fromString(data['status']),
      assignedTo: data['assigned_to'],
      assignedCropId: data['assigned_crop_id'],
      firmwareVersion: data['firmware_version'],
      registeredAt: (data['registeredAt'] as Timestamp?)?.toDate(),
      assignedAt: (data['assignedAt'] as Timestamp?)?.toDate(),
      unassignedAt: (data['unassignedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Create from Map
  factory DeviceModel.fromMap(Map<String, dynamic> map, String deviceId) {
    return DeviceModel(
      deviceId: deviceId,
      deviceName: map['device_name'],
      deviceType: map['device_type'] ?? 'ESP32',
      status: DeviceStatus.fromString(map['status']),
      assignedTo: map['assigned_to'],
      assignedCropId: map['assigned_crop_id'],
      firmwareVersion: map['firmware_version'],
      registeredAt: (map['registeredAt'] as Timestamp?)?.toDate(),
      assignedAt: (map['assignedAt'] as Timestamp?)?.toDate(),
      unassignedAt: (map['unassignedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'device_id': deviceId,
      'device_name': deviceName,
      'device_type': deviceType,
      'status': status.value,
      'assigned_to': assignedTo,
      'assigned_crop_id': assignedCropId,
      'firmware_version': firmwareVersion,
    };
  }

  /// Convert to Map for registration
  Map<String, dynamic> toRegisterMap() {
    return {
      'device_id': deviceId,
      'device_name': deviceName ?? 'ESP32 Controller',
      'device_type': deviceType,
      'status': DeviceStatus.unassigned.value,
      'registeredAt': FieldValue.serverTimestamp(),
    };
  }

  /// Convert to Map for assignment
  Map<String, dynamic> toAssignMap(String userId, String cropId) {
    return {
      'status': DeviceStatus.assigned.value,
      'assigned_to': userId,
      'assigned_crop_id': cropId,
      'assignedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Convert to Map for unassignment
  Map<String, dynamic> toUnassignMap() {
    return {
      'status': DeviceStatus.unassigned.value,
      'assigned_to': FieldValue.delete(),
      'assigned_crop_id': FieldValue.delete(),
      'unassignedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Create a copy with updated fields
  DeviceModel copyWith({
    String? deviceId,
    String? deviceName,
    String? deviceType,
    DeviceStatus? status,
    String? assignedTo,
    String? assignedCropId,
    String? firmwareVersion,
    DateTime? registeredAt,
    DateTime? assignedAt,
    DateTime? unassignedAt,
  }) {
    return DeviceModel(
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      deviceType: deviceType ?? this.deviceType,
      status: status ?? this.status,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedCropId: assignedCropId ?? this.assignedCropId,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      registeredAt: registeredAt ?? this.registeredAt,
      assignedAt: assignedAt ?? this.assignedAt,
      unassignedAt: unassignedAt ?? this.unassignedAt,
    );
  }

  /// Check if device is assigned
  bool get isAssigned => status == DeviceStatus.assigned;

  /// Check if device is unassigned (available)
  bool get isAvailable => status == DeviceStatus.unassigned;

  /// Check if device is assigned to specific user
  bool isAssignedToUser(String userId) => assignedTo == userId;

  /// Get display name
  String get displayName => deviceName ?? 'ESP32 Controller';

  /// Get short device ID for display
  String get shortId {
    if (deviceId.length > 10) {
      return '${deviceId.substring(0, 10)}...';
    }
    return deviceId;
  }

  @override
  String toString() {
    return 'DeviceModel(deviceId: $deviceId, status: ${status.value}, assignedTo: $assignedTo)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DeviceModel && other.deviceId == deviceId;
  }

  @override
  int get hashCode => deviceId.hashCode;
}

/// Device status enum
enum DeviceStatus {
  unassigned('unassigned'),
  assigned('assigned'),
  offline('offline'),
  error('error');

  final String value;
  const DeviceStatus(this.value);

  factory DeviceStatus.fromString(String? status) {
    switch (status?.toLowerCase()) {
      case 'assigned':
        return DeviceStatus.assigned;
      case 'offline':
        return DeviceStatus.offline;
      case 'error':
        return DeviceStatus.error;
      case 'unassigned':
      default:
        return DeviceStatus.unassigned;
    }
  }

  /// Get display text
  String get displayText {
    switch (this) {
      case DeviceStatus.unassigned:
        return 'Available';
      case DeviceStatus.assigned:
        return 'Assigned';
      case DeviceStatus.offline:
        return 'Offline';
      case DeviceStatus.error:
        return 'Error';
    }
  }
}
