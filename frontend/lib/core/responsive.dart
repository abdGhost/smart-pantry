import 'package:flutter/material.dart';

import 'colors.dart';

/// Responsive layout and typography for mobile-first screens.
/// Use [Responsive.of](context) in build methods to get values that adapt to screen width.
class Responsive {
  const Responsive._();

  static ResponsiveData of(BuildContext context) {
    final media = MediaQuery.of(context);
    final w = media.size.width;
    final isNarrow = w < 400;
    final isCompact = w < 360;

    return ResponsiveData(
      screenWidth: w,
      screenHeight: media.size.height,
      isNarrow: isNarrow,
      isCompact: isCompact,
      horizontalPadding: isCompact ? 12.0 : (isNarrow ? 16.0 : 20.0),
      /// Scale factor for font sizes on narrow screens (e.g. 0.9)
      fontScale: isCompact ? 0.85 : (isNarrow ? 0.92 : 1.0),
    );
  }
}

class ResponsiveData {
  const ResponsiveData({
    required this.screenWidth,
    required this.screenHeight,
    required this.isNarrow,
    required this.isCompact,
    required this.horizontalPadding,
    required this.fontScale,
  });

  final double screenWidth;
  final double screenHeight;
  final bool isNarrow;
  final bool isCompact;
  final double horizontalPadding;
  final double fontScale;

  /// Scaled font size: baseSize * fontScale, with optional min/max.
  double scaleFont(double baseSize, {double? min, double? max}) {
    var s = baseSize * fontScale;
    if (min != null && s < min) s = min;
    if (max != null && s > max) s = max;
    return s;
  }

  /// Title-style text with responsive size and [AppColors.charcoalText].
  TextStyle titleStyle(BuildContext context, {double? fontSize, FontWeight? fontWeight}) {
    final theme = Theme.of(context).textTheme;
    final size = scaleFont(fontSize ?? (theme.titleMedium?.fontSize ?? 16));
    return (theme.titleMedium ?? TextStyle()).copyWith(
      fontSize: size,
      fontWeight: fontWeight ?? FontWeight.w600,
      color: AppColors.charcoalText,
    );
  }

  /// Body-style text with responsive size.
  TextStyle bodyStyle(BuildContext context, {double? fontSize, Color? color}) {
    final theme = Theme.of(context).textTheme;
    final size = scaleFont(fontSize ?? (theme.bodyMedium?.fontSize ?? 14));
    return (theme.bodyMedium ?? TextStyle()).copyWith(
      fontSize: size,
      color: color ?? AppColors.charcoalText,
    );
  }

  /// Small body/caption with responsive size.
  TextStyle bodySmallStyle(BuildContext context, {double? fontSize, Color? color}) {
    final theme = Theme.of(context).textTheme;
    final size = scaleFont(fontSize ?? (theme.bodySmall?.fontSize ?? 12));
    return (theme.bodySmall ?? TextStyle()).copyWith(
      fontSize: size,
      color: color ?? AppColors.charcoalText.withOpacity(0.85),
    );
  }

  /// Label style (chips, buttons).
  TextStyle labelStyle(BuildContext context, {double? fontSize, FontWeight? fontWeight}) {
    final theme = Theme.of(context).textTheme;
    final size = scaleFont(fontSize ?? (theme.labelMedium?.fontSize ?? 12));
    return (theme.labelMedium ?? TextStyle()).copyWith(
      fontSize: size,
      fontWeight: fontWeight ?? FontWeight.w600,
      color: AppColors.charcoalText,
    );
  }
}
