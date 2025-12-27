import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../notification_service.dart';
import '../models/notification_model.dart';

/// Irrigation Monitor Service
/// Monitors irrigation events (auto and manual pump control)
class IrrigationMonitorService {
  static final IrrigationMonitorService _instance = IrrigationMonitorService._internal();
  factory IrrigationMonitorService() => _instance;
  IrrigationMonitorService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _rtdb = FirebaseDatabase.instance;
  final NotificationService _notificationService = NotificationService();

  final Map<String, StreamSubscription> _listeners = {};
  final Map<String, bool> _lastPumpState = {}; // Track pump state to detect changes
  final Map<String, String> _lastMode = {}; // Track mode changes

  /// Start monitoring irrigation for a device
  void startMonitoring(String deviceId) {
    // Stop existing listener if any
    stopMonitoring(deviceId);

    // Listen to commands path for the device
    final commandsRef = _rtdb.ref('commands/$deviceId');
    final listener = commandsRef.onValue.listen((event) {
      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        _handleCommandChange(deviceId, data);
      }
    });

    _listeners[deviceId] = listener;
  }

  /// Stop monitoring a specific device
  void stopMonitoring(String deviceId) {
    _listeners[deviceId]?.cancel();
    _listeners.remove(deviceId);
    _lastPumpState.remove(deviceId);
    _lastMode.remove(deviceId);
  }

  /// Stop all monitoring
  void stopAllMonitoring() {
    for (var listener in _listeners.values) {
      listener.cancel();
    }
    _listeners.clear();
    _lastPumpState.clear();
    _lastMode.clear();
  }

  /// Handle command changes from RTDB
  Future<void> _handleCommandChange(
      String deviceId, Map<dynamic, dynamic> data) async {
    try {
      final pumpOn = data['pumpOn'] as bool?;
      final mode = data['mode'] as String?;

      // Detect pump state changes
      if (pumpOn != null) {
        final lastState = _lastPumpState[deviceId];
        if (lastState != pumpOn) {
          _lastPumpState[deviceId] = pumpOn;

          // Don't notify on first state detection (app startup)
          if (lastState != null) {
            await _notifyPumpStateChange(deviceId, pumpOn, mode ?? 'manual');
          }
        }
      }

      // Detect mode changes
      if (mode != null) {
        final lastModeValue = _lastMode[deviceId];
        if (lastModeValue != mode) {
          _lastMode[deviceId] = mode;

          // Notify mode change (but not on first detection)
          if (lastModeValue != null) {
            await _notifyModeChange(deviceId, mode);
          }
        }
      }
    } catch (e) {
      // Error handling - use logger in production
    }
  }

  /// Notify pump state change
  Future<void> _notifyPumpStateChange(
      String deviceId, bool pumpOn, String mode) async {
    if (pumpOn) {
      // Pump turned ON
      if (mode == 'auto') {
        await _notificationService.createNotification(
          severity: NotificationSeverity.info,
          category: NotificationCategory.irrigation,
          title: 'Auto Irrigation Started',
          message:
              'Automatic irrigation has started on device $deviceId based on soil moisture levels.',
          data: {
            'deviceId': deviceId,
            'pumpOn': true,
            'mode': mode,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          },
        );
      } else {
        await _notificationService.createNotification(
          severity: NotificationSeverity.info,
          category: NotificationCategory.irrigation,
          title: 'Manual Pump Started',
          message: 'Pump on device $deviceId has been turned ON manually.',
          data: {
            'deviceId': deviceId,
            'pumpOn': true,
            'mode': mode,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          },
        );
      }
    } else {
      // Pump turned OFF
      if (mode == 'auto') {
        await _notificationService.createNotification(
          severity: NotificationSeverity.info,
          category: NotificationCategory.irrigation,
          title: 'Auto Irrigation Stopped',
          message:
              'Automatic irrigation has completed on device $deviceId. Soil moisture target reached.',
          data: {
            'deviceId': deviceId,
            'pumpOn': false,
            'mode': mode,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          },
        );
      } else {
        await _notificationService.createNotification(
          severity: NotificationSeverity.info,
          category: NotificationCategory.irrigation,
          title: 'Manual Pump Stopped',
          message: 'Pump on device $deviceId has been turned OFF manually.',
          data: {
            'deviceId': deviceId,
            'pumpOn': false,
            'mode': mode,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          },
        );
      }
    }
  }

  /// Notify mode change
  Future<void> _notifyModeChange(String deviceId, String newMode) async {
    String modeDisplay = newMode == 'auto' ? 'Automatic' : 'Manual';

    await _notificationService.createNotification(
      severity: NotificationSeverity.info,
      category: NotificationCategory.system,
      title: 'Irrigation Mode Changed',
      message: 'Device $deviceId is now in $modeDisplay mode.',
      data: {
        'deviceId': deviceId,
        'mode': newMode,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  /// Manual notification for irrigation rule execution
  Future<void> notifyIrrigationRuleExecuted({
    required String deviceId,
    required String ruleName,
    required Map<String, dynamic> ruleData,
  }) async {
    await _notificationService.createNotification(
      severity: NotificationSeverity.info,
      category: NotificationCategory.irrigation,
      title: 'Irrigation Rule Executed',
      message:
          'Irrigation rule "$ruleName" has been triggered on device $deviceId.',
      data: {
        'deviceId': deviceId,
        'ruleName': ruleName,
        'ruleData': ruleData,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }
}
