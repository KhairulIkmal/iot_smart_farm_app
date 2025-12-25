import 'package:flutter/material.dart';

import '../core/theme.dart';

/// ------------------------------------------------------------
/// CUSTOM TEXT FIELD WIDGET
///
/// A reusable text field widget with multiple styles:
/// - Standard (with container background)
/// - Outlined (border only)
/// - Filled (with fill color)
///
/// Features:
/// - Dark green theme styling
/// - Icon support (leading/trailing)
/// - Validation support
/// - Keyboard type options
/// - Enabled/disabled states
/// - Password visibility toggle
/// - Character counter
/// ------------------------------------------------------------

enum CustomTextFieldStyle { standard, outlined, filled }

class CustomTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? initialValue;
  final IconData? icon;
  final Widget? suffixIcon;
  final bool enabled;
  final bool obscureText;
  final bool showPasswordToggle;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final int? maxLines;
  final int? maxLength;
  final bool showCounter;
  final CustomTextFieldStyle style;
  final Color? backgroundColor;
  final double borderRadius;

  const CustomTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.initialValue,
    this.icon,
    this.suffixIcon,
    this.enabled = true,
    this.obscureText = false,
    this.showPasswordToggle = false,
    this.keyboardType,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.maxLines = 1,
    this.maxLength,
    this.showCounter = false,
    this.style = CustomTextFieldStyle.standard,
    this.backgroundColor,
    this.borderRadius = 16,
  });

  /// Standard text field with container background
  factory CustomTextField.standard({
    Key? key,
    TextEditingController? controller,
    required String label,
    String? hint,
    IconData? icon,
    bool enabled = true,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return CustomTextField(
      key: key,
      controller: controller,
      label: label,
      hint: hint,
      icon: icon,
      enabled: enabled,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
      style: CustomTextFieldStyle.standard,
    );
  }

  /// Password field with visibility toggle
  factory CustomTextField.password({
    Key? key,
    TextEditingController? controller,
    required String label,
    String? hint,
    bool enabled = true,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return CustomTextField(
      key: key,
      controller: controller,
      label: label,
      hint: hint,
      icon: Icons.lock_outline,
      enabled: enabled,
      obscureText: true,
      showPasswordToggle: true,
      validator: validator,
      onChanged: onChanged,
      style: CustomTextFieldStyle.standard,
    );
  }

  /// Multiline text area
  factory CustomTextField.multiline({
    Key? key,
    TextEditingController? controller,
    required String label,
    String? hint,
    bool enabled = true,
    int maxLines = 4,
    int? maxLength,
    bool showCounter = false,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return CustomTextField(
      key: key,
      controller: controller,
      label: label,
      hint: hint,
      enabled: enabled,
      maxLines: maxLines,
      maxLength: maxLength,
      showCounter: showCounter,
      validator: validator,
      onChanged: onChanged,
      style: CustomTextFieldStyle.standard,
    );
  }

  /// Email field
  factory CustomTextField.email({
    Key? key,
    TextEditingController? controller,
    required String label,
    String? hint,
    bool enabled = true,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return CustomTextField(
      key: key,
      controller: controller,
      label: label,
      hint: hint,
      icon: Icons.email_outlined,
      enabled: enabled,
      keyboardType: TextInputType.emailAddress,
      validator: validator,
      onChanged: onChanged,
      style: CustomTextFieldStyle.standard,
    );
  }

  /// Phone field
  factory CustomTextField.phone({
    Key? key,
    TextEditingController? controller,
    required String label,
    String? hint,
    bool enabled = true,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return CustomTextField(
      key: key,
      controller: controller,
      label: label,
      hint: hint,
      icon: Icons.phone_outlined,
      enabled: enabled,
      keyboardType: TextInputType.phone,
      validator: validator,
      onChanged: onChanged,
      style: CustomTextFieldStyle.standard,
    );
  }

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  bool _obscureText = true;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.style) {
      case CustomTextFieldStyle.standard:
        return _buildStandardField();
      case CustomTextFieldStyle.outlined:
        return _buildOutlinedField();
      case CustomTextFieldStyle.filled:
        return _buildFilledField();
    }
  }

  Widget _buildStandardField() {
    return Container(
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: Border.all(
          color: widget.enabled
              ? AppColors.primary.withOpacity(0.3)
              : AppColors.borderDark,
        ),
      ),
      child: TextFormField(
        controller: widget.controller,
        initialValue: widget.initialValue,
        enabled: widget.enabled,
        obscureText: _obscureText,
        keyboardType: widget.keyboardType,
        validator: widget.validator,
        onChanged: widget.onChanged,
        onFieldSubmitted: widget.onSubmitted,
        maxLines: widget.obscureText ? 1 : widget.maxLines,
        maxLength: widget.maxLength,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        decoration: InputDecoration(
          filled: false,
          labelText: widget.label,
          hintText: widget.hint,
          labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
          prefixIcon: widget.icon != null
              ? Icon(
                  widget.icon,
                  color: widget.enabled
                      ? AppColors.primary
                      : Colors.white.withOpacity(0.3),
                )
              : null,
          suffixIcon: _buildSuffixIcon(),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          counterText: widget.showCounter ? null : '',
        ),
      ),
    );
  }

  Widget _buildOutlinedField() {
    return TextFormField(
      controller: widget.controller,
      initialValue: widget.initialValue,
      enabled: widget.enabled,
      obscureText: _obscureText,
      keyboardType: widget.keyboardType,
      validator: widget.validator,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onSubmitted,
      maxLines: widget.obscureText ? 1 : widget.maxLines,
      maxLength: widget.maxLength,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        filled: false,
        labelText: widget.label,
        hintText: widget.hint,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
        prefixIcon: widget.icon != null
            ? Icon(
                widget.icon,
                color: widget.enabled
                    ? AppColors.primary
                    : Colors.white.withOpacity(0.3),
              )
            : null,
        suffixIcon: _buildSuffixIcon(),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          borderSide: const BorderSide(color: AppColors.borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          borderSide: BorderSide(color: AppColors.borderDark.withOpacity(0.5)),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        counterText: widget.showCounter ? null : '',
      ),
    );
  }

  Widget _buildFilledField() {
    return TextFormField(
      controller: widget.controller,
      initialValue: widget.initialValue,
      enabled: widget.enabled,
      obscureText: _obscureText,
      keyboardType: widget.keyboardType,
      validator: widget.validator,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onSubmitted,
      maxLines: widget.obscureText ? 1 : widget.maxLines,
      maxLength: widget.maxLength,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        filled: true,
        fillColor: widget.backgroundColor ?? AppColors.surfaceDark,
        labelText: widget.label,
        hintText: widget.hint,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
        prefixIcon: widget.icon != null
            ? Icon(
                widget.icon,
                color: widget.enabled
                    ? AppColors.primary
                    : Colors.white.withOpacity(0.3),
              )
            : null,
        suffixIcon: _buildSuffixIcon(),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        counterText: widget.showCounter ? null : '',
      ),
    );
  }

  Widget? _buildSuffixIcon() {
    if (widget.showPasswordToggle) {
      return IconButton(
        icon: Icon(
          _obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          color: Colors.white.withOpacity(0.5),
        ),
        onPressed: () {
          setState(() {
            _obscureText = !_obscureText;
          });
        },
      );
    }
    return widget.suffixIcon;
  }
}

/// ------------------------------------------------------------
/// CUSTOM SEARCH FIELD
/// ------------------------------------------------------------
class CustomSearchField extends StatelessWidget {
  final TextEditingController? controller;
  final String? hint;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final VoidCallback? onClear;
  final Color? backgroundColor;

  const CustomSearchField({
    super.key,
    this.controller,
    this.hint,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        decoration: InputDecoration(
          filled: false,
          hintText: hint ?? 'Search...',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
          prefixIcon: Icon(
            Icons.search,
            color: Colors.white.withOpacity(0.5),
          ),
          suffixIcon: controller != null && controller!.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: Colors.white.withOpacity(0.5),
                  ),
                  onPressed: () {
                    controller!.clear();
                    if (onClear != null) onClear!();
                    if (onChanged != null) onChanged!('');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }
}
