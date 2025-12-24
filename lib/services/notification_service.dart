import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firestore_service.dart';
import 'rtdb_service.dart';

/// ------------------------------------------------------------
/// NOTIFICATION SERVICE
///
/// Handles all notification and alert operations:
/// - Sensor alerts (error states)
/// - Threshold alerts (low soil, low water)
/// - Weather alerts (from OpenWeather API)
/// - System notifications
///
/// Triggers:
/// - Sensor error (sensorHealth = "error")
/// - Dry soil (soil < 30%)
/// - Low water level (waterLevel < 20%)
/// - High temperature (temp > 35°C)
/// - Weather alerts (rain, heat)
///
/// Storage:
/// - Firestore: users/{uid}/notifications/{notificationId}
///
/// Monitoring:
/// - RTDB: sensors/{deviceId}/live/
/// - RTDB: sensors/{deviceId}/sensorHealth/
/// ------------------------------------------------------------
class NotificationService {
  final FirebaseDatabase _rtdb = FirebaseDatabase.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirestoreService _firestoreService = FirestoreService();
  final RtdbService _rtdbService = RtdbService();

  // Singleton pattern
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // Alert thresholds
  static const double soilLowThreshold = 30.0;
  static const double soilCriticalThreshold = 20.0;
  static const double waterLowThreshold = 40.0;
  static const double waterCriticalThreshold = 20.0;
  static const double tempHighThreshold = 35.0;
  static const double tempLowThreshold = 10.0;
  static const double humidityHighThreshold = 85.0;
  static const double humidityLowThreshold = 25.0;

  // ============================================================
  // NOTIFICATION TYPES
  // ============================================================

  /// Notification type enum as string constants
  static const String typeCritical = 'critical';
  static const String typeWarning = 'warning';
  static const String typeInfo = 'info';
  static const String typeSuccess = 'success';

  // ============================================================
  // CREATE NOTIFICATIONS
  // ============================================================

  /// Create a notification in Firestore
  Future<void> createNotification({
    required String userId,
    required String type,
    required String title,
    required String message,
    String? deviceId,
    String? sensorType,
    Map<String, dynamic>? additionalData,
  }) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .add({
          'type': type,
          'title': title,
          'message': message,
          'deviceId': deviceId,
          'sensorType': sensorType,
          'data': additionalData,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
  }

  /// Create critical alert
  Future<void> createCriticalAlert({
    required String userId,
    required String title,
    required String message,
    String? deviceId,
    String? sensorType,
  }) {
    return createNotification(
      userId: userId,
      type: typeCritical,
      title: title,
      message: message,
      deviceId: deviceId,
      sensorType: sensorType,
    );
  }

  /// Create warning alert
  Future<void> createWarningAlert({
    required String userId,
    required String title,
    required String message,
    String? deviceId,
    String? sensorType,
  }) {
    return createNotification(
      userId: userId,
      type: typeWarning,
      title: title,
      message: message,
      deviceId: deviceId,
      sensorType: sensorType,
    );
  }

  /// Create info notification
  Future<void> createInfoNotification({
    required String userId,
    required String title,
    required String message,
  }) {
    return createNotification(
      userId: userId,
      type: typeInfo,
      title: title,
      message: message,
    );
  }

  /// Create success notification
  Future<void> createSuccessNotification({
    required String userId,
    required String title,
    required String message,
  }) {
    return createNotification(
      userId: userId,
      type: typeSuccess,
      title: title,
      message: message,
    );
  }

  // ============================================================
  // SENSOR MONITORING
  // ============================================================

  /// Check sensor values and create alerts if needed
  Future<List<AlertInfo>> checkSensorAlerts({
    required String userId,
    required String deviceId,
  }) async {
    final List<AlertInfo> alerts = [];

    try {
      // Get live sensor data
      final liveData = await _rtdbService.getLiveData(deviceId);
      if (!liveData.exists || liveData.value == null) {
        return alerts;
      }

      final data = Map<String, dynamic>.from(liveData.value as Map);

      // Get sensor health
      final healthData = await _rtdbService.getSensorHealth(deviceId);

      // Check each sensor
      alerts.addAll(_checkSoilMoisture(data, healthData));
      alerts.addAll(_checkWaterLevel(data, healthData));
      alerts.addAll(_checkTemperature(data, healthData));
      alerts.addAll(_checkHumidity(data, healthData));
      alerts.addAll(_checkPh(data, healthData));

      // Check device connection
      final lastSeen = data['lastSeen'] as int?;
      if (lastSeen != null) {
        final lastSeenDate = DateTime.fromMillisecondsSinceEpoch(
          lastSeen * 1000,
        );
        if (DateTime.now().difference(lastSeenDate).inMinutes > 10) {
          alerts.add(
            AlertInfo(
              type: typeWarning,
              title: 'Device Disconnected',
              message:
                  'ESP32 device has not reported data for over 10 minutes. Check power and connectivity.',
              sensorType: 'connection',
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error checking sensor alerts: $e');
    }

    return alerts;
  }

  List<AlertInfo> _checkSoilMoisture(
    Map<String, dynamic> data,
    Map<String, String> health,
  ) {
    final List<AlertInfo> alerts = [];
    final soil = data['soil'];

    // Check health first
    if (health['soil'] == 'error') {
      alerts.add(
        AlertInfo(
          type: typeCritical,
          title: 'Soil Sensor Error',
          message:
              'Soil moisture sensor is not responding. Check sensor connections.',
          sensorType: 'soil',
        ),
      );
      return alerts;
    }

    if (soil == null) return alerts;
    final value = (soil as num).toDouble();

    if (value < soilCriticalThreshold) {
      alerts.add(
        AlertInfo(
          type: typeCritical,
          title: 'Critical: Soil Too Dry',
          message:
              'Soil moisture is critically low at ${value.toStringAsFixed(0)}%. Immediate irrigation required.',
          sensorType: 'soil',
          value: value,
        ),
      );
    } else if (value < soilLowThreshold) {
      alerts.add(
        AlertInfo(
          type: typeWarning,
          title: 'Low Soil Moisture',
          message:
              'Soil moisture at ${value.toStringAsFixed(0)}%. Consider starting irrigation.',
          sensorType: 'soil',
          value: value,
        ),
      );
    }

    return alerts;
  }

  List<AlertInfo> _checkWaterLevel(
    Map<String, dynamic> data,
    Map<String, String> health,
  ) {
    final List<AlertInfo> alerts = [];
    final waterLevel = data['waterLevel'];

    // Check health first
    if (health['waterLevel'] == 'error') {
      alerts.add(
        AlertInfo(
          type: typeCritical,
          title: 'Water Level Sensor Error',
          message:
              'Water level sensor is not responding. Pump has been auto-stopped for safety.',
          sensorType: 'waterLevel',
        ),
      );
      return alerts;
    }

    if (waterLevel == null) return alerts;
    final value = (waterLevel as num).toDouble();

    if (value < waterCriticalThreshold) {
      alerts.add(
        AlertInfo(
          type: typeCritical,
          title: 'Water Level Critical',
          message:
              'Main tank is below ${value.toStringAsFixed(0)}%. Pump has been auto-stopped to prevent dry running.',
          sensorType: 'waterLevel',
          value: value,
          actions: ['Refill Tank', 'Ignore'],
        ),
      );
    } else if (value < waterLowThreshold) {
      alerts.add(
        AlertInfo(
          type: typeWarning,
          title: 'Low Water Level',
          message:
              'Tank level at ${value.toStringAsFixed(0)}%. Schedule refill soon.',
          sensorType: 'waterLevel',
          value: value,
        ),
      );
    }

    return alerts;
  }

  List<AlertInfo> _checkTemperature(
    Map<String, dynamic> data,
    Map<String, String> health,
  ) {
    final List<AlertInfo> alerts = [];
    final temp = data['temp'];

    if (health['temp'] == 'error') {
      alerts.add(
        AlertInfo(
          type: typeWarning,
          title: 'Temperature Sensor Error',
          message: 'Temperature sensor is not responding. Check connections.',
          sensorType: 'temp',
        ),
      );
      return alerts;
    }

    if (temp == null) return alerts;
    final value = (temp as num).toDouble();

    if (value > tempHighThreshold) {
      alerts.add(
        AlertInfo(
          type: typeWarning,
          title: 'High Temp Warning',
          message:
              'Temperature is ${value.toStringAsFixed(0)}°C, above safe threshold. Ventilation activated.',
          sensorType: 'temp',
          value: value,
        ),
      );
    } else if (value < tempLowThreshold) {
      alerts.add(
        AlertInfo(
          type: typeWarning,
          title: 'Low Temperature Warning',
          message:
              'Temperature dropped to ${value.toStringAsFixed(0)}°C. Crops may need protection.',
          sensorType: 'temp',
          value: value,
        ),
      );
    }

    return alerts;
  }

  List<AlertInfo> _checkHumidity(
    Map<String, dynamic> data,
    Map<String, String> health,
  ) {
    final List<AlertInfo> alerts = [];
    final humidity = data['humidity'];

    if (health['humidity'] == 'error') {
      alerts.add(
        AlertInfo(
          type: typeWarning,
          title: 'Humidity Sensor Error',
          message: 'Humidity sensor is not responding.',
          sensorType: 'humidity',
        ),
      );
      return alerts;
    }

    if (humidity == null) return alerts;
    final value = (humidity as num).toDouble();

    if (value > humidityHighThreshold) {
      alerts.add(
        AlertInfo(
          type: typeWarning,
          title: 'High Humidity Alert',
          message:
              'Humidity at ${value.toStringAsFixed(0)}%. Monitor for fungal diseases.',
          sensorType: 'humidity',
          value: value,
        ),
      );
    } else if (value < humidityLowThreshold) {
      alerts.add(
        AlertInfo(
          type: typeWarning,
          title: 'Low Humidity Alert',
          message:
              'Humidity dropped to ${value.toStringAsFixed(0)}%. Consider misting.',
          sensorType: 'humidity',
          value: value,
        ),
      );
    }

    return alerts;
  }

  List<AlertInfo> _checkPh(
    Map<String, dynamic> data,
    Map<String, String> health,
  ) {
    final List<AlertInfo> alerts = [];
    final ph = data['ph'];

    if (health['ph'] == 'error') {
      alerts.add(
        AlertInfo(
          type: typeWarning,
          title: 'pH Sensor Error',
          message: 'pH sensor is not responding. Calibration may be needed.',
          sensorType: 'ph',
        ),
      );
      return alerts;
    }

    if (ph == null) return alerts;
    final value = (ph as num).toDouble();

    if (value < 5.0) {
      alerts.add(
        AlertInfo(
          type: typeWarning,
          title: 'Soil Too Acidic',
          message:
              'pH level is ${value.toStringAsFixed(1)}, below optimal range. Consider adding lime.',
          sensorType: 'ph',
          value: value,
        ),
      );
    } else if (value > 8.0) {
      alerts.add(
        AlertInfo(
          type: typeWarning,
          title: 'Soil Too Alkaline',
          message:
              'pH level is ${value.toStringAsFixed(1)}, above optimal range. Consider adding sulfur.',
          sensorType: 'ph',
          value: value,
        ),
      );
    }

    return alerts;
  }

  // ============================================================
  // WEATHER ALERTS
  // ============================================================

  /// Create weather-based alert
  Future<void> createWeatherAlert({
    required String userId,
    required String condition,
    required String description,
    double? temperature,
  }) async {
    String title;
    String message;
    String type;

    switch (condition.toLowerCase()) {
      case 'rain':
      case 'drizzle':
        title = 'Rain Expected';
        message =
            'Weather forecast shows rain. Auto-irrigation may be paused to conserve water.';
        type = typeInfo;
        break;
      case 'thunderstorm':
        title = 'Thunderstorm Warning';
        message =
            'Severe weather expected. Outdoor equipment should be secured.';
        type = typeWarning;
        break;
      case 'extreme':
        title = 'Extreme Weather Alert';
        message = description;
        type = typeCritical;
        break;
      default:
        if (temperature != null && temperature > 40) {
          title = 'Heat Wave Warning';
          message =
              'Extreme heat expected (${temperature.toStringAsFixed(0)}°C). Increase irrigation frequency.';
          type = typeWarning;
        } else {
          return; // No alert needed
        }
    }

    await createNotification(
      userId: userId,
      type: type,
      title: title,
      message: message,
      additionalData: {
        'source': 'weather',
        'condition': condition,
        'temperature': temperature,
      },
    );
  }

  // ============================================================
  // SYSTEM NOTIFICATIONS
  // ============================================================

  /// Create irrigation complete notification
  Future<void> notifyIrrigationComplete({
    required String userId,
    required String zone,
    required double waterUsed,
  }) {
    return createSuccessNotification(
      userId: userId,
      title: 'Irrigation Complete',
      message:
          'Scheduled cycle for $zone finished successfully. ${waterUsed.toStringAsFixed(0)}L water used.',
    );
  }

  /// Create firmware update notification
  Future<void> notifyFirmwareUpdate({
    required String userId,
    required String version,
  }) {
    return createInfoNotification(
      userId: userId,
      title: 'Firmware Update',
      message:
          'Main controller updated to v$version. System rebooted successfully.',
    );
  }

  /// Create device claimed notification
  Future<void> notifyDeviceClaimed({
    required String userId,
    required String deviceId,
    required String cropType,
  }) {
    return createSuccessNotification(
      userId: userId,
      title: 'Device Claimed',
      message:
          'Device $deviceId has been linked to your $cropType crop. Monitoring started.',
    );
  }

  // ============================================================
  // NOTIFICATION MANAGEMENT
  // ============================================================

  /// Get unread notification count
  Future<int> getUnreadCount(String userId) async {
    final query = await _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .count()
        .get();

    return query.count ?? 0;
  }

  /// Stream unread count
  Stream<int> streamUnreadCount(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Delete old notifications (older than 30 days)
  Future<void> cleanupOldNotifications(String userId) async {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));

    final oldNotifications = await _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('createdAt', isLessThan: Timestamp.fromDate(cutoff))
        .get();

    final batch = _firestore.batch();
    for (final doc in oldNotifications.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  // ============================================================
  // HELPER METHODS
  // ============================================================

  /// Get icon for notification type
  IconData getNotificationIcon(String type) {
    switch (type) {
      case typeCritical:
        return Icons.error;
      case typeWarning:
        return Icons.warning_amber;
      case typeSuccess:
        return Icons.check_circle;
      case typeInfo:
      default:
        return Icons.info;
    }
  }

  /// Get color for notification type
  Color getNotificationColor(String type) {
    switch (type) {
      case typeCritical:
        return Colors.red;
      case typeWarning:
        return Colors.orange;
      case typeSuccess:
        return Colors.green;
      case typeInfo:
      default:
        return Colors.blue;
    }
  }
}

/// Alert information model
class AlertInfo {
  final String type;
  final String title;
  final String message;
  final String? sensorType;
  final double? value;
  final List<String>? actions;

  AlertInfo({
    required this.type,
    required this.title,
    required this.message,
    this.sensorType,
    this.value,
    this.actions,
  });
}
