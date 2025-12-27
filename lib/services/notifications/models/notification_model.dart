import 'package:cloud_firestore/cloud_firestore.dart';

/// Notification severity levels
enum NotificationSeverity {
  critical, // RED - Device offline, sensor failure, water critical
  warning,  // ORANGE/YELLOW - Low water, weather warnings
  info,     // BLUE/GREEN - System updates, recommendations
}

/// Notification categories
enum NotificationCategory {
  device,     // Device offline, sensor failure
  irrigation, // Auto/manual irrigation events
  weather,    // Weather alerts from OpenWeather API
  crop,       // AI recommendations, crop status
  system,     // Profile updates, device claims
}

/// Notification Model
class NotificationModel {
  final String id;
  final String userId;
  final NotificationSeverity severity;
  final NotificationCategory category;
  final String title;
  final String message;
  final DateTime timestamp;
  final bool isRead;
  final bool actionTaken;
  final Map<String, dynamic>? data; // Additional context

  NotificationModel({
    required this.id,
    required this.userId,
    required this.severity,
    required this.category,
    required this.title,
    required this.message,
    required this.timestamp,
    this.isRead = false,
    this.actionTaken = false,
    this.data,
  });

  /// Convert from Firestore document
  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      severity: NotificationSeverity.values.firstWhere(
        (e) => e.name == data['severity'],
        orElse: () => NotificationSeverity.info,
      ),
      category: NotificationCategory.values.firstWhere(
        (e) => e.name == data['category'],
        orElse: () => NotificationCategory.system,
      ),
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      isRead: data['isRead'] ?? false,
      actionTaken: data['actionTaken'] ?? false,
      data: data['data'] as Map<String, dynamic>?,
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'severity': severity.name,
      'category': category.name,
      'title': title,
      'message': message,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
      'actionTaken': actionTaken,
      if (data != null) 'data': data,
    };
  }

  /// Copy with method
  NotificationModel copyWith({
    String? id,
    String? userId,
    NotificationSeverity? severity,
    NotificationCategory? category,
    String? title,
    String? message,
    DateTime? timestamp,
    bool? isRead,
    bool? actionTaken,
    Map<String, dynamic>? data,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      severity: severity ?? this.severity,
      category: category ?? this.category,
      title: title ?? this.title,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      actionTaken: actionTaken ?? this.actionTaken,
      data: data ?? this.data,
    );
  }
}
