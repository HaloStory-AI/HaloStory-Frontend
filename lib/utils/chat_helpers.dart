import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';

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

Color surfaceBackground(BuildContext context) =>
    Theme.of(context).colorScheme.surface;

Color surfaceAltBackground(BuildContext context) =>
    Theme.of(context).colorScheme.surfaceContainerHighest;

Color titleColor(BuildContext context) =>
    Theme.of(context).colorScheme.onSurface;

Color subtitleColor(BuildContext context) =>
    Theme.of(context).colorScheme.onSurfaceVariant;

Color fieldBorderColor(BuildContext context) =>
    Theme.of(context).colorScheme.outlineVariant;

Color hintColor(BuildContext context) {
  final color = Theme.of(context).inputDecorationTheme.hintStyle?.color;
  return color ?? Theme.of(context).colorScheme.onSurfaceVariant;
}

mixin ChatHelpers {
  Color pageBackground(BuildContext context) =>
      Theme.of(context).scaffoldBackgroundColor;

  Color botBubbleBackground(BuildContext context) => AppTheme.botBubbleDark;

  String formatMessageTime(DateTime? dt) {
    if (dt == null) return "";
    return '${DateFormat('MMMM d').format(dt)} at ${DateFormat('h:mm a').format(dt)}';
  }
}

String filterItalics(String text, bool enabled) {
  if (!enabled) return text;
  String filtered = text
      .replaceAll(RegExp(r'\*(?!\*)[^*]+\*'), '')
      .replaceAll(RegExp(r'_(?!_)[^_]+_'), '');
  return filtered.trim();
}
