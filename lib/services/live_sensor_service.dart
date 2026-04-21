import 'dart:async';

import 'package:firebase_database/firebase_database.dart';

/// Parsed snapshot of all live sensor data for one device.
class LiveSensorData {
  final int soil;
  final double ph;
  final int temp;
  final int humidity;
  final int waterLevel;
  final bool pumpOn;
  final bool isOnline;
  final int? lastSeen;
  final String soilHealth;
  final String phHealth;
  final String waterHealth;

  const LiveSensorData({
    this.soil = 0,
    this.ph = 0.0,
    this.temp = 0,
    this.humidity = 0,
    this.waterLevel = 0,
    this.pumpOn = false,
    this.isOnline = false,
    this.lastSeen,
    this.soilHealth = 'ok',
    this.phHealth = 'ok',
    this.waterHealth = 'ok',
  });

  /// Returns true if any field actually differs from [other].
  bool isDifferentFrom(LiveSensorData other) {
    return soil != other.soil ||
        ph != other.ph ||
        temp != other.temp ||
        humidity != other.humidity ||
        waterLevel != other.waterLevel ||
        pumpOn != other.pumpOn ||
        isOnline != other.isOnline ||
        soilHealth != other.soilHealth ||
        phHealth != other.phHealth ||
        waterHealth != other.waterHealth;
  }
}

/// Singleton that holds ONE Firebase RTDB listener for the active device and
/// broadcasts [LiveSensorData] to all subscribers.
///
/// Why: Dashboard, Sensors, and Irrigation screens were each opening their own
/// `sensors/$deviceId.onValue` listener. Every ESP32 heartbeat fired all of
/// them simultaneously — 4+ setState() calls rebuilding multiple screens at
/// once. This service reduces that to ONE RTDB event → ONE parse → one
/// broadcast that each screen handles independently.
class LiveSensorService {
  static final LiveSensorService _instance = LiveSensorService._internal();
  factory LiveSensorService() => _instance;
  LiveSensorService._internal();

  final FirebaseDatabase _rtdb = FirebaseDatabase.instance;

  String? _activeDeviceId;
  StreamSubscription<DatabaseEvent>? _rtdbSubscription;
  LiveSensorData? _lastData;

  /// The most recently received data. Available immediately for late subscribers
  /// so screens don't show stale values while waiting for first stream event.
  LiveSensorData? get currentData => _lastData;

  final StreamController<LiveSensorData> _controller =
      StreamController<LiveSensorData>.broadcast();

  /// Stream of parsed sensor updates. All screens should subscribe here.
  Stream<LiveSensorData> get stream => _controller.stream;

  /// Switch to listening on [deviceId]. No-op if already listening to same device.
  /// Pass null to stop listening entirely.
  void setDevice(String? deviceId) {
    if (deviceId == _activeDeviceId) return;

    _rtdbSubscription?.cancel();
    _rtdbSubscription = null;
    _activeDeviceId = deviceId;
    _lastData = null;

    if (deviceId == null) return;

    _rtdbSubscription = _rtdb
        .ref('sensors/$deviceId')
        .onValue
        .listen((event) {
      if (event.snapshot.value == null) return;
      final parsed = _parse(event.snapshot.value as Map);

      // Only broadcast if something actually changed — prevents unnecessary
      // setState() calls when ESP32 sends a heartbeat with identical values.
      if (_lastData != null && !parsed.isDifferentFrom(_lastData!)) return;

      _lastData = parsed;
      _controller.add(parsed);
    });
  }

  LiveSensorData _parse(Map raw) {
    final root = Map<String, dynamic>.from(raw);

    final live = root['live'] != null
        ? Map<String, dynamic>.from(root['live'] as Map)
        : <String, dynamic>{};

    final health = root['sensorHealth'] != null
        ? Map<String, dynamic>.from(root['sensorHealth'] as Map)
        : <String, dynamic>{};

    bool isOnline = false;
    final lastSeenRaw = live['lastSeen'];
    int? lastSeenMs;
    if (lastSeenRaw != null) {
      lastSeenMs = (lastSeenRaw as num).toInt();
      final lastSeenDate = DateTime.fromMillisecondsSinceEpoch(lastSeenMs);
      isOnline = DateTime.now().difference(lastSeenDate).inMinutes < 5;
    }

    return LiveSensorData(
      soil: live['soil'] != null ? (live['soil'] as num).toInt() : 0,
      ph: live['ph'] != null ? (live['ph'] as num).toDouble() : 0.0,
      temp: live['temperature'] != null
          ? (live['temperature'] as num).toInt()
          : (live['temp'] != null ? (live['temp'] as num).toInt() : 0),
      humidity:
          live['humidity'] != null ? (live['humidity'] as num).toInt() : 0,
      waterLevel: live['waterLevel'] != null
          ? (live['waterLevel'] as num).toInt()
          : 0,
      pumpOn: live['pumpOn'] == true,
      isOnline: isOnline,
      lastSeen: lastSeenMs,
      soilHealth: health['soil']?.toString() ?? 'ok',
      phHealth: health['ph']?.toString() ?? 'ok',
      waterHealth: health['waterLevel']?.toString() ?? 'ok',
    );
  }
}
