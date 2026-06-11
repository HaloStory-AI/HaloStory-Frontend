import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/wallpaper_service.dart';
import '../theme/app_theme.dart';

mixin ChatHelpers {
  Color parseColor(dynamic color) {
    if (color == null) return Colors.blueGrey;
    if (color is Color) return color;
    if (color is String) {
      try {
        return Color(int.parse(color));
      } catch (_) {
        return Colors.blueGrey;
      }
    }
    return Colors.blueGrey;
  }

  bool isDarkMode(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  Color textOnWallpaper(BuildContext context, Color defaultColor) {
    if (WallpaperService().type == 'none') return defaultColor;
    return Colors.white;
  }

  Color subtextOnWallpaper(BuildContext context, Color defaultColor) {
    if (WallpaperService().type == 'none') return defaultColor;
    return Colors.white70;
  }

  Color pageBackground(BuildContext context) =>
      Theme.of(context).scaffoldBackgroundColor;

  BoxDecoration? getWallpaperDecoration(BuildContext context) =>
      WallpaperService().getBoxDecoration(context);

  Color surfaceBackground(BuildContext context) =>
      Theme.of(context).colorScheme.surface;

  Color surfaceAltBackground(BuildContext context) =>
      Theme.of(context).colorScheme.surfaceContainerHighest;

  Color titleColor(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;

  Color subtitleColor(BuildContext context) =>
      Theme.of(context).colorScheme.onSurfaceVariant;

  Color botBubbleBackground(BuildContext context) =>
      isDarkMode(context) ? AppTheme.botBubbleDark : AppTheme.botBubbleLight;

  Color fieldBorderColor(BuildContext context) =>
      Theme.of(context).colorScheme.outlineVariant;

  Color hintColor(BuildContext context) {
    final color = Theme.of(context).inputDecorationTheme.hintStyle?.color;
    return color ?? Theme.of(context).colorScheme.onSurfaceVariant;
  }

  String formatMessageTime(DateTime? dt) {
    if (dt == null) return "";
    return '${DateFormat('MMMM d').format(dt)} at ${DateFormat('h:mm a').format(dt)}';
  }
}
