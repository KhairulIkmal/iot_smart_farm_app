import 'package:flutter/material.dart';

import '../core/theme.dart';

/// ------------------------------------------------------------
/// CUSTOM TILE WIDGET
///
/// A reusable menu list item widget with:
/// - Leading icon with colored background
/// - Title and optional subtitle
/// - Optional trailing badge
/// - Optional trailing arrow
/// - Tap action
///
/// Used for:
/// - Settings menu items
/// - Navigation lists
/// - Selection lists
/// ------------------------------------------------------------
class CustomTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final String? badge;
  final Color? badgeColor;
  final bool showArrow;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isSelected;
  final Color? backgroundColor;
  final double? iconSize;
  final double borderRadius;

  const CustomTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.badge,
    this.badgeColor,
    this.showArrow = true,
    this.trailing,
    this.onTap,
    this.isSelected = false,
    this.backgroundColor,
    this.iconSize,
    this.borderRadius = 16,
  });

  /// Menu item factory (for settings screens)
  factory CustomTile.menu({
    Key? key,
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    String? badge,
    VoidCallback? onTap,
  }) {
    return CustomTile(
      key: key,
      icon: icon,
      iconColor: iconColor,
      title: title,
      subtitle: subtitle,
      badge: badge,
      badgeColor: AppColors.error,
      showArrow: true,
      onTap: onTap,
    );
  }

  /// Selection item factory (for selection lists)
  factory CustomTile.selection({
    Key? key,
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    required bool isSelected,
    VoidCallback? onTap,
  }) {
    return CustomTile(
      key: key,
      icon: icon,
      iconColor: iconColor,
      title: title,
      subtitle: subtitle,
      showArrow: false,
      isSelected: isSelected,
      onTap: onTap,
      trailing: isSelected
          ? Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 14),
            )
          : Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.borderDark, width: 2),
              ),
            ),
    );
  }

  /// Toggle item factory (for switch settings)
  factory CustomTile.toggle({
    Key? key,
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return CustomTile(
      key: key,
      icon: icon,
      iconColor: iconColor,
      title: title,
      subtitle: subtitle,
      showArrow: false,
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppColors.primary,
        activeTrackColor: AppColors.primary.withOpacity(0.3),
        inactiveThumbColor: Colors.grey,
        inactiveTrackColor: AppColors.borderDark,
      ),
    );
  }

  /// Info item factory (non-interactive)
  factory CustomTile.info({
    Key? key,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return CustomTile(
      key: key,
      icon: icon,
      iconColor: iconColor,
      title: title,
      showArrow: false,
      trailing: Text(
        value,
        style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.5)),
      ),
    );
  }

  /// Sensor item factory (for sensor lists)
  factory CustomTile.sensor({
    Key? key,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String status,
    Color? statusColor,
    VoidCallback? onTap,
  }) {
    return CustomTile(
      key: key,
      icon: icon,
      iconColor: iconColor,
      title: title,
      subtitle: status,
      showArrow: true,
      onTap: onTap,
      trailing: Text(
        value,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(borderRadius),
            border: isSelected
                ? Border.all(color: AppColors.primary, width: 2)
                : null,
          ),
          child: Row(
            children: [
              // Leading Icon
              _buildLeadingIcon(),
              const SizedBox(width: 14),

              // Title & Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: isSelected ? AppColors.primary : Colors.white,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Badge
              if (badge != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor ?? AppColors.error,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],

              // Custom Trailing Widget
              if (trailing != null) trailing!,

              // Arrow
              if (showArrow && trailing == null)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(
                    Icons.chevron_right,
                    color: Colors.white.withOpacity(0.3),
                    size: 22,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeadingIcon() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: iconColor, size: iconSize ?? 22),
    );
  }
}

/// ------------------------------------------------------------
/// CUSTOM TILE GROUP
///
/// A container for grouping multiple CustomTile items
/// with consistent styling and dividers.
/// ------------------------------------------------------------
class CustomTileGroup extends StatelessWidget {
  final List<CustomTile> tiles;
  final String? title;
  final Color? backgroundColor;
  final double borderRadius;

  const CustomTileGroup({
    super.key,
    required this.tiles,
    this.title,
    this.backgroundColor,
    this.borderRadius = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Title
        if (title != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              title!.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.5),
                letterSpacing: 1,
              ),
            ),
          ),
        ],

        // Tiles Container
        Container(
          decoration: BoxDecoration(
            color: backgroundColor ?? AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: AppColors.borderDark),
          ),
          child: Column(
            children: tiles.asMap().entries.map((entry) {
              final index = entry.key;
              final tile = entry.value;
              final isLast = index == tiles.length - 1;

              return Column(
                children: [
                  tile,
                  if (!isLast)
                    Divider(height: 1, color: AppColors.borderDark, indent: 60),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
