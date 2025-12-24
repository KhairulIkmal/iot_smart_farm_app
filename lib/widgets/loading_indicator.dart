import 'package:flutter/material.dart';

import '../core/theme.dart';

/// ------------------------------------------------------------
/// LOADING INDICATOR WIDGET
///
/// A reusable loading indicator with multiple styles:
/// - Circular spinner
/// - Full screen overlay
/// - Inline loading
/// - Skeleton loader
///
/// Features:
/// - Custom colors
/// - Custom sizes
/// - Optional message
/// - Overlay support
/// ------------------------------------------------------------

enum LoadingStyle { circular, overlay, inline, skeleton }

enum LoadingSize { small, medium, large }

class LoadingIndicator extends StatelessWidget {
  final LoadingStyle style;
  final LoadingSize size;
  final String? message;
  final Color? color;
  final Color? backgroundColor;

  const LoadingIndicator({
    super.key,
    this.style = LoadingStyle.circular,
    this.size = LoadingSize.medium,
    this.message,
    this.color,
    this.backgroundColor,
  });

  /// Circular loading indicator
  factory LoadingIndicator.circular({
    Key? key,
    LoadingSize size = LoadingSize.medium,
    String? message,
    Color? color,
  }) {
    return LoadingIndicator(
      key: key,
      style: LoadingStyle.circular,
      size: size,
      message: message,
      color: color,
    );
  }

  /// Full screen overlay loading
  factory LoadingIndicator.overlay({
    Key? key,
    String? message,
    Color? color,
    Color? backgroundColor,
  }) {
    return LoadingIndicator(
      key: key,
      style: LoadingStyle.overlay,
      size: LoadingSize.large,
      message: message,
      color: color,
      backgroundColor: backgroundColor,
    );
  }

  /// Inline loading (for buttons, small areas)
  factory LoadingIndicator.inline({Key? key, Color? color}) {
    return LoadingIndicator(
      key: key,
      style: LoadingStyle.inline,
      size: LoadingSize.small,
      color: color,
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (style) {
      case LoadingStyle.circular:
        return _buildCircular();
      case LoadingStyle.overlay:
        return _buildOverlay();
      case LoadingStyle.inline:
        return _buildInline();
      case LoadingStyle.skeleton:
        return _buildSkeleton();
    }
  }

  Widget _buildCircular() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: _getSize(),
            height: _getSize(),
            child: CircularProgressIndicator(
              strokeWidth: _getStrokeWidth(),
              valueColor: AlwaysStoppedAnimation<Color>(
                color ?? AppColors.primary,
              ),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOverlay() {
    return Container(
      color: backgroundColor ?? Colors.black.withOpacity(0.5),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: _getSize(),
                height: _getSize(),
                child: CircularProgressIndicator(
                  strokeWidth: _getStrokeWidth(),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    color ?? AppColors.primary,
                  ),
                ),
              ),
              if (message != null) ...[
                const SizedBox(height: 20),
                Text(
                  message!,
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInline() {
    return SizedBox(
      width: _getSize(),
      height: _getSize(),
      child: CircularProgressIndicator(
        strokeWidth: _getStrokeWidth(),
        valueColor: AlwaysStoppedAnimation<Color>(color ?? AppColors.primary),
      ),
    );
  }

  Widget _buildSkeleton() {
    return Container(
      width: double.infinity,
      height: _getSize(),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const _ShimmerEffect(),
    );
  }

  double _getSize() {
    switch (size) {
      case LoadingSize.small:
        return 20;
      case LoadingSize.medium:
        return 36;
      case LoadingSize.large:
        return 48;
    }
  }

  double _getStrokeWidth() {
    switch (size) {
      case LoadingSize.small:
        return 2;
      case LoadingSize.medium:
        return 3;
      case LoadingSize.large:
        return 4;
    }
  }
}

/// ------------------------------------------------------------
/// SHIMMER EFFECT FOR SKELETON LOADING
/// ------------------------------------------------------------
class _ShimmerEffect extends StatefulWidget {
  const _ShimmerEffect();

  @override
  State<_ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<_ShimmerEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                AppColors.surfaceDark,
                AppColors.borderDark,
                AppColors.surfaceDark,
              ],
              stops: [0.0, _controller.value, 1.0],
            ).createShader(bounds);
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      },
    );
  }
}

/// ------------------------------------------------------------
/// SKELETON LOADER WIDGETS
/// ------------------------------------------------------------
class SkeletonLoader extends StatelessWidget {
  final double? width;
  final double height;
  final double borderRadius;

  const SkeletonLoader({
    super.key,
    this.width,
    this.height = 20,
    this.borderRadius = 8,
  });

  /// Text line skeleton
  factory SkeletonLoader.text({Key? key, double? width, double height = 16}) {
    return SkeletonLoader(
      key: key,
      width: width,
      height: height,
      borderRadius: 4,
    );
  }

  /// Avatar skeleton
  factory SkeletonLoader.avatar({Key? key, double size = 48}) {
    return SkeletonLoader(
      key: key,
      width: size,
      height: size,
      borderRadius: size / 2,
    );
  }

  /// Card skeleton
  factory SkeletonLoader.card({Key? key, double height = 120}) {
    return SkeletonLoader(key: key, height: height, borderRadius: 16);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: const _ShimmerEffect(),
    );
  }
}

/// ------------------------------------------------------------
/// LOADING OVERLAY WRAPPER
///
/// Wraps a child widget and shows loading overlay when loading.
/// ------------------------------------------------------------
class LoadingOverlay extends StatelessWidget {
  final Widget child;
  final bool isLoading;
  final String? message;
  final Color? backgroundColor;

  const LoadingOverlay({
    super.key,
    required this.child,
    required this.isLoading,
    this.message,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Positioned.fill(
            child: LoadingIndicator.overlay(
              message: message,
              backgroundColor: backgroundColor,
            ),
          ),
      ],
    );
  }
}

/// ------------------------------------------------------------
/// PULL TO REFRESH INDICATOR
/// ------------------------------------------------------------
class CustomRefreshIndicator extends StatelessWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  final Color? color;

  const CustomRefreshIndicator({
    super.key,
    required this.child,
    required this.onRefresh,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: color ?? AppColors.primary,
      backgroundColor: AppColors.surfaceDark,
      child: child,
    );
  }
}
