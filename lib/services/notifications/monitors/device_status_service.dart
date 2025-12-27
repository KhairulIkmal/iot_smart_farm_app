import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import '../notification_service.dart';
import '../models/notification_model.dart';

/// Device Status Service
/// Monitors device connection status and creates notifications
class DeviceStatusService {
  static final DeviceStatusService _instance = DeviceStatusService._internal();
  factory DeviceStatusService() => _instance;
  DeviceStatusService._internal();

  final NotificationService _notificationService = NotificationService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseDatabase _rtdb = FirebaseDatabase.instance;

  StreamSubscription? _deviceStatusListener;
  String? _currentDeviceId;
  bool? _lastKnownStatus; // null = unknown, true = online, false = offline

  /// Start monitoring device status
  void startMonitoring() async {
    stopMonitoring();

    // Get user's device
    final deviceId = await _getUserDeviceId();
    if (deviceId == null) return;

    _currentDeviceId = deviceId;

    // Listen to device lastSeen updates
    _deviceStatusListener = _rtdb
        .ref('sensors/$deviceId/live/lastSeen')
        .onValue
        .listen(_handleStatusChange);
  }

  /// Stop monitoring
  void stopMonitoring() {
    _deviceStatusListener?.cancel();
    _deviceStatusListener = null;
    _currentDeviceId = null;
    _lastKnownStatus = null;
  }

  /// Get user's device ID from Firestore
  Future<String?> _getUserDeviceId() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final crops = await _firestore
          .collection('crops')
          .where('farmer_id', isEqualTo: user.uid)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      if (crops.docs.isEmpty) return null;

      final cropData = crops.docs.first.data();
      return cropData['device_id'] as String?;
    } catch (e) {
      return null;
    }
  }

  /// Handle device status changes
  void _handleStatusChange(DatabaseEvent event) {
    if (event.snapshot.value == null) return;

    try {
      final lastSeen = event.snapshot.value as int;
      final lastSeenDate = DateTime.fromMillisecondsSinceEpoch(lastSeen);
      final isOnline = DateTime.now().difference(lastSeenDate).inMinutes < 5;

      // Check if status changed
      if (_lastKnownStatus != null && _lastKnownStatus != isOnline) {
        _createStatusNotification(isOnline);
      }

      _lastKnownStatus = isOnline;
    } catch (e) {
      // Error parsing timestamp
    }
  }

  /// Create notification for status change
  Future<void> _createStatusNotification(bool isOnline) async {
    if (_currentDeviceId == null) return;

    if (isOnline) {
      // Device came online
      await _notificationService.createNotification(
        severity: NotificationSeverity.info,
        category: NotificationCategory.system,
        title: 'Device Connected',
        message:
            'Your IoT device ($_currentDeviceId) is now online and ready. All systems are operational.',
        data: {
          'deviceId': _currentDeviceId!,
          'status': 'online',
          'type': 'device_status',
        },
      );
    } else {
      // Device went offline
      await _notificationService.createNotification(
        severity: NotificationSeverity.warning,
        category: NotificationCategory.system,
        title: 'Device Disconnected',
        message:
            'Your IoT device ($_currentDeviceId) has gone offline. Check your device connection and power supply.',
        data: {
          'deviceId': _currentDeviceId!,
          'status': 'offline',
          'type': 'device_status',
        },
      );
    }
  }
}
