/// ------------------------------------------------------------
/// DATE UTILITIES
///
/// Date & time formatting + calculations for:
/// - Sensor graphs (X-axis labels)
/// - Timestamps display
/// - "Last seen" / "time ago" logic
/// - Connectivity status
///
/// No Firebase, no UI, no BuildContext.
///
/// Usage:
/// ```dart
/// String ago = DateUtils.timeAgo(timestamp);
/// String formatted = DateUtils.formatTimestamp(timestamp);
/// ```
/// ------------------------------------------------------------
library;

// Using a different name to avoid conflict with Flutter's DateUtils
class AppDateUtils {
  // Private constructor to prevent instantiation
  AppDateUtils._();

  // ============================================================
  // TIMESTAMP CONVERSION
  // ============================================================

  /// Convert Unix timestamp (seconds) to DateTime
  static DateTime fromUnixSeconds(int timestamp) {
    return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
  }

  /// Convert Unix timestamp (milliseconds) to DateTime
  static DateTime fromUnixMillis(int timestamp) {
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  /// Convert DateTime to Unix timestamp (seconds)
  static int toUnixSeconds(DateTime dateTime) {
    return dateTime.millisecondsSinceEpoch ~/ 1000;
  }

  /// Convert DateTime to Unix timestamp (milliseconds)
  static int toUnixMillis(DateTime dateTime) {
    return dateTime.millisecondsSinceEpoch;
  }

  /// Get current Unix timestamp (seconds)
  static int nowUnixSeconds() {
    return toUnixSeconds(DateTime.now());
  }

  /// Get current Unix timestamp (milliseconds)
  static int nowUnixMillis() {
    return DateTime.now().millisecondsSinceEpoch;
  }

  // ============================================================
  // TIME AGO FORMATTING
  // ============================================================

  /// Format timestamp as "time ago" string
  /// e.g., "5m ago", "2h ago", "3d ago"
  static String timeAgo(int timestampSeconds) {
    final dateTime = fromUnixSeconds(timestampSeconds);
    return timeAgoFromDateTime(dateTime);
  }

  /// Format DateTime as "time ago" string
  static String timeAgoFromDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.isNegative) {
      return 'just now';
    }

    if (difference.inSeconds < 60) {
      return 'just now';
    }

    if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return '${minutes}m ago';
    }

    if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '${hours}h ago';
    }

    if (difference.inDays < 7) {
      final days = difference.inDays;
      return '${days}d ago';
    }

    if (difference.inDays < 30) {
      final weeks = difference.inDays ~/ 7;
      return '${weeks}w ago';
    }

    if (difference.inDays < 365) {
      final months = difference.inDays ~/ 30;
      return '${months}mo ago';
    }

    final years = difference.inDays ~/ 365;
    return '${years}y ago';
  }

  /// Format timestamp as verbose "time ago"
  /// e.g., "5 minutes ago", "2 hours ago"
  static String timeAgoVerbose(int timestampSeconds) {
    final dateTime = fromUnixSeconds(timestampSeconds);
    return timeAgoVerboseFromDateTime(dateTime);
  }

  /// Format DateTime as verbose "time ago"
  static String timeAgoVerboseFromDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.isNegative) {
      return 'just now';
    }

    if (difference.inSeconds < 60) {
      return 'just now';
    }

    if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return '$minutes ${minutes == 1 ? 'minute' : 'minutes'} ago';
    }

    if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
    }

    if (difference.inDays < 7) {
      final days = difference.inDays;
      return '$days ${days == 1 ? 'day' : 'days'} ago';
    }

    if (difference.inDays < 30) {
      final weeks = difference.inDays ~/ 7;
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    }

    if (difference.inDays < 365) {
      final months = difference.inDays ~/ 30;
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    }

    final years = difference.inDays ~/ 365;
    return '$years ${years == 1 ? 'year' : 'years'} ago';
  }

  // ============================================================
  // DATE FORMATTING
  // ============================================================

  /// Format timestamp as full date
  /// e.g., "Dec 23, 2025"
  static String formatDate(int timestampSeconds) {
    final dateTime = fromUnixSeconds(timestampSeconds);
    return formatDateTime(dateTime);
  }

  /// Format DateTime as full date
  static String formatDateTime(DateTime dateTime) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year}';
  }

  /// Format timestamp as short date
  /// e.g., "23/12/25"
  static String formatDateShort(int timestampSeconds) {
    final dateTime = fromUnixSeconds(timestampSeconds);
    return formatDateTimeShort(dateTime);
  }

  /// Format DateTime as short date
  static String formatDateTimeShort(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year.toString().substring(2);
    return '$day/$month/$year';
  }

  /// Format timestamp as ISO date
  /// e.g., "2025-12-23"
  static String formatDateISO(int timestampSeconds) {
    final dateTime = fromUnixSeconds(timestampSeconds);
    return formatDateTimeISO(dateTime);
  }

  /// Format DateTime as ISO date
  static String formatDateTimeISO(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    return '${dateTime.year}-$month-$day';
  }

  // ============================================================
  // TIME FORMATTING
  // ============================================================

  /// Format timestamp as time only
  /// e.g., "14:30"
  static String formatTime(int timestampSeconds) {
    final dateTime = fromUnixSeconds(timestampSeconds);
    return formatTimeFromDateTime(dateTime);
  }

  /// Format DateTime as time only
  static String formatTimeFromDateTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Format timestamp as 12-hour time
  /// e.g., "2:30 PM"
  static String formatTime12Hour(int timestampSeconds) {
    final dateTime = fromUnixSeconds(timestampSeconds);
    return formatTime12HourFromDateTime(dateTime);
  }

  /// Format DateTime as 12-hour time
  static String formatTime12HourFromDateTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$displayHour:$minute $period';
  }

  // ============================================================
  // DATE + TIME FORMATTING
  // ============================================================

  /// Format timestamp as full datetime
  /// e.g., "Dec 23, 2025 at 14:30"
  static String formatTimestamp(int timestampSeconds) {
    final dateTime = fromUnixSeconds(timestampSeconds);
    return '${formatDateTime(dateTime)} at ${formatTimeFromDateTime(dateTime)}';
  }

  /// Format timestamp as relative datetime
  /// Shows "Today", "Yesterday", or date
  static String formatRelativeDate(int timestampSeconds) {
    final dateTime = fromUnixSeconds(timestampSeconds);
    return formatRelativeDateFromDateTime(dateTime);
  }

  /// Format DateTime as relative datetime
  static String formatRelativeDateFromDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final inputDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (inputDate == today) {
      return 'Today';
    } else if (inputDate == yesterday) {
      return 'Yesterday';
    } else if (now.difference(dateTime).inDays < 7) {
      return _getDayName(dateTime.weekday);
    } else {
      return formatDateTime(dateTime);
    }
  }

  /// Format for notification grouping
  /// Returns "TODAY", "YESTERDAY", or full date
  static String formatNotificationGroup(int timestampSeconds) {
    final dateTime = fromUnixSeconds(timestampSeconds);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final inputDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (inputDate == today) {
      return 'TODAY';
    } else if (inputDate == yesterday) {
      return 'YESTERDAY';
    } else {
      return formatDateTime(dateTime).toUpperCase();
    }
  }

  static String _getDayName(int weekday) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[weekday - 1];
  }

  // ============================================================
  // GRAPH AXIS LABELS
  // ============================================================

  /// Get X-axis labels for 24-hour graph
  static List<String> get24HourLabels() {
    return ['12 AM', '6 AM', '12 PM', '6 PM'];
  }

  /// Get X-axis labels for 7-day graph
  static List<String> get7DayLabels() {
    final now = DateTime.now();
    final labels = <String>[];

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      labels.add(_getShortDayName(date.weekday));
    }

    return labels;
  }

  static String _getShortDayName(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }

  /// Format hour for graph label
  /// e.g., "6 AM", "12 PM"
  static String formatHourLabel(int hour) {
    if (hour == 0) return '12 AM';
    if (hour == 12) return '12 PM';
    if (hour < 12) return '$hour AM';
    return '${hour - 12} PM';
  }

  // ============================================================
  // TIME COMPARISON / CHECKS
  // ============================================================

  /// Check if timestamp is older than specified minutes
  static bool isOlderThanMinutes(int timestampSeconds, int minutes) {
    final dateTime = fromUnixSeconds(timestampSeconds);
    return DateTime.now().difference(dateTime).inMinutes > minutes;
  }

  /// Check if timestamp is older than specified hours
  static bool isOlderThanHours(int timestampSeconds, int hours) {
    final dateTime = fromUnixSeconds(timestampSeconds);
    return DateTime.now().difference(dateTime).inHours > hours;
  }

  /// Check if timestamp is older than specified days
  static bool isOlderThanDays(int timestampSeconds, int days) {
    final dateTime = fromUnixSeconds(timestampSeconds);
    return DateTime.now().difference(dateTime).inDays > days;
  }

  /// Check if timestamp is within last N minutes
  static bool isWithinMinutes(int timestampSeconds, int minutes) {
    return !isOlderThanMinutes(timestampSeconds, minutes);
  }

  /// Check if device is online (last seen within 5 minutes)
  static bool isDeviceOnline(int lastSeenTimestamp) {
    return isWithinMinutes(lastSeenTimestamp, 5);
  }

  /// Check if timestamp is today
  static bool isToday(int timestampSeconds) {
    final dateTime = fromUnixSeconds(timestampSeconds);
    final now = DateTime.now();
    return dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day;
  }

  /// Check if timestamp is yesterday
  static bool isYesterday(int timestampSeconds) {
    final dateTime = fromUnixSeconds(timestampSeconds);
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return dateTime.year == yesterday.year &&
        dateTime.month == yesterday.month &&
        dateTime.day == yesterday.day;
  }

  // ============================================================
  // DURATION FORMATTING
  // ============================================================

  /// Format duration in human readable form
  /// e.g., "2h 30m", "45m", "1d 5h"
  static String formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      final hours = duration.inHours % 24;
      return hours > 0
          ? '${duration.inDays}d ${hours}h'
          : '${duration.inDays}d';
    }

    if (duration.inHours > 0) {
      final minutes = duration.inMinutes % 60;
      return minutes > 0
          ? '${duration.inHours}h ${minutes}m'
          : '${duration.inHours}h';
    }

    if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m';
    }

    return '${duration.inSeconds}s';
  }

  /// Format duration verbose
  /// e.g., "2 hours 30 minutes"
  static String formatDurationVerbose(Duration duration) {
    if (duration.inDays > 0) {
      final days = duration.inDays;
      final hours = duration.inHours % 24;
      final daysStr = '$days ${days == 1 ? 'day' : 'days'}';
      if (hours > 0) {
        return '$daysStr $hours ${hours == 1 ? 'hour' : 'hours'}';
      }
      return daysStr;
    }

    if (duration.inHours > 0) {
      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;
      final hoursStr = '$hours ${hours == 1 ? 'hour' : 'hours'}';
      if (minutes > 0) {
        return '$hoursStr $minutes ${minutes == 1 ? 'minute' : 'minutes'}';
      }
      return hoursStr;
    }

    final minutes = duration.inMinutes;
    if (minutes > 0) {
      return '$minutes ${minutes == 1 ? 'minute' : 'minutes'}';
    }

    final seconds = duration.inSeconds;
    return '$seconds ${seconds == 1 ? 'second' : 'seconds'}';
  }

  // ============================================================
  // TIME RANGE CALCULATIONS
  // ============================================================

  /// Get start of day for a timestamp
  static DateTime startOfDay(int timestampSeconds) {
    final dateTime = fromUnixSeconds(timestampSeconds);
    return DateTime(dateTime.year, dateTime.month, dateTime.day);
  }

  /// Get end of day for a timestamp
  static DateTime endOfDay(int timestampSeconds) {
    final dateTime = fromUnixSeconds(timestampSeconds);
    return DateTime(dateTime.year, dateTime.month, dateTime.day, 23, 59, 59);
  }

  /// Get timestamp for N hours ago
  static int hoursAgo(int hours) {
    return toUnixSeconds(DateTime.now().subtract(Duration(hours: hours)));
  }

  /// Get timestamp for N days ago
  static int daysAgo(int days) {
    return toUnixSeconds(DateTime.now().subtract(Duration(days: days)));
  }

  /// Get timestamp for start of today
  static int startOfToday() {
    final now = DateTime.now();
    return toUnixSeconds(DateTime(now.year, now.month, now.day));
  }
}
