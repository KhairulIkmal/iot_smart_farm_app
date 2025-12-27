import 'package:firebase_auth/firebase_auth.dart';
import 'monitors/device_monitor_service.dart';
import 'monitors/irrigation_monitor_service.dart';
import 'monitors/weather_alert_service.dart';
import 'monitors/device_status_service.dart';

/// Monitoring Manager
/// Coordinates all monitoring services and manages their lifecycle
class MonitoringManager {
  static final MonitoringManager _instance = MonitoringManager._internal();
  factory MonitoringManager() => _instance;
  MonitoringManager._internal();

  final DeviceMonitorService _deviceMonitor = DeviceMonitorService();
  final IrrigationMonitorService _irrigationMonitor = IrrigationMonitorService();
  final WeatherAlertService _weatherAlert = WeatherAlertService();
  final DeviceStatusService _deviceStatus = DeviceStatusService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isMonitoring = false;

  /// Initialize monitoring when user logs in
  void startMonitoring() {
    if (_isMonitoring) return;

    final user = _auth.currentUser;
    if (user == null) return;

    _isMonitoring = true;

    // Start device offline detection and sensor health monitoring
    _deviceMonitor.startMonitoring();

    // Start device online/offline status notifications
    _deviceStatus.startMonitoring();

    // Start weather alerts
    _weatherAlert.startMonitoring();

    // Note: Irrigation monitoring is started per device
    // This should be called when user selects/claims a device
  }

  /// Start irrigation monitoring for a specific device
  void startIrrigationMonitoring(String deviceId) {
    _irrigationMonitor.startMonitoring(deviceId);
  }

  /// Stop irrigation monitoring for a specific device
  void stopIrrigationMonitoring(String deviceId) {
    _irrigationMonitor.stopMonitoring(deviceId);
  }

  /// Stop all monitoring when user logs out
  void stopMonitoring() {
    if (!_isMonitoring) return;

    _deviceMonitor.stopMonitoring();
    _deviceStatus.stopMonitoring();
    _irrigationMonitor.stopAllMonitoring();
    _weatherAlert.stopMonitoring();

    _isMonitoring = false;
  }

  /// Check if monitoring is active
  bool get isMonitoring => _isMonitoring;
}
