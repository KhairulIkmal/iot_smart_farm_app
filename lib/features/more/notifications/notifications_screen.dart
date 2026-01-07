import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../services/notifications/notification_service.dart';
import '../../../services/notifications/models/notification_model.dart';

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
  final NotificationService _notificationService = NotificationService();
  final PageController _pageController = PageController();
  final ScrollController _tabScrollController = ScrollController();
  final ValueNotifier<int> _selectedFilterIndex = ValueNotifier<int>(0);
  final List<String> _filters = ['All', 'Critical', 'Devices', 'Water', 'Crops', 'Weather', 'System', 'Archived'];
  final List<GlobalKey> _tabKeys = List.generate(8, (index) => GlobalKey());

  @override
  void dispose() {
    _pageController.dispose();
    _tabScrollController.dispose();
    _selectedFilterIndex.dispose();
    super.dispose();
  }

  void _scrollToSelectedTab(int index) {
    if (!_tabScrollController.hasClients) return;

    // Get the RenderBox of the selected tab
    final tabKey = _tabKeys[index];
    final context = tabKey.currentContext;
    if (context == null) return;

    final RenderBox tabBox = context.findRenderObject() as RenderBox;
    final tabPosition = tabBox.localToGlobal(Offset.zero);
    final tabWidth = tabBox.size.width;

    // Calculate scroll position to center the selected tab
    final screenWidth = MediaQuery.of(this.context).size.width;
    final scrollOffset = _tabScrollController.offset;
    final targetOffset = scrollOffset + tabPosition.dx - (screenWidth / 2) + (tabWidth / 2);

    // Animate to the calculated position
    _tabScrollController.animateTo(
      targetOffset.clamp(0.0, _tabScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final notificationsStream = _notificationService.getNotificationsStream();

    if (notificationsStream == null) {
      return Scaffold(
        backgroundColor: AppColors.backgroundDark,
        body: SafeArea(
          child: Center(
            child: Text(
              'Please sign in to view notifications',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: StreamBuilder<List<NotificationModel>>(
          stream: notificationsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error loading notifications',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
              );
            }

            final notifications = snapshot.data ?? [];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                _buildHeader(),
                const SizedBox(height: 16),

                // Filter Tabs (using ValueListenableBuilder for efficiency)
                ValueListenableBuilder<int>(
                  valueListenable: _selectedFilterIndex,
                  builder: (context, selectedIndex, _) {
                    return _buildStaticFilterTabs(notifications, selectedIndex);
                  },
                ),
                const SizedBox(height: 20),

                // PageView with swipe navigation
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _filters.length,
                    onPageChanged: (index) {
                      _selectedFilterIndex.value = index;
                      // Auto-scroll to show the selected tab
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _scrollToSelectedTab(index);
                      });
                    },
                    itemBuilder: (context, pageIndex) {
                      return _buildNotificationsListContent(
                        notifications,
                        _filters[pageIndex],
                      );
                    },
                  ),
                ),
              ],
            );
          },
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
  Widget _buildStaticFilterTabs(List<NotificationModel> notifications, int selectedIndex) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        controller: _tabScrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isSelected = selectedIndex == index;
          final count = _getCountForFilter(filter, notifications);

          return GestureDetector(
            key: _tabKeys[index],
            onTap: () {
              _selectedFilterIndex.value = index;
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
              _scrollToSelectedTab(index);
            },
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
                  if (_getFilterIcon(filter) != null) ...[
                    Icon(
                      _getFilterIcon(filter),
                      size: 16,
                      color: isSelected
                          ? Colors.white
                          : Colors.white.withOpacity(0.7),
                    ),
                    const SizedBox(width: 6),
                  ],
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
                        style: const TextStyle(
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

  int _getCountForFilter(String filter, List<NotificationModel> notifications) {
    switch (filter) {
      case 'Critical':
        return notifications
            .where((n) =>
                n.severity == NotificationSeverity.critical && !n.isRead)
            .length;
      case 'Devices':
        return notifications
            .where((n) => n.category == NotificationCategory.device && !n.isRead)
            .length;
      case 'Water':
        return notifications
            .where(
                (n) => n.category == NotificationCategory.irrigation && !n.isRead)
            .length;
      case 'Crops':
        return notifications
            .where((n) => n.category == NotificationCategory.crop && !n.isRead)
            .length;
      case 'Weather':
        return notifications
            .where((n) => n.category == NotificationCategory.weather && !n.isRead)
            .length;
      case 'System':
        return notifications
            .where((n) => n.category == NotificationCategory.system && !n.isRead)
            .length;
      default:
        return 0;
    }
  }

  IconData? _getFilterIcon(String filter) {
    switch (filter) {
      case 'Critical':
        return Icons.error_outline;
      case 'Devices':
        return Icons.sensors;
      case 'Water':
        return Icons.water_drop;
      case 'Crops':
        return Icons.eco;
      case 'Weather':
        return Icons.wb_sunny;
      case 'System':
        return Icons.notifications_active;
      case 'Archived':
        return Icons.archive_outlined;
      default:
        return null; // 'All' has no icon
    }
  }

  /// ------------------------------------------------
  /// NOTIFICATIONS LIST CONTENT
  /// ------------------------------------------------
  Widget _buildNotificationsListContent(
    List<NotificationModel> notifications,
    String filter,
  ) {
    final filtered = _getFilteredNotifications(notifications, filter);
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

  List<NotificationModel> _getFilteredNotifications(
    List<NotificationModel> notifications,
    String filter,
  ) {
    switch (filter) {
      case 'Critical':
        return notifications
            .where((n) => n.severity == NotificationSeverity.critical)
            .toList();
      case 'Devices':
        return notifications
            .where((n) => n.category == NotificationCategory.device)
            .toList();
      case 'Water':
        return notifications
            .where((n) => n.category == NotificationCategory.irrigation)
            .toList();
      case 'Crops':
        return notifications
            .where((n) => n.category == NotificationCategory.crop)
            .toList();
      case 'Weather':
        return notifications
            .where((n) => n.category == NotificationCategory.weather)
            .toList();
      case 'System':
        return notifications
            .where((n) => n.category == NotificationCategory.system)
            .toList();
      case 'Archived':
        return notifications.where((n) => n.isRead).toList();
      default:
        return notifications;
    }
  }

  Map<String, List<NotificationModel>> _groupByDate(
    List<NotificationModel> items,
  ) {
    final Map<String, List<NotificationModel>> grouped = {};

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

  Widget _buildNotificationCard(NotificationModel notification) {
    return GestureDetector(
      onTap: () async {
        if (!notification.isRead) {
          await _notificationService.markAsRead(notification.id);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: notification.isRead
                ? AppColors.borderDark
                : _getSeverityColor(notification.severity).withOpacity(0.3),
          ),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Left color indicator
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: _getSeverityColor(notification.severity),
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
                              color: _getSeverityColor(
                                notification.severity,
                              ).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _getCategoryIcon(notification.category),
                              color: _getSeverityColor(notification.severity),
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
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getSeverityColor(NotificationSeverity severity) {
    switch (severity) {
      case NotificationSeverity.critical:
        return AppColors.error;
      case NotificationSeverity.warning:
        return AppColors.warning;
      case NotificationSeverity.info:
        return AppColors.primary;
    }
  }

  IconData _getCategoryIcon(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.device:
        return Icons.sensors;
      case NotificationCategory.irrigation:
        return Icons.water_drop;
      case NotificationCategory.weather:
        return Icons.wb_sunny;
      case NotificationCategory.crop:
        return Icons.eco;
      case NotificationCategory.system:
        return Icons.settings;
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

  void _markAllAsRead() async {
    await _notificationService.markAllAsRead();
    if (mounted) {
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }
}
