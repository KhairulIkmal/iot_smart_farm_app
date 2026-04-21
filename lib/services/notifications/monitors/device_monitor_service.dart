import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../notification_service.dart';
import '../models/notification_model.dart';

/// Device Monitor Service
/// Monitors ESP32 devices for offline status and sensor failures
class DeviceMonitorService {
  static final DeviceMonitorService _instance = DeviceMonitorService._internal();
  factory DeviceMonitorService() => _instance;
  DeviceMonitorService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _rtdb = FirebaseDatabase.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  StreamSubscription? _cropsSubscription;
  final Map<String, StreamSubscription> _deviceSubscriptions = {};

  final Set<String> _offlineDevices = {}; // Track notified offline devices
  final Map<String, Set<String>> _failedSensors = {}; // Track notified sensor failures
  final Map<String, String> _lastWaterAlert = {}; // Track last water level alert type
  final Map<String, String> _lastpHAlert = {}; // Track last pH alert
  final Map<String, String> _lastTempAlert = {}; // Track last temperature alert
  final Map<String, String> _lastSoilAlert = {}; // Track last soil moisture alert

  /// Start monitoring all devices for current user
  /// Uses reactive streams — Firestore crops stream drives RTDB device listeners
  void startMonitoring() {
    stopMonitoring();

    final user = _auth.currentUser;
    if (user == null) return;

    // Listen to crops collection — triggers when device assignments change
    _cropsSubscription = _firestore
        .collection('crops')
        .where('farmer_id', isEqualTo: user.uid)
        .snapshots()
        .listen((snapshot) {
      final newDeviceIds = <String>{};
      for (var doc in snapshot.docs) {
        final deviceId = doc.data()['device_id'] as String?;
        if (deviceId != null) newDeviceIds.add(deviceId);
      }
      _updateDeviceSubscriptions(newDeviceIds);
    }, onError: (e) {
      print('[DeviceMonitor] Error on crops stream: $e');
    });
  }

  /// Update RTDB listeners when the set of assigned devices changes
  void _updateDeviceSubscriptions(Set<String> newDeviceIds) {
    // Cancel listeners for devices that are no longer assigned
    final removed = _deviceSubscriptions.keys.toSet().difference(newDeviceIds);
    for (final id in removed) {
      _deviceSubscriptions[id]?.cancel();
      _deviceSubscriptions.remove(id);
    }

    // Start listeners for newly assigned devices
    for (final deviceId in newDeviceIds) {
      if (_deviceSubscriptions.containsKey(deviceId)) continue;

      _deviceSubscriptions[deviceId] = _rtdb
          .ref('sensors/$deviceId')
          .onValue
          .listen((event) {
        if (!event.snapshot.exists) return;
        final deviceData = event.snapshot.value as Map<dynamic, dynamic>;

        _checkDeviceOnlineStatus(deviceId, deviceData);
        _checkSensorHealth(deviceId, deviceData);

        final liveData = deviceData['live'] as Map<dynamic, dynamic>?;
        if (liveData == null) return;

        final waterLevel = liveData['waterLevel'];
        if (waterLevel != null) {
          _checkWaterLevel(deviceId, (waterLevel as num).toDouble());
        }

        final pH = liveData['pH'];
        if (pH != null) {
          _checkpHLevel(deviceId, (pH as num).toDouble());
        }

        final temperature = liveData['temperature'];
        if (temperature != null) {
          print('[DeviceMonitor] Temperature reading: ${temperature}°C for device $deviceId');
          _checkTemperature(deviceId, (temperature as num).toDouble());
        } else {
          print('[DeviceMonitor] No temperature data for device $deviceId');
        }

        final soilMoisture = liveData['soilMoisture'];
        if (soilMoisture != null) {
          _checkSoilMoisture(deviceId, (soilMoisture as num).toDouble());
        }
      }, onError: (e) {
        print('[DeviceMonitor] Error on RTDB stream for $deviceId: $e');
      });
    }
  }

  /// Stop monitoring
  void stopMonitoring() {
    _cropsSubscription?.cancel();
    _cropsSubscription = null;
    for (final sub in _deviceSubscriptions.values) {
      sub.cancel();
    }
    _deviceSubscriptions.clear();
    _offlineDevices.clear();
    _failedSensors.clear();
    _lastWaterAlert.clear();
    _lastpHAlert.clear();
    _lastTempAlert.clear();
    _lastSoilAlert.clear();
  }

  /// Check if device is online based on lastSeen
  Future<void> _checkDeviceOnlineStatus(
      String deviceId, Map<dynamic, dynamic> deviceData) async {
    try {
      final liveData = deviceData['live'] as Map<dynamic, dynamic>?;
      if (liveData == null) return;

      final lastSeen = liveData['lastSeen'] as int?;
      if (lastSeen == null) return;

      final lastSeenTime = DateTime.fromMillisecondsSinceEpoch(lastSeen);
      final timeSinceLastSeen = DateTime.now().difference(lastSeenTime);

      // Device is offline if lastSeen > 2 minutes
      if (timeSinceLastSeen.inMinutes > 2) {
        // Only notify once per offline event
        if (!_offlineDevices.contains(deviceId)) {
          _offlineDevices.add(deviceId);
          await _notificationService.createNotification(
            severity: NotificationSeverity.critical,
            category: NotificationCategory.device,
            title: 'Device Offline',
            message:
                'Device $deviceId has been offline for ${timeSinceLastSeen.inMinutes} minutes. Check power and internet connection.',
            data: {
              'deviceId': deviceId,
              'lastSeen': lastSeen,
              'offlineDuration': timeSinceLastSeen.inMinutes,
            },
          );
        }
      } else {
        // Device is back online
        if (_offlineDevices.contains(deviceId)) {
          _offlineDevices.remove(deviceId);
          await _notificationService.createNotification(
            severity: NotificationSeverity.info,
            category: NotificationCategory.device,
            title: 'Device Back Online',
            message: 'Device $deviceId is now online and reporting data.',
            data: {'deviceId': deviceId},
          );
        }
      }
    } catch (e) {
      print('[DeviceMonitor] Error checking device $deviceId online status: $e');
    }
  }

  /// Check sensor health status
  Future<void> _checkSensorHealth(
      String deviceId, Map<dynamic, dynamic> deviceData) async {
    try {
      final sensorHealth = deviceData['sensorHealth'] as Map<dynamic, dynamic>?;
      if (sensorHealth == null) return;

      final failedSensorsForDevice = _failedSensors[deviceId] ?? {};

      for (var entry in sensorHealth.entries) {
        final sensorName = entry.key as String;
        final sensorStatus = entry.value as String?;

        if (sensorStatus == 'error' || sensorStatus == 'fail') {
          // Only notify once per sensor failure
          if (!failedSensorsForDevice.contains(sensorName)) {
            failedSensorsForDevice.add(sensorName);
            _failedSensors[deviceId] = failedSensorsForDevice;

            await _notificationService.createNotification(
              severity: NotificationSeverity.critical,
              category: NotificationCategory.device,
              title: 'Sensor Failure',
              message:
                  '$sensorName sensor on device $deviceId is not responding. Check wiring and connections.',
              data: {
                'deviceId': deviceId,
                'sensorName': sensorName,
                'status': sensorStatus,
              },
            );
          }
        } else if (sensorStatus == 'ok') {
          // Sensor recovered
          if (failedSensorsForDevice.contains(sensorName)) {
            failedSensorsForDevice.remove(sensorName);
            await _notificationService.createNotification(
              severity: NotificationSeverity.info,
              category: NotificationCategory.device,
              title: 'Sensor Recovered',
              message: '$sensorName sensor on device $deviceId is now working normally.',
              data: {
                'deviceId': deviceId,
                'sensorName': sensorName,
              },
            );
          }
        }
      }
    } catch (e) {
      print('[DeviceMonitor] Error checking sensor health for $deviceId: $e');
    }
  }

  /// Check for critical water level
  Future<void> _checkWaterLevel(String deviceId, double waterLevel) async {
    if (waterLevel < 10) {
      // Only notify if this is a new critical alert or was previously at warning/normal
      if (_lastWaterAlert[deviceId] != 'critical') {
        _lastWaterAlert[deviceId] = 'critical';
        await _notificationService.createNotification(
          severity: NotificationSeverity.critical,
          category: NotificationCategory.irrigation,
          title: 'Water Level Critical',
          message:
              'Water tank is at ${waterLevel.toStringAsFixed(1)}%. Refill immediately to prevent pump damage.',
          data: {
            'deviceId': deviceId,
            'waterLevel': waterLevel,
          },
        );
      }
    } else if (waterLevel < 30) {
      // Only notify if this is a new warning alert or was previously normal
      if (_lastWaterAlert[deviceId] != 'warning' && _lastWaterAlert[deviceId] != 'critical') {
        _lastWaterAlert[deviceId] = 'warning';
        await _notificationService.createNotification(
          severity: NotificationSeverity.warning,
          category: NotificationCategory.irrigation,
          title: 'Water Level Low',
          message:
              'Water tank is at ${waterLevel.toStringAsFixed(1)}%. Consider refilling soon.',
          data: {
            'deviceId': deviceId,
            'waterLevel': waterLevel,
          },
        );
      }
    } else {
      // Water level is normal (>= 30%)
      if (_lastWaterAlert[deviceId] != null) {
        // Water level recovered - notify user
        _lastWaterAlert.remove(deviceId);
        await _notificationService.createNotification(
          severity: NotificationSeverity.info,
          category: NotificationCategory.irrigation,
          title: 'Water Level Normal',
          message:
              'Water tank level is now at ${waterLevel.toStringAsFixed(1)}%. Tank has been refilled.',
          data: {
            'deviceId': deviceId,
            'waterLevel': waterLevel,
          },
        );
      }
    }
  }

  /// Check for critical pH levels
  Future<void> _checkpHLevel(String deviceId, double pH) async {
    if (pH < 5.5 || pH > 8.0) {
      // Only notify once per pH critical event
      if (_lastpHAlert[deviceId] != 'critical') {
        _lastpHAlert[deviceId] = 'critical';
        await _notificationService.createNotification(
          severity: NotificationSeverity.critical,
          category: NotificationCategory.crop,
          title: 'pH Level Critical',
          message:
              'Soil pH is ${pH.toStringAsFixed(1)} - outside safe range (5.5-8.0). Adjust immediately to prevent crop damage.',
          data: {
            'deviceId': deviceId,
            'pH': pH,
          },
        );
      }
    } else {
      // pH is back to normal
      if (_lastpHAlert[deviceId] == 'critical') {
        _lastpHAlert.remove(deviceId);
        await _notificationService.createNotification(
          severity: NotificationSeverity.info,
          category: NotificationCategory.crop,
          title: 'pH Level Normal',
          message:
              'Soil pH is now ${pH.toStringAsFixed(1)} - back to safe range.',
          data: {
            'deviceId': deviceId,
            'pH': pH,
          },
        );
      }
    }
  }

  /// Check for critical temperature levels
  Future<void> _checkTemperature(String deviceId, double temperature) async {
    print('[DeviceMonitor] Checking temperature: $temperature°C (Last alert: ${_lastTempAlert[deviceId]})');

    if (temperature > 35) {
      // Extreme heat - critical
      if (_lastTempAlert[deviceId] != 'hot_critical') {
        print('[DeviceMonitor] ✅ Sending CRITICAL heat alert for $deviceId');
        _lastTempAlert[deviceId] = 'hot_critical';
        await _notificationService.createNotification(
          severity: NotificationSeverity.critical,
          category: NotificationCategory.crop,
          title: 'Extreme Heat Alert',
          message:
              'Temperature is ${temperature.toStringAsFixed(1)}°C! Crops at risk. Provide shade and increase watering immediately.',
          data: {
            'deviceId': deviceId,
            'temperature': temperature,
          },
        );
      } else {
        print('[DeviceMonitor] ⏭️ Skipping duplicate CRITICAL heat alert');
      }
    } else if (temperature > 30) {
      // High temperature - warning
      if (_lastTempAlert[deviceId] != 'hot_warning' && _lastTempAlert[deviceId] != 'hot_critical') {
        print('[DeviceMonitor] ✅ Sending WARNING heat alert for $deviceId');
        _lastTempAlert[deviceId] = 'hot_warning';
        await _notificationService.createNotification(
          severity: NotificationSeverity.warning,
          category: NotificationCategory.crop,
          title: 'High Temperature Warning',
          message:
              'Temperature is ${temperature.toStringAsFixed(1)}°C. Monitor crops closely and ensure adequate watering.',
          data: {
            'deviceId': deviceId,
            'temperature': temperature,
          },
        );
      } else {
        print('[DeviceMonitor] ⏭️ Skipping duplicate WARNING heat alert (last: ${_lastTempAlert[deviceId]})');
      }
    } else if (temperature < 5) {
      // Freezing risk - critical
      if (_lastTempAlert[deviceId] != 'cold_critical') {
        _lastTempAlert[deviceId] = 'cold_critical';
        await _notificationService.createNotification(
          severity: NotificationSeverity.critical,
          category: NotificationCategory.crop,
          title: 'Frost Risk Alert',
          message:
              'Temperature is ${temperature.toStringAsFixed(1)}°C! Risk of frost damage. Protect sensitive crops immediately.',
          data: {
            'deviceId': deviceId,
            'temperature': temperature,
          },
        );
      }
    } else if (temperature < 10) {
      // Cold temperature - warning
      if (_lastTempAlert[deviceId] != 'cold_warning' && _lastTempAlert[deviceId] != 'cold_critical') {
        _lastTempAlert[deviceId] = 'cold_warning';
        await _notificationService.createNotification(
          severity: NotificationSeverity.warning,
          category: NotificationCategory.crop,
          title: 'Low Temperature Warning',
          message:
              'Temperature is ${temperature.toStringAsFixed(1)}°C. Cold stress may affect crop growth.',
          data: {
            'deviceId': deviceId,
            'temperature': temperature,
          },
        );
      }
    } else {
      // Temperature is normal (10-30°C)
      if (_lastTempAlert[deviceId] != null) {
        _lastTempAlert.remove(deviceId);
        await _notificationService.createNotification(
          severity: NotificationSeverity.info,
          category: NotificationCategory.crop,
          title: 'Temperature Normal',
          message:
              'Temperature is now ${temperature.toStringAsFixed(1)}°C - back to optimal range.',
          data: {
            'deviceId': deviceId,
            'temperature': temperature,
          },
        );
      }
    }
  }

  /// Check for critical soil moisture levels
  Future<void> _checkSoilMoisture(String deviceId, double soilMoisture) async {
    if (soilMoisture < 20) {
      // Critically dry - critical
      if (_lastSoilAlert[deviceId] != 'critical') {
        _lastSoilAlert[deviceId] = 'critical';
        await _notificationService.createNotification(
          severity: NotificationSeverity.critical,
          category: NotificationCategory.crop,
          title: 'Soil Critically Dry',
          message:
              'Soil moisture is ${soilMoisture.toStringAsFixed(1)}%. Crops are stressed. Irrigate immediately to prevent wilting.',
          data: {
            'deviceId': deviceId,
            'soilMoisture': soilMoisture,
          },
        );
      }
    } else if (soilMoisture < 40) {
      // Low moisture - warning
      if (_lastSoilAlert[deviceId] != 'warning' && _lastSoilAlert[deviceId] != 'critical') {
        _lastSoilAlert[deviceId] = 'warning';
        await _notificationService.createNotification(
          severity: NotificationSeverity.warning,
          category: NotificationCategory.crop,
          title: 'Low Soil Moisture',
          message:
              'Soil moisture is ${soilMoisture.toStringAsFixed(1)}%. Consider watering soon to maintain optimal growth.',
          data: {
            'deviceId': deviceId,
            'soilMoisture': soilMoisture,
          },
        );
      }
    } else if (soilMoisture > 80) {
      // Over-saturated - warning
      if (_lastSoilAlert[deviceId] != 'saturated') {
        _lastSoilAlert[deviceId] = 'saturated';
        await _notificationService.createNotification(
          severity: NotificationSeverity.warning,
          category: NotificationCategory.crop,
          title: 'Soil Over-Saturated',
          message:
              'Soil moisture is ${soilMoisture.toStringAsFixed(1)}%. Risk of root rot. Stop irrigation and ensure proper drainage.',
          data: {
            'deviceId': deviceId,
            'soilMoisture': soilMoisture,
          },
        );
      }
    } else {
      // Soil moisture is normal (40-80%)
      if (_lastSoilAlert[deviceId] != null) {
        _lastSoilAlert.remove(deviceId);
        await _notificationService.createNotification(
          severity: NotificationSeverity.info,
          category: NotificationCategory.crop,
          title: 'Soil Moisture Optimal',
          message:
              'Soil moisture is now ${soilMoisture.toStringAsFixed(1)}% - optimal for healthy growth.',
          data: {
            'deviceId': deviceId,
            'soilMoisture': soilMoisture,
          },
        );
      }
    }
  }
}
