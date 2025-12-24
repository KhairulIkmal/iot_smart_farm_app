import 'package:flutter/material.dart';

import '../core/theme.dart';

/// ------------------------------------------------------------
/// CUSTOM BUTTON WIDGET
///
/// A reusable button widget with multiple styles:
/// - Primary (filled green)
/// - Secondary (outlined)
/// - Danger (filled red)
/// - Ghost (text only)
///
/// Features:
/// - Loading state with spinner
/// - Disabled state
/// - Icon support (leading/trailing)
/// - Full width option
/// - Custom sizing
/// ------------------------------------------------------------

enum CustomButtonStyle { primary, secondary, danger, ghost }

enum CustomButtonSize { small, medium, large }

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final CustomButtonStyle style;
  final CustomButtonSize size;
  final bool isLoading;
  final bool isFullWidth;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final Color? customColor;
  final double? customHeight;
  final double? customBorderRadius;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.style = CustomButtonStyle.primary,
    this.size = CustomButtonSize.medium,
    this.isLoading = false,
    this.isFullWidth = true,
    this.leadingIcon,
    this.trailingIcon,
    this.customColor,
    this.customHeight,
    this.customBorderRadius,
  });

  /// Primary button factory
  factory CustomButton.primary({
    Key? key,
    required String text,
    VoidCallback? onPressed,
    bool isLoading = false,
    bool isFullWidth = true,
    IconData? leadingIcon,
    IconData? trailingIcon,
    CustomButtonSize size = CustomButtonSize.medium,
  }) {
    return CustomButton(
      key: key,
      text: text,
      onPressed: onPressed,
      style: CustomButtonStyle.primary,
      size: size,
      isLoading: isLoading,
      isFullWidth: isFullWidth,
      leadingIcon: leadingIcon,
      trailingIcon: trailingIcon,
    );
  }

  /// Secondary button factory
  factory CustomButton.secondary({
    Key? key,
    required String text,
    VoidCallback? onPressed,
    bool isLoading = false,
    bool isFullWidth = true,
    IconData? leadingIcon,
    IconData? trailingIcon,
    CustomButtonSize size = CustomButtonSize.medium,
  }) {
    return CustomButton(
      key: key,
      text: text,
      onPressed: onPressed,
      style: CustomButtonStyle.secondary,
      size: size,
      isLoading: isLoading,
      isFullWidth: isFullWidth,
      leadingIcon: leadingIcon,
      trailingIcon: trailingIcon,
    );
  }

  /// Danger button factory
  factory CustomButton.danger({
    Key? key,
    required String text,
    VoidCallback? onPressed,
    bool isLoading = false,
    bool isFullWidth = true,
    IconData? leadingIcon,
    IconData? trailingIcon,
    CustomButtonSize size = CustomButtonSize.medium,
  }) {
    return CustomButton(
      key: key,
      text: text,
      onPressed: onPressed,
      style: CustomButtonStyle.danger,
      size: size,
      isLoading: isLoading,
      isFullWidth: isFullWidth,
      leadingIcon: leadingIcon,
      trailingIcon: trailingIcon,
    );
  }

  /// Ghost button factory
  factory CustomButton.ghost({
    Key? key,
    required String text,
    VoidCallback? onPressed,
    bool isLoading = false,
    bool isFullWidth = false,
    IconData? leadingIcon,
    IconData? trailingIcon,
    CustomButtonSize size = CustomButtonSize.medium,
    Color? customColor,
  }) {
    return CustomButton(
      key: key,
      text: text,
      onPressed: onPressed,
      style: CustomButtonStyle.ghost,
      size: size,
      isLoading: isLoading,
      isFullWidth: isFullWidth,
      leadingIcon: leadingIcon,
      trailingIcon: trailingIcon,
      customColor: customColor,
    );
  }

  @override
  Widget build(BuildContext context) {
    final height = customHeight ?? _getHeight();
    final borderRadius = customBorderRadius ?? 16.0;
    final isDisabled = onPressed == null || isLoading;

    Widget buttonChild = _buildButtonContent();

    switch (style) {
      case CustomButtonStyle.primary:
        return SizedBox(
          width: isFullWidth ? double.infinity : null,
          height: height,
          child: ElevatedButton(
            onPressed: isDisabled ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: customColor ?? AppColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: (customColor ?? AppColors.primary)
                  .withOpacity(0.5),
              disabledForegroundColor: Colors.white.withOpacity(0.7),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              elevation: 0,
              padding: _getPadding(),
            ),
            child: buttonChild,
          ),
        );

      case CustomButtonStyle.secondary:
        return SizedBox(
          width: isFullWidth ? double.infinity : null,
          height: height,
          child: OutlinedButton(
            onPressed: isDisabled ? null : onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: customColor ?? Colors.white,
              side: BorderSide(
                color: isDisabled
                    ? AppColors.borderDark
                    : (customColor ?? AppColors.borderDark),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              padding: _getPadding(),
            ),
            child: buttonChild,
          ),
        );

      case CustomButtonStyle.danger:
        return SizedBox(
          width: isFullWidth ? double.infinity : null,
          height: height,
          child: ElevatedButton(
            onPressed: isDisabled ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: customColor ?? AppColors.error,
              foregroundColor: Colors.white,
              disabledBackgroundColor: (customColor ?? AppColors.error)
                  .withOpacity(0.5),
              disabledForegroundColor: Colors.white.withOpacity(0.7),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              elevation: 0,
              padding: _getPadding(),
            ),
            child: buttonChild,
          ),
        );

      case CustomButtonStyle.ghost:
        return SizedBox(
          width: isFullWidth ? double.infinity : null,
          height: height,
          child: TextButton(
            onPressed: isDisabled ? null : onPressed,
            style: TextButton.styleFrom(
              foregroundColor: customColor ?? AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              padding: _getPadding(),
            ),
            child: buttonChild,
          ),
        );
    }
  }

  Widget _buildButtonContent() {
    if (isLoading) {
      return SizedBox(
        width: _getLoaderSize(),
        height: _getLoaderSize(),
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(
            style == CustomButtonStyle.secondary ||
                    style == CustomButtonStyle.ghost
                ? AppColors.primary
                : Colors.white,
          ),
        ),
      );
    }

    final textWidget = Text(
      text,
      style: TextStyle(fontSize: _getFontSize(), fontWeight: FontWeight.w600),
    );

    if (leadingIcon == null && trailingIcon == null) {
      return textWidget;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (leadingIcon != null) ...[
          Icon(leadingIcon, size: _getIconSize()),
          SizedBox(width: size == CustomButtonSize.small ? 6 : 8),
        ],
        textWidget,
        if (trailingIcon != null) ...[
          SizedBox(width: size == CustomButtonSize.small ? 6 : 8),
          Icon(trailingIcon, size: _getIconSize()),
        ],
      ],
    );
  }

  double _getHeight() {
    switch (size) {
      case CustomButtonSize.small:
        return 40;
      case CustomButtonSize.medium:
        return 52;
      case CustomButtonSize.large:
        return 60;
    }
  }

  EdgeInsets _getPadding() {
    switch (size) {
      case CustomButtonSize.small:
        return const EdgeInsets.symmetric(horizontal: 16, vertical: 8);
      case CustomButtonSize.medium:
        return const EdgeInsets.symmetric(horizontal: 24, vertical: 12);
      case CustomButtonSize.large:
        return const EdgeInsets.symmetric(horizontal: 32, vertical: 16);
    }
  }

  double _getFontSize() {
    switch (size) {
      case CustomButtonSize.small:
        return 14;
      case CustomButtonSize.medium:
        return 16;
      case CustomButtonSize.large:
        return 18;
    }
  }

  double _getIconSize() {
    switch (size) {
      case CustomButtonSize.small:
        return 18;
      case CustomButtonSize.medium:
        return 20;
      case CustomButtonSize.large:
        return 24;
    }
  }

  double _getLoaderSize() {
    switch (size) {
      case CustomButtonSize.small:
        return 18;
      case CustomButtonSize.medium:
        return 22;
      case CustomButtonSize.large:
        return 26;
    }
  }
}
