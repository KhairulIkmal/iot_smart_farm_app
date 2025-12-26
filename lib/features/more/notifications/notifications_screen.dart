import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/theme.dart';

/// ------------------------------------------------------------
/// NOTIFICATIONS SCREEN
///
/// Shows:
/// - Filter Tabs (All, Critical, Warnings, Archived)
/// - Grouped notifications by date (Today, Yesterday)
/// - Different alert types with action buttons
/// ------------------------------------------------------------
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Critical', 'Warnings', 'Archived'];

  // Sample notifications data (in production, fetch from Firestore)
  final List<_NotificationItem> _notifications = [
    _NotificationItem(
      id: '1',
      type: NotificationType.critical,
      title: 'Water Level Critical',
      message:
          'Main tank is below 10%. Pump has been auto-stopped to prevent dry running.',
      timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
      actions: ['Refill Tank', 'Ignore'],
      isRead: false,
    ),
    _NotificationItem(
      id: '2',
      type: NotificationType.warning,
      title: 'Sensor Disconnected',
      message:
          'Greenhouse B - Humidity Sensor is not responding. Check power supply.',
      timestamp: DateTime.now().subtract(const Duration(hours: 1)),
      isRead: false,
    ),
    _NotificationItem(
      id: '3',
      type: NotificationType.warning,
      title: 'High Temp Warning',
      message:
          'Zone 3 temperature is 2°C above set threshold. Ventilation activated.',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      isRead: true,
    ),
    _NotificationItem(
      id: '4',
      type: NotificationType.success,
      title: 'Irrigation Complete',
      message:
          'Scheduled cycle for Sector 4 finished successfully. 450L water used.',
      timestamp: DateTime.now().subtract(const Duration(hours: 14)),
      isRead: true,
    ),
    _NotificationItem(
      id: '5',
      type: NotificationType.info,
      title: 'Firmware Update',
      message:
          'Main controller updated to v2.4.1. System rebooted successfully.',
      timestamp: DateTime.now().subtract(const Duration(hours: 18)),
      isRead: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _buildHeader(),
            const SizedBox(height: 16),

            // Filter Tabs
            _buildFilterTabs(),
            const SizedBox(height: 20),

            // Notifications List
            Expanded(child: _buildNotificationsList()),
          ],
        ),
      ),
    );
  }

  /// ------------------------------------------------
  /// HEADER
  /// ------------------------------------------------
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderDark),
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          const Expanded(
            child: Text(
              'Alerts',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          TextButton(
            onPressed: _markAllAsRead,
            child: Row(
              children: [
                Icon(Icons.done_all, color: AppColors.primary, size: 18),
                const SizedBox(width: 4),
                const Text(
                  'MARK ALL AS READ',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// ------------------------------------------------
  /// FILTER TABS
  /// ------------------------------------------------
  Widget _buildFilterTabs() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isSelected = _selectedFilter == filter;
          final count = _getCountForFilter(filter);

          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = filter),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.borderDark,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    filter,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : Colors.white.withOpacity(0.7),
                    ),
                  ),
                  if (count > 0 && filter == 'Critical') ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withOpacity(0.2)
                            : AppColors.error,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  int _getCountForFilter(String filter) {
    switch (filter) {
      case 'Critical':
        return _notifications
            .where((n) => n.type == NotificationType.critical && !n.isRead)
            .length;
      case 'Warnings':
        return _notifications
            .where((n) => n.type == NotificationType.warning && !n.isRead)
            .length;
      default:
        return 0;
    }
  }

  /// ------------------------------------------------
  /// NOTIFICATIONS LIST
  /// ------------------------------------------------
  Widget _buildNotificationsList() {
    final filtered = _getFilteredNotifications();
    final grouped = _groupByDate(filtered);

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_none,
              size: 64,
              color: Colors.white.withOpacity(0.2),
            ),
            const SizedBox(height: 16),
            Text(
              'No notifications',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final group = grouped.entries.elementAt(index);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Label
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                group.key.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.5),
                  letterSpacing: 0.5,
                ),
              ),
            ),
            // Notifications
            ...group.value.map((n) => _buildNotificationCard(n)),
          ],
        );
      },
    );
  }

  List<_NotificationItem> _getFilteredNotifications() {
    switch (_selectedFilter) {
      case 'Critical':
        return _notifications
            .where((n) => n.type == NotificationType.critical)
            .toList();
      case 'Warnings':
        return _notifications
            .where((n) => n.type == NotificationType.warning)
            .toList();
      case 'Archived':
        return _notifications.where((n) => n.isRead).toList();
      default:
        return _notifications;
    }
  }

  Map<String, List<_NotificationItem>> _groupByDate(
    List<_NotificationItem> items,
  ) {
    final Map<String, List<_NotificationItem>> grouped = {};

    for (final item in items) {
      final now = DateTime.now();
      final diff = now.difference(item.timestamp);

      String label;
      if (diff.inHours < 24) {
        label = 'Today';
      } else if (diff.inHours < 48) {
        label = 'Yesterday';
      } else {
        label =
            '${item.timestamp.day}/${item.timestamp.month}/${item.timestamp.year}';
      }

      if (!grouped.containsKey(label)) {
        grouped[label] = [];
      }
      grouped[label]!.add(item);
    }

    return grouped;
  }

  Widget _buildNotificationCard(_NotificationItem notification) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: notification.isRead
              ? AppColors.borderDark
              : _getTypeColor(notification.type).withOpacity(0.3),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Left color indicator
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: _getTypeColor(notification.type),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Row
                    Row(
                      children: [
                        // Icon
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _getTypeColor(
                              notification.type,
                            ).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _getTypeIcon(notification.type),
                            color: _getTypeColor(notification.type),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Title & Time
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                notification.title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          _formatTime(notification.timestamp),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Message
                    Text(
                      notification.message,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.7),
                        height: 1.4,
                      ),
                    ),
                    // Actions
                    if (notification.actions != null &&
                        notification.actions!.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Row(
                        children: notification.actions!.map((action) {
                          final isPrimary =
                              notification.actions!.indexOf(action) == 0;
                          return Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: isPrimary
                                ? ElevatedButton(
                                    onPressed: () =>
                                        _handleAction(notification, action),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _getTypeColor(
                                        notification.type,
                                      ),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: Text(
                                      action,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  )
                                : TextButton(
                                    onPressed: () =>
                                        _handleAction(notification, action),
                                    child: Text(
                                      action,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: _getTypeColor(notification.type),
                                      ),
                                    ),
                                  ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getTypeColor(NotificationType type) {
    switch (type) {
      case NotificationType.critical:
        return AppColors.error;
      case NotificationType.warning:
        return AppColors.warning;
      case NotificationType.success:
        return AppColors.primary;
      case NotificationType.info:
        return AppColors.info;
    }
  }

  IconData _getTypeIcon(NotificationType type) {
    switch (type) {
      case NotificationType.critical:
        return Icons.water_drop;
      case NotificationType.warning:
        return Icons.wifi_off;
      case NotificationType.success:
        return Icons.check_circle;
      case NotificationType.info:
        return Icons.system_update;
    }
  }

  String _formatTime(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }

  void _handleAction(_NotificationItem notification, String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Action: $action'),
        backgroundColor: AppColors.surfaceDark,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _markAllAsRead() {
    setState(() {
      for (final n in _notifications) {
        n.isRead = true;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Text('All notifications marked as read'),
          ],
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

/// Notification Type Enum
enum NotificationType { critical, warning, success, info }

/// Notification Item Model
class _NotificationItem {
  final String id;
  final NotificationType type;
  final String title;
  final String message;
  final DateTime timestamp;
  final List<String>? actions;
  bool isRead;

  _NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.timestamp,
    this.actions,
    this.isRead = false,
  });
}
