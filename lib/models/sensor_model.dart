/// ------------------------------------------------------------
/// SENSOR MODEL
///
/// Represents: Sensor data abstraction
/// Source: RTDB (`sensors/{deviceId}`)
///
/// Used in:
/// - Dashboard
/// - Sensors overview
/// - Status indicators
/// - Graph screens
///
/// RTDB Structure:
/// /sensors/{deviceId}/
///   live/
///     soil, temp, humidity, ph, waterLevel, lastSeen
///   history/
///     {sensorType}/{timestamp}: value
///   sensorHealth/
///     {sensorType}: "ok" | "error"
/// ------------------------------------------------------------
library;

/// Live sensor data model
class SensorData {
  final String deviceId;
  final double? soil;
  final double? temp;
  final double? humidity;
  final double? ph;
  final double? waterLevel;
  final int? lastSeen;
  final Map<String, String>? sensorHealth;

  const SensorData({
    required this.deviceId,
    this.soil,
    this.temp,
    this.humidity,
    this.ph,
    this.waterLevel,
    this.lastSeen,
    this.sensorHealth,
  });

  /// Create from RTDB snapshot data
  factory SensorData.fromRtdb(String deviceId, Map<dynamic, dynamic>? data) {
    if (data == null) {
      return SensorData(deviceId: deviceId);
    }

    return SensorData(
      deviceId: deviceId,
      soil: (data['soil'] as num?)?.toDouble(),
      temp: (data['temp'] as num?)?.toDouble(),
      humidity: (data['humidity'] as num?)?.toDouble(),
      ph: (data['ph'] as num?)?.toDouble(),
      waterLevel: (data['waterLevel'] as num?)?.toDouble(),
      lastSeen: data['lastSeen'] as int?,
    );
  }

  /// Create from live data map
  factory SensorData.fromLiveData(
    String deviceId,
    Map<String, dynamic> liveData, {
    Map<String, dynamic>? healthData,
  }) {
    Map<String, String>? health;
    if (healthData != null) {
      health = healthData.map((k, v) => MapEntry(k, v.toString()));
    }

    return SensorData(
      deviceId: deviceId,
      soil: (liveData['soil'] as num?)?.toDouble(),
      temp: (liveData['temp'] as num?)?.toDouble(),
      humidity: (liveData['humidity'] as num?)?.toDouble(),
      ph: (liveData['ph'] as num?)?.toDouble(),
      waterLevel: (liveData['waterLevel'] as num?)?.toDouble(),
      lastSeen: liveData['lastSeen'] as int?,
      sensorHealth: health,
    );
  }

  /// Create empty sensor data
  factory SensorData.empty(String deviceId) {
    return SensorData(deviceId: deviceId);
  }

  /// Get sensor value by type
  double? getValue(SensorType type) {
    switch (type) {
      case SensorType.soil:
        return soil;
      case SensorType.temp:
        return temp;
      case SensorType.humidity:
        return humidity;
      case SensorType.ph:
        return ph;
      case SensorType.waterLevel:
        return waterLevel;
    }
  }

  /// Check if sensor is healthy
  bool isSensorHealthy(SensorType type) {
    if (sensorHealth == null) return true;
    final status = sensorHealth![type.key];
    return status == null || status == 'ok';
  }

  /// Check if device is online (last seen within 5 minutes)
  bool get isOnline {
    if (lastSeen == null) return false;
    final lastSeenDate = DateTime.fromMillisecondsSinceEpoch(lastSeen! * 1000);
    return DateTime.now().difference(lastSeenDate).inMinutes < 5;
  }

  /// Get last seen as DateTime
  DateTime? get lastSeenDateTime {
    if (lastSeen == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(lastSeen! * 1000);
  }

  /// Check if any sensor has error
  bool get hasError {
    if (sensorHealth == null) return false;
    return sensorHealth!.values.any((v) => v == 'error');
  }

  /// Get list of sensors with errors
  List<String> get errorSensors {
    if (sensorHealth == null) return [];
    return sensorHealth!.entries
        .where((e) => e.value == 'error')
        .map((e) => e.key)
        .toList();
  }

  /// Create a copy with updated fields
  SensorData copyWith({
    String? deviceId,
    double? soil,
    double? temp,
    double? humidity,
    double? ph,
    double? waterLevel,
    int? lastSeen,
    Map<String, String>? sensorHealth,
  }) {
    return SensorData(
      deviceId: deviceId ?? this.deviceId,
      soil: soil ?? this.soil,
      temp: temp ?? this.temp,
      humidity: humidity ?? this.humidity,
      ph: ph ?? this.ph,
      waterLevel: waterLevel ?? this.waterLevel,
      lastSeen: lastSeen ?? this.lastSeen,
      sensorHealth: sensorHealth ?? this.sensorHealth,
    );
  }

  @override
  String toString() {
    return 'SensorData(deviceId: $deviceId, soil: $soil, temp: $temp, humidity: $humidity, ph: $ph, waterLevel: $waterLevel)';
  }
}

/// Single sensor reading (for history)
class SensorReading {
  final int timestamp;
  final double value;

  const SensorReading({required this.timestamp, required this.value});

  /// Create from map entry
  factory SensorReading.fromEntry(String timestampStr, dynamic value) {
    return SensorReading(
      timestamp: int.tryParse(timestampStr) ?? 0,
      value: (value as num).toDouble(),
    );
  }

  /// Get timestamp as DateTime
  DateTime get dateTime =>
      DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);

  /// Create a copy with updated fields
  SensorReading copyWith({int? timestamp, double? value}) {
    return SensorReading(
      timestamp: timestamp ?? this.timestamp,
      value: value ?? this.value,
    );
  }

  @override
  String toString() => 'SensorReading($timestamp: $value)';
}

/// Sensor type enum
enum SensorType {
  soil('soil', 'Soil Moisture', '%', 0, 100),
  temp('temp', 'Temperature', '°C', 0, 50),
  humidity('humidity', 'Humidity', '%', 0, 100),
  ph('ph', 'pH Level', 'pH', 0, 14),
  waterLevel('waterLevel', 'Water Level', '%', 0, 100);

  final String key;
  final String displayName;
  final String unit;
  final double minValue;
  final double maxValue;

  const SensorType(
    this.key,
    this.displayName,
    this.unit,
    this.minValue,
    this.maxValue,
  );

  /// Get sensor type from key string
  static SensorType? fromKey(String key) {
    return SensorType.values.cast<SensorType?>().firstWhere(
      (e) => e?.key == key,
      orElse: () => null,
    );
  }

  /// Format value with unit
  String formatValue(double? value) {
    if (value == null) return '--';
    if (this == SensorType.ph) {
      return value.toStringAsFixed(1);
    }
    return '${value.toStringAsFixed(0)}$unit';
  }

  /// Get status for value
  SensorStatus getStatus(double? value) {
    if (value == null) return SensorStatus.unknown;

    switch (this) {
      case SensorType.soil:
        if (value < 20) return SensorStatus.critical;
        if (value < 30) return SensorStatus.warning;
        if (value > 80) return SensorStatus.warning;
        if (value >= 40 && value <= 70) return SensorStatus.good;
        return SensorStatus.normal;

      case SensorType.temp:
        if (value < 10 || value > 40) return SensorStatus.critical;
        if (value < 15 || value > 35) return SensorStatus.warning;
        if (value >= 20 && value <= 30) return SensorStatus.good;
        return SensorStatus.normal;

      case SensorType.humidity:
        if (value < 20 || value > 90) return SensorStatus.warning;
        if (value >= 50 && value <= 70) return SensorStatus.good;
        return SensorStatus.normal;

      case SensorType.ph:
        if (value < 4.5 || value > 8.5) return SensorStatus.critical;
        if (value < 5.5 || value > 7.5) return SensorStatus.warning;
        if (value >= 6.0 && value <= 7.0) return SensorStatus.good;
        return SensorStatus.normal;

      case SensorType.waterLevel:
        if (value < 20) return SensorStatus.critical;
        if (value < 40) return SensorStatus.warning;
        if (value > 80) return SensorStatus.good;
        return SensorStatus.normal;
    }
  }
}

/// Sensor status enum
enum SensorStatus {
  good('Good'),
  normal('Normal'),
  warning('Warning'),
  critical('Critical'),
  error('Error'),
  unknown('Unknown');

  final String displayText;
  const SensorStatus(this.displayText);
}

/// Sensor health model
class SensorHealth {
  final String sensorType;
  final bool isHealthy;
  final String? errorMessage;
  final DateTime? lastChecked;

  const SensorHealth({
    required this.sensorType,
    required this.isHealthy,
    this.errorMessage,
    this.lastChecked,
  });

  factory SensorHealth.fromValue(String sensorType, String? value) {
    return SensorHealth(
      sensorType: sensorType,
      isHealthy: value == null || value == 'ok',
      errorMessage: value == 'error' ? 'Sensor not responding' : null,
    );
  }

  @override
  String toString() =>
      'SensorHealth($sensorType: ${isHealthy ? "ok" : "error"})';
}
