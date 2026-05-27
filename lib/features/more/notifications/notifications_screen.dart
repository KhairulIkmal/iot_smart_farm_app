import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/app_localizations.dart';
import '../../../core/theme.dart';
import '../../../services/notifications/notification_service.dart';
import '../../../services/notifications/models/notification_model.dart';

/// ------------------------------------------------------------
/// NOTIFICATIONS SCREEN
///
/// Tabs: All | Critical | Devices | Water | Crops | Weather | System | Archived
///
/// Main tabs  → non-archived notifications only
///              swipe LEFT on any card → archive it
/// Archive tab → archived notifications only
///              swipe RIGHT on any card → unarchive it
///
/// Header actions:
///   MARK ALL AS READ  — marks every unread notification as read
///   ARCHIVE ALL READ  — archives every read, non-archived notification
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

  final List<String> _filters = [
    'All',
    'Critical',
    'Devices',
    'Water',
    'Crops',
    'Weather',
    'System',
    'Archived',
  ];
  final List<GlobalKey> _tabKeys = List.generate(8, (_) => GlobalKey());

  // Main feed (non-archived) and archive feed — separate subscriptions
  List<NotificationModel> _notifications = [];
  List<NotificationModel> _archived = [];
  StreamSubscription<List<NotificationModel>>? _mainSub;
  StreamSubscription<List<NotificationModel>>? _archiveSub;

  @override
  void initState() {
    super.initState();

    final mainStream = _notificationService.getNotificationsStream();
    if (mainStream != null) {
      _mainSub = mainStream.listen((list) {
        if (mounted) setState(() => _notifications = list);
      });
    }

    final archiveStream = _notificationService.getArchivedNotificationsStream();
    if (archiveStream != null) {
      _archiveSub = archiveStream.listen((list) {
        if (mounted) setState(() => _archived = list);
      });
    }
  }

  @override
  void dispose() {
    _mainSub?.cancel();
    _archiveSub?.cancel();
    _pageController.dispose();
    _tabScrollController.dispose();
    _selectedFilterIndex.dispose();
    super.dispose();
  }

  void _scrollToSelectedTab(int index) {
    if (!_tabScrollController.hasClients) return;
    final tabKey = _tabKeys[index];
    final ctx = tabKey.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox;
    final pos = box.localToGlobal(Offset.zero);
    final screenWidth = MediaQuery.of(context).size.width;
    final target =
        _tabScrollController.offset +
        pos.dx -
        (screenWidth / 2) +
        (box.size.width / 2);
    _tabScrollController.animateTo(
      target.clamp(0.0, _tabScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeColors.bg(context),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            ValueListenableBuilder<int>(
              valueListenable: _selectedFilterIndex,
              builder: (context, selectedIndex, _) =>
                  _buildFilterTabs(selectedIndex),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _filters.length,
                onPageChanged: (index) {
                  _selectedFilterIndex.value = index;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _scrollToSelectedTab(index);
                  });
                },
                itemBuilder: (context, pageIndex) {
                  final filter = _filters[pageIndex];
                  if (filter == 'Archived') {
                    return _buildArchiveTab();
                  }
                  return _buildMainTab(filter);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------------
  // HEADER
  // ----------------------------------------------------------------
  Widget _buildHeader() {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: ThemeColors.surface(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ThemeColors.border(context)),
              ),
              child: Icon(
                Icons.arrow_back,
                color: ThemeColors.icon(context),
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.t('Notifications'),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: ThemeColors.textPrimary(context),
              ),
            ),
          ),
          // Mark all as read
          GestureDetector(
            onTap: _markAllAsRead,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.archive_outlined,
                    color: AppColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    l10n.t('Clear all'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------
  // FILTER TABS
  // ----------------------------------------------------------------
  Widget _buildFilterTabs(int selectedIndex) {
    final l10n = AppLocalizations.of(context);
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
          final count = _countForFilter(filter);

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
                color: isSelected ? AppColors.primary : ThemeColors.surface(context),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppColors.primary : ThemeColors.border(context),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_iconForFilter(filter) != null) ...[
                    Icon(
                      _iconForFilter(filter),
                      size: 16,
                      color: isSelected
                          ? Colors.white
                          : ThemeColors.textSecondary(context).withOpacity(0.7),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    l10n.t(filter),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : ThemeColors.textSecondary(context).withOpacity(0.7),
                    ),
                  ),
                  if (count > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: filter == 'Archived'
                            ? (isSelected
                                  ? Colors.white.withOpacity(0.25)
                                  : Colors.white.withOpacity(0.15))
                            : (isSelected
                                  ? Colors.white.withOpacity(0.25)
                                  : AppColors.error),
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

  // ----------------------------------------------------------------
  // MAIN TABS (non-archived)
  // ----------------------------------------------------------------
  Widget _buildMainTab(String filter) {
    final items = _filterNotifications(_notifications, filter);
    if (items.isEmpty) return _buildEmpty(filter);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _groupByDate(items).length,
      itemBuilder: (context, index) {
        final group = _groupByDate(items).entries.elementAt(index);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                group.key.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: ThemeColors.textSecondary(context).withOpacity(0.5),
                  letterSpacing: 0.5,
                ),
              ),
            ),
            ...group.value.map(
              (n) => _buildSwipeableCard(n, isArchived: false),
            ),
          ],
        );
      },
    );
  }

  // ----------------------------------------------------------------
  // ARCHIVE TAB
  // ----------------------------------------------------------------
  Widget _buildArchiveTab() {
    final l10n = AppLocalizations.of(context);
    if (_archived.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.archive_outlined,
              size: 64,
              color: ThemeColors.textSecondary(context).withOpacity(0.2),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.t('No archived notifications'),
              style: TextStyle(
                fontSize: 18,
                color: ThemeColors.textSecondary(context).withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.t('Swipe left on a notification to archive it'),
              style: TextStyle(
                fontSize: 13,
                color: ThemeColors.textSecondary(context).withOpacity(0.3),
              ),
            ),
          ],
        ),
      );
    }

    final grouped = _groupByDate(_archived);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final group = grouped.entries.elementAt(index);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                group.key.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: ThemeColors.textSecondary(context).withOpacity(0.5),
                  letterSpacing: 0.5,
                ),
              ),
            ),
            ...group.value.map((n) => _buildSwipeableCard(n, isArchived: true)),
          ],
        );
      },
    );
  }

  // ----------------------------------------------------------------
  // SWIPEABLE NOTIFICATION CARD
  // ----------------------------------------------------------------
  Widget _buildSwipeableCard(NotificationModel n, {required bool isArchived}) {
    final l10n = AppLocalizations.of(context);
    return Dismissible(
      key: ValueKey('${n.id}_${isArchived ? 'arch' : 'main'}'),
      direction: isArchived
          ? DismissDirection
                .startToEnd // swipe RIGHT → unarchive
          : DismissDirection.endToStart, // swipe LEFT  → archive
      confirmDismiss: (_) async {
        if (isArchived) {
          await _notificationService.unarchiveNotification(n.id);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              _snackBar(
                Icons.unarchive_outlined,
                l10n.t('Moved back to inbox'),
                AppColors.primary,
              ),
            );
          }
        } else {
          await _notificationService.archiveNotification(n.id);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              _snackBarWithUndo(
                l10n.t('Notification archived'),
                onUndo: () => _notificationService.unarchiveNotification(n.id),
                l10n: l10n,
              ),
            );
          }
        }
        return false; // Firestore stream handles removal — no need to dismiss locally
      },
      background: _buildSwipeBackground(isArchived, l10n),
      child: _buildNotificationCard(n, isArchived: isArchived, l10n: l10n),
    );
  }

  Widget _buildSwipeBackground(bool isArchived, AppLocalizations l10n) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isArchived
            ? AppColors.primary.withOpacity(0.15)
            : Colors.blueGrey.withOpacity(0.25),
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: isArchived ? Alignment.centerLeft : Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
            color: isArchived ? AppColors.primary : Colors.white70,
            size: 26,
          ),
          const SizedBox(height: 4),
          Text(
            isArchived ? l10n.t('Unarchive') : l10n.t('Archive'),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isArchived ? AppColors.primary : Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(
    NotificationModel n, {
    required bool isArchived,
    required AppLocalizations l10n,
  }) {
    return GestureDetector(
      onTap: () async {
        if (!n.isRead) {
          await _notificationService.markAsRead(n.id);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isArchived
              ? ThemeColors.surface(context).withOpacity(0.6)
              : ThemeColors.surface(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: n.isRead
                ? ThemeColors.border(context)
                : _severityColor(n.severity).withOpacity(0.3),
          ),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Left severity bar
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: isArchived
                      ? _severityColor(n.severity).withOpacity(0.4)
                      : _severityColor(n.severity),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _severityColor(
                                n.severity,
                              ).withOpacity(isArchived ? 0.08 : 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _categoryIcon(n.category),
                              color: isArchived
                                  ? _severityColor(n.severity).withOpacity(0.5)
                                  : _severityColor(n.severity),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              n.title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isArchived
                                    ? ThemeColors.textSecondary(context).withOpacity(0.5)
                                    : ThemeColors.textPrimary(context),
                              ),
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _formatTime(n.timestamp),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: ThemeColors.textSecondary(context).withOpacity(0.4),
                                ),
                              ),
                              if (isArchived) ...[
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: ThemeColors.textSecondary(context).withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    l10n.t('Archived'),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: ThemeColors.textSecondary(context).withOpacity(0.4),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        n.message,
                        style: TextStyle(
                          fontSize: 14,
                          color: ThemeColors.textSecondary(context).withOpacity(
                            isArchived ? 0.4 : 0.7,
                          ),
                          height: 1.4,
                        ),
                      ),
                      // Hint text for non-archived cards
                      if (!isArchived && n.isRead) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.swipe_left,
                              size: 14,
                              color: ThemeColors.textSecondary(context).withOpacity(0.2),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              l10n.t('Swipe left to archive'),
                              style: TextStyle(
                                fontSize: 11,
                                color: ThemeColors.textSecondary(context).withOpacity(0.2),
                              ),
                            ),
                          ],
                        ),
                      ],
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

  // ----------------------------------------------------------------
  // EMPTY STATE
  // ----------------------------------------------------------------
  Widget _buildEmpty(String filter) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none,
            size: 64,
            color: ThemeColors.textSecondary(context).withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.t('No notifications'),
            style: TextStyle(
              fontSize: 18,
              color: ThemeColors.textSecondary(context).withOpacity(0.5),
            ),
          ),
          if (filter == 'All') ...[
            const SizedBox(height: 8),
            Text(
              l10n.t('Check Archive tab for past alerts'),
              style: TextStyle(
                fontSize: 13,
                color: ThemeColors.textSecondary(context).withOpacity(0.3),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ----------------------------------------------------------------
  // SNACKBARS
  // ----------------------------------------------------------------
  SnackBar _snackBar(IconData icon, String msg, Color color) {
    return SnackBar(
      content: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Text(msg),
        ],
      ),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 2),
    );
  }

  SnackBar _snackBarWithUndo(String msg, {required VoidCallback onUndo, required AppLocalizations l10n}) {
    return SnackBar(
      content: Row(
        children: [
          const Icon(Icons.archive_outlined, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(msg)),
        ],
      ),
      backgroundColor: ThemeColors.surface(context),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 4),
      action: SnackBarAction(
        label: l10n.t('UNDO'),
        textColor: AppColors.primary,
        onPressed: onUndo,
      ),
    );
  }

  // ----------------------------------------------------------------
  // ACTIONS
  // ----------------------------------------------------------------
  Future<void> _markAllAsRead() async {
    final l10n = AppLocalizations.of(context);
    final total = _notifications.length;
    if (total == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        _snackBar(
          Icons.info_outline,
          'No notifications to clear',
          ThemeColors.surface(context),
        ),
      );
      return;
    }

    await _notificationService.markAllAsReadAndArchive();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        _snackBar(
          Icons.archive_outlined,
          '$total notification${total > 1 ? 's' : ''} archived',
          ThemeColors.surface(context),
        ),
      );
    }
  }

  // ----------------------------------------------------------------
  // HELPERS
  // ----------------------------------------------------------------
  int _countForFilter(String filter) {
    switch (filter) {
      case 'Critical':
        return _notifications
            .where(
              (n) => n.severity == NotificationSeverity.critical && !n.isRead,
            )
            .length;
      case 'Devices':
        return _notifications
            .where(
              (n) => n.category == NotificationCategory.device && !n.isRead,
            )
            .length;
      case 'Water':
        return _notifications
            .where(
              (n) => n.category == NotificationCategory.irrigation && !n.isRead,
            )
            .length;
      case 'Crops':
        return _notifications
            .where((n) => n.category == NotificationCategory.crop && !n.isRead)
            .length;
      case 'Weather':
        return _notifications
            .where(
              (n) => n.category == NotificationCategory.weather && !n.isRead,
            )
            .length;
      case 'System':
        return _notifications
            .where(
              (n) => n.category == NotificationCategory.system && !n.isRead,
            )
            .length;
      case 'Archived':
        return 0;
      default:
        return _notifications.where((n) => !n.isRead).length;
    }
  }

  List<NotificationModel> _filterNotifications(
    List<NotificationModel> list,
    String filter,
  ) {
    switch (filter) {
      case 'Critical':
        return list
            .where((n) => n.severity == NotificationSeverity.critical)
            .toList();
      case 'Devices':
        return list
            .where((n) => n.category == NotificationCategory.device)
            .toList();
      case 'Water':
        return list
            .where((n) => n.category == NotificationCategory.irrigation)
            .toList();
      case 'Crops':
        return list
            .where((n) => n.category == NotificationCategory.crop)
            .toList();
      case 'Weather':
        return list
            .where((n) => n.category == NotificationCategory.weather)
            .toList();
      case 'System':
        return list
            .where((n) => n.category == NotificationCategory.system)
            .toList();
      default:
        return list;
    }
  }

  Map<String, List<NotificationModel>> _groupByDate(
    List<NotificationModel> items,
  ) {
    final Map<String, List<NotificationModel>> grouped = {};
    for (final item in items) {
      final diff = DateTime.now().difference(item.timestamp);
      final label = diff.inHours < 24
          ? 'Today'
          : diff.inHours < 48
          ? 'Yesterday'
          : '${item.timestamp.day}/${item.timestamp.month}/${item.timestamp.year}';
      grouped.putIfAbsent(label, () => []).add(item);
    }
    return grouped;
  }

  Color _severityColor(NotificationSeverity s) {
    switch (s) {
      case NotificationSeverity.critical:
        return AppColors.error;
      case NotificationSeverity.warning:
        return AppColors.warning;
      case NotificationSeverity.info:
        return AppColors.primary;
    }
  }

  IconData _categoryIcon(NotificationCategory c) {
    switch (c) {
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

  IconData? _iconForFilter(String filter) {
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
        return null;
    }
  }

  String _formatTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
