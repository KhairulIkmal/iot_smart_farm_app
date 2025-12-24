import 'package:firebase_database/firebase_database.dart';

/// ------------------------------------------------------------
/// REALTIME DATABASE SERVICE
///
/// Handles all Firebase Realtime Database operations for:
/// - Live sensor data
/// - Sensor history
/// - Sensor health status
/// - Device commands (pump control)
///
/// RTDB Structure:
/// /sensors/{deviceId}/
///   live/
///     soil, temp, humidity, ph, waterLevel, lastSeen
///   history/
///     soil/{timestamp}: value
///     temp/{timestamp}: value
///     humidity/{timestamp}: value
///     ph/{timestamp}: value
///     waterLevel/{timestamp}: value
///   sensorHealth/
///     soil: "ok" | "error"
///     ph: "ok" | "error"
///     waterLevel: "ok" | "error"
///
/// /commands/{deviceId}/
///   pump: "on" | "off"
///   timestamp: serverTimestamp
///   source: "app" | "auto"
/// ------------------------------------------------------------
class RtdbService {
  final FirebaseDatabase _rtdb = FirebaseDatabase.instance;

  // Singleton pattern
  static final RtdbService _instance = RtdbService._internal();
  factory RtdbService() => _instance;
  RtdbService._internal();

  // ============================================================
  // LIVE SENSOR DATA
  // ============================================================

  /// Get reference to live sensor data
  DatabaseReference getLiveRef(String deviceId) {
    return _rtdb.ref('sensors/$deviceId/live');
  }

  /// Stream all live sensor data
  Stream<DatabaseEvent> streamLiveData(String deviceId) {
    return _rtdb.ref('sensors/$deviceId/live').onValue;
  }

  /// Stream specific sensor live value
  Stream<DatabaseEvent> streamSensorValue(String deviceId, String sensorType) {
    return _rtdb.ref('sensors/$deviceId/live/$sensorType').onValue;
  }

  /// Get all live sensor data (one-time)
  Future<DataSnapshot> getLiveData(String deviceId) {
    return _rtdb.ref('sensors/$deviceId/live').get();
  }

  /// Get specific sensor value (one-time)
  Future<DataSnapshot> getSensorValue(String deviceId, String sensorType) {
    return _rtdb.ref('sensors/$deviceId/live/$sensorType').get();
  }

  /// Get last seen timestamp
  Future<int?> getLastSeen(String deviceId) async {
    final snapshot = await _rtdb.ref('sensors/$deviceId/live/lastSeen').get();
    if (snapshot.exists && snapshot.value != null) {
      return snapshot.value as int;
    }
    return null;
  }

  /// Check if device is online (lastSeen within 5 minutes)
  Future<bool> isDeviceOnline(String deviceId) async {
    final lastSeen = await getLastSeen(deviceId);
    if (lastSeen == null) return false;

    final lastSeenDate = DateTime.fromMillisecondsSinceEpoch(lastSeen * 1000);
    return DateTime.now().difference(lastSeenDate).inMinutes < 5;
  }

  /// Stream device online status
  Stream<bool> streamDeviceOnline(String deviceId) {
    return _rtdb.ref('sensors/$deviceId/live/lastSeen').onValue.map((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) {
        return false;
      }
      final lastSeen = event.snapshot.value as int;
      final lastSeenDate = DateTime.fromMillisecondsSinceEpoch(lastSeen * 1000);
      return DateTime.now().difference(lastSeenDate).inMinutes < 5;
    });
  }

  // ============================================================
  // SENSOR HISTORY DATA
  // ============================================================

  /// Get reference to sensor history
  DatabaseReference getHistoryRef(String deviceId, String sensorType) {
    return _rtdb.ref('sensors/$deviceId/history/$sensorType');
  }

  /// Get sensor history for time range
  Future<Map<int, double>> getSensorHistory({
    required String deviceId,
    required String sensorType,
    required DateTime startTime,
    DateTime? endTime,
    int? limit,
  }) async {
    final startTimestamp = startTime.millisecondsSinceEpoch ~/ 1000;
    final endTimestamp =
        (endTime ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;

    Query query = _rtdb
        .ref('sensors/$deviceId/history/$sensorType')
        .orderByKey()
        .startAt(startTimestamp.toString())
        .endAt(endTimestamp.toString());

    if (limit != null) {
      query = query.limitToLast(limit);
    }

    final snapshot = await query.get();

    final Map<int, double> history = {};

    if (snapshot.exists && snapshot.value != null) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      data.forEach((key, value) {
        final timestamp = int.tryParse(key);
        if (timestamp != null && value != null) {
          history[timestamp] = (value as num).toDouble();
        }
      });
    }

    return history;
  }

  /// Get last 24 hours of sensor data
  Future<Map<int, double>> getLast24Hours(
    String deviceId,
    String sensorType,
  ) async {
    final startTime = DateTime.now().subtract(const Duration(hours: 24));
    return getSensorHistory(
      deviceId: deviceId,
      sensorType: sensorType,
      startTime: startTime,
    );
  }

  /// Get last 7 days of sensor data
  Future<Map<int, double>> getLast7Days(
    String deviceId,
    String sensorType,
  ) async {
    final startTime = DateTime.now().subtract(const Duration(days: 7));
    return getSensorHistory(
      deviceId: deviceId,
      sensorType: sensorType,
      startTime: startTime,
    );
  }

  /// Get latest N history points
  Future<Map<int, double>> getLatestHistory({
    required String deviceId,
    required String sensorType,
    int count = 24,
  }) async {
    final snapshot = await _rtdb
        .ref('sensors/$deviceId/history/$sensorType')
        .orderByKey()
        .limitToLast(count)
        .get();

    final Map<int, double> history = {};

    if (snapshot.exists && snapshot.value != null) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      data.forEach((key, value) {
        final timestamp = int.tryParse(key);
        if (timestamp != null && value != null) {
          history[timestamp] = (value as num).toDouble();
        }
      });
    }

    return history;
  }

  // ============================================================
  // SENSOR HEALTH STATUS
  // ============================================================

  /// Get reference to sensor health
  DatabaseReference getSensorHealthRef(String deviceId) {
    return _rtdb.ref('sensors/$deviceId/sensorHealth');
  }

  /// Stream sensor health status
  Stream<DatabaseEvent> streamSensorHealth(String deviceId) {
    return _rtdb.ref('sensors/$deviceId/sensorHealth').onValue;
  }

  /// Get sensor health (one-time)
  Future<Map<String, String>> getSensorHealth(String deviceId) async {
    final snapshot = await _rtdb.ref('sensors/$deviceId/sensorHealth').get();

    final Map<String, String> health = {};

    if (snapshot.exists && snapshot.value != null) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      data.forEach((key, value) {
        health[key] = value.toString();
      });
    }

    return health;
  }

  /// Check if specific sensor is healthy
  Future<bool> isSensorHealthy(String deviceId, String sensorType) async {
    final snapshot = await _rtdb
        .ref('sensors/$deviceId/sensorHealth/$sensorType')
        .get();
    if (!snapshot.exists || snapshot.value == null) return true;
    return snapshot.value.toString() == 'ok';
  }

  /// Stream specific sensor health
  Stream<bool> streamSensorHealthStatus(String deviceId, String sensorType) {
    return _rtdb.ref('sensors/$deviceId/sensorHealth/$sensorType').onValue.map((
      event,
    ) {
      if (!event.snapshot.exists || event.snapshot.value == null) return true;
      return event.snapshot.value.toString() == 'ok';
    });
  }

  // ============================================================
  // DEVICE COMMANDS (PUMP CONTROL)
  // ============================================================

  /// Get reference to commands
  DatabaseReference getCommandsRef(String deviceId) {
    return _rtdb.ref('commands/$deviceId');
  }

  /// Send pump command
  Future<void> setPumpCommand({
    required String deviceId,
    required bool turnOn,
    String source = 'app',
  }) {
    return _rtdb.ref('commands/$deviceId').set({
      'pump': turnOn ? 'on' : 'off',
      'timestamp': ServerValue.timestamp,
      'source': source,
    });
  }

  /// Get current pump status
  Future<String?> getPumpStatus(String deviceId) async {
    final snapshot = await _rtdb.ref('commands/$deviceId/pump').get();
    if (snapshot.exists && snapshot.value != null) {
      return snapshot.value.toString();
    }
    return null;
  }

  /// Stream pump status
  Stream<String?> streamPumpStatus(String deviceId) {
    return _rtdb.ref('commands/$deviceId/pump').onValue.map((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) return null;
      return event.snapshot.value.toString();
    });
  }

  /// Turn pump on
  Future<void> turnPumpOn(String deviceId) {
    return setPumpCommand(deviceId: deviceId, turnOn: true);
  }

  /// Turn pump off
  Future<void> turnPumpOff(String deviceId) {
    return setPumpCommand(deviceId: deviceId, turnOn: false);
  }

  // ============================================================
  // UTILITY METHODS
  // ============================================================

  /// Parse live sensor data from snapshot
  Map<String, dynamic> parseLiveData(DataSnapshot snapshot) {
    if (!snapshot.exists || snapshot.value == null) {
      return {};
    }
    return Map<String, dynamic>.from(snapshot.value as Map);
  }

  /// Calculate average from history
  double calculateAverage(Map<int, double> history) {
    if (history.isEmpty) return 0;
    final sum = history.values.reduce((a, b) => a + b);
    return sum / history.length;
  }

  /// Calculate min from history
  double calculateMin(Map<int, double> history) {
    if (history.isEmpty) return 0;
    return history.values.reduce((a, b) => a < b ? a : b);
  }

  /// Calculate max from history
  double calculateMax(Map<int, double> history) {
    if (history.isEmpty) return 0;
    return history.values.reduce((a, b) => a > b ? a : b);
  }

  /// Calculate trend (percentage change)
  double calculateTrend(Map<int, double> history) {
    if (history.length < 2) return 0;

    final sortedKeys = history.keys.toList()..sort();
    final oldValue = history[sortedKeys.first]!;
    final newValue = history[sortedKeys.last]!;

    if (oldValue == 0) return 0;
    return ((newValue - oldValue) / oldValue) * 100;
  }

  /// Get sensor display info
  SensorDisplayInfo getSensorDisplayInfo(String sensorType, double value) {
    switch (sensorType) {
      case 'soil':
        return SensorDisplayInfo(
          name: 'Soil Moisture',
          value: value,
          unit: '%',
          status: value < 30
              ? 'Low'
              : value > 70
              ? 'High'
              : 'Normal',
          isWarning: value < 30 || value > 80,
          isCritical: value < 20,
        );
      case 'temp':
        return SensorDisplayInfo(
          name: 'Temperature',
          value: value,
          unit: '°C',
          status: value < 15
              ? 'Cold'
              : value > 35
              ? 'Hot'
              : 'Normal',
          isWarning: value < 15 || value > 35,
          isCritical: value > 40,
        );
      case 'humidity':
        return SensorDisplayInfo(
          name: 'Humidity',
          value: value,
          unit: '%',
          status: value < 30
              ? 'Dry'
              : value > 80
              ? 'Humid'
              : 'Normal',
          isWarning: value < 30 || value > 80,
          isCritical: false,
        );
      case 'ph':
        return SensorDisplayInfo(
          name: 'pH Level',
          value: value,
          unit: 'pH',
          status: value < 5.5
              ? 'Acidic'
              : value > 7.5
              ? 'Alkaline'
              : 'Neutral',
          isWarning: value < 5.5 || value > 7.5,
          isCritical: value < 4.5 || value > 8.5,
        );
      case 'waterLevel':
        return SensorDisplayInfo(
          name: 'Water Level',
          value: value,
          unit: '%',
          status: value < 20
              ? 'Critical'
              : value < 40
              ? 'Low'
              : 'Normal',
          isWarning: value < 40,
          isCritical: value < 20,
        );
      default:
        return SensorDisplayInfo(
          name: sensorType,
          value: value,
          unit: '',
          status: 'Unknown',
          isWarning: false,
          isCritical: false,
        );
    }
  }
}

/// Sensor display information model
class SensorDisplayInfo {
  final String name;
  final double value;
  final String unit;
  final String status;
  final bool isWarning;
  final bool isCritical;

  SensorDisplayInfo({
    required this.name,
    required this.value,
    required this.unit,
    required this.status,
    required this.isWarning,
    required this.isCritical,
  });

  String get formattedValue {
    if (unit == 'pH') {
      return value.toStringAsFixed(1);
    }
    return '${value.toStringAsFixed(0)}$unit';
  }
}
