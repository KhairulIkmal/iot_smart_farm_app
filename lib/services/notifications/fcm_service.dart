import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'models/notification_model.dart';

/// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Handle background messages
  print('Handling background message: ${message.messageId}');
}

/// FCM Service
/// Handles Firebase Cloud Messaging for push notifications
class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isInitialized = false;

  /// Initialize FCM and local notifications
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Request notification permissions
      await _requestPermissions();

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Setup FCM handlers
      _setupFCMHandlers();

      // Get and save FCM token
      await _saveFCMToken();

      _isInitialized = true;
      print('FCM Service initialized successfully');
    } catch (e) {
      print('Error initializing FCM: $e');
    }
  }

  /// Request notification permissions
  Future<void> _requestPermissions() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    print('Notification permission status: ${settings.authorizationStatus}');
  }

  /// Initialize local notifications plugin
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleNotificationTap,
    );

    // Create notification channels for Android
    await _createNotificationChannels();
  }

  /// Create Android notification channels
  Future<void> _createNotificationChannels() async {
    const channels = [
      AndroidNotificationChannel(
        'critical_alerts',
        'Critical Alerts',
        description: 'Critical system and farm alerts',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ),
      AndroidNotificationChannel(
        'warnings',
        'Warnings',
        description: 'Important warnings and alerts',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
      AndroidNotificationChannel(
        'info',
        'Information',
        description: 'General information and updates',
        importance: Importance.defaultImportance,
        playSound: true,
      ),
      AndroidNotificationChannel(
        'success',
        'Success',
        description: 'Success notifications',
        importance: Importance.defaultImportance,
        playSound: true,
      ),
    ];

    for (final channel in channels) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  /// Setup FCM message handlers
  void _setupFCMHandlers() {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle background message taps
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Handle notification taps when app is terminated
    _handleInitialMessage();
  }

  /// Handle foreground messages
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('Foreground message received: ${message.messageId}');

    // Show local notification
    await _showLocalNotification(message);
  }

  /// Handle message opened from background
  void _handleMessageOpenedApp(RemoteMessage message) {
    print('Message opened from background: ${message.messageId}');
    // TODO: Navigate to appropriate screen based on notification data
  }

  /// Handle initial message when app opens from terminated state
  Future<void> _handleInitialMessage() async {
    final message = await _messaging.getInitialMessage();
    if (message != null) {
      print('App opened from terminated state via notification: ${message.messageId}');
      // TODO: Navigate to appropriate screen based on notification data
    }
  }

  /// Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;

    if (notification == null) return;

    // Determine channel and priority based on severity
    final severity = data['severity'] as String? ?? 'info';
    final channelId = _getChannelId(severity);
    final importance = _getImportance(severity);
    final priority = _getPriority(severity);

    final androidDetails = AndroidNotificationDetails(
      channelId,
      _getChannelName(channelId),
      channelDescription: _getChannelDescription(channelId),
      importance: importance,
      priority: priority,
      playSound: true,
      enableVibration: severity == 'critical' || severity == 'warning',
      styleInformation: notification.body != null
          ? BigTextStyleInformation(notification.body!)
          : null,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      notification.title,
      notification.body,
      details,
      payload: message.data.toString(),
    );
  }

  /// Handle notification tap
  void _handleNotificationTap(NotificationResponse response) {
    print('Notification tapped: ${response.payload}');
    // TODO: Navigate to appropriate screen based on payload
  }

  /// Get FCM token and save to Firestore
  Future<void> _saveFCMToken() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final token = await _messaging.getToken();
      if (token == null) return;

      print('FCM Token: $token');

      // Save token to Firestore
      await _firestore.collection('users').doc(user.uid).update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });

      // Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) async {
        await _firestore.collection('users').doc(user.uid).update({
          'fcmToken': newToken,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      print('Error saving FCM token: $e');
    }
  }

  /// Send local notification (for in-app notifications)
  Future<void> sendLocalNotification({
    required String title,
    required String message,
    required NotificationSeverity severity,
    required NotificationCategory category,
    Map<String, dynamic>? data,
  }) async {
    final channelId = _getChannelId(severity.toString().split('.').last);
    final importance = _getImportance(severity.toString().split('.').last);
    final priority = _getPriority(severity.toString().split('.').last);

    final androidDetails = AndroidNotificationDetails(
      channelId,
      _getChannelName(channelId),
      channelDescription: _getChannelDescription(channelId),
      importance: importance,
      priority: priority,
      playSound: true,
      enableVibration: severity == NotificationSeverity.critical ||
          severity == NotificationSeverity.warning,
      styleInformation: BigTextStyleInformation(message),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      message,
      details,
      payload: data?.toString(),
    );
  }

  /// Get channel ID based on severity
  String _getChannelId(String severity) {
    switch (severity) {
      case 'critical':
        return 'critical_alerts';
      case 'warning':
        return 'warnings';
      case 'success':
        return 'success';
      case 'info':
      default:
        return 'info';
    }
  }

  /// Get channel name
  String _getChannelName(String channelId) {
    switch (channelId) {
      case 'critical_alerts':
        return 'Critical Alerts';
      case 'warnings':
        return 'Warnings';
      case 'success':
        return 'Success';
      case 'info':
      default:
        return 'Information';
    }
  }

  /// Get channel description
  String _getChannelDescription(String channelId) {
    switch (channelId) {
      case 'critical_alerts':
        return 'Critical system and farm alerts';
      case 'warnings':
        return 'Important warnings and alerts';
      case 'success':
        return 'Success notifications';
      case 'info':
      default:
        return 'General information and updates';
    }
  }

  /// Get Android importance level
  Importance _getImportance(String severity) {
    switch (severity) {
      case 'critical':
        return Importance.max;
      case 'warning':
        return Importance.high;
      case 'info':
      case 'success':
      default:
        return Importance.defaultImportance;
    }
  }

  /// Get Android priority level
  Priority _getPriority(String severity) {
    switch (severity) {
      case 'critical':
        return Priority.max;
      case 'warning':
        return Priority.high;
      case 'info':
      case 'success':
      default:
        return Priority.defaultPriority;
    }
  }

  /// Cleanup
  void dispose() {
    _isInitialized = false;
  }
}
