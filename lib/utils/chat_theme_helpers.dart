import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

Color pageBackground(BuildContext context) =>
    Theme.of(context).scaffoldBackgroundColor;

Color surfaceBackground(BuildContext context) =>
    Theme.of(context).colorScheme.surface;

Color surfaceAltBackground(BuildContext context) =>
    Theme.of(context).colorScheme.surfaceContainerHighest;

Color titleColor(BuildContext context) =>
    Theme.of(context).colorScheme.onSurface;

Color subtitleColor(BuildContext context) =>
    Theme.of(context).colorScheme.onSurfaceVariant;

Color relationshipColor(String status) {
  return switch (status) {
    'enemy' => Colors.red.shade400,
    'married' => Colors.purple.shade400,
    'lover' => const Color(0xFFFB6F9D),
    'rejected' => Colors.grey.shade500,
    'stuck' => Colors.orange.shade400,
    _ => Colors.blue.shade400,
  };
}

TextStyle bondCountHeaderStyle(BuildContext context) {
  final isDark = isDarkMode(context);
  final colorScheme = Theme.of(context).colorScheme;
  final shadowColor = isDark
      ? Colors.black.withValues(alpha: 0.45)
      : Colors.white;

  return TextStyle(
    color: colorScheme.primary,
    fontWeight: FontWeight.w800,
    fontSize: 12,
    shadows: [
      Shadow(color: shadowColor, offset: const Offset(1, 0)),
      Shadow(color: shadowColor, offset: const Offset(-1, 0)),
      Shadow(color: shadowColor, offset: const Offset(0, 1)),
      Shadow(color: shadowColor, offset: const Offset(0, -1)),
    ],
  );
}

Color botBubbleBackground(BuildContext context) =>
    Theme.of(context).colorScheme.surfaceContainerHighest;

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
