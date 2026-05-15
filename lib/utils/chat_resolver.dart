import 'package:flutter/material.dart';
import 'chat_theme_helpers.dart';

String? resolveBotName(
  String? botId,
  List<Map<String, dynamic>> groupMembers,
  Map<String, dynamic> bot,
) {
  if (botId == null) return null;
  try {
    final member = groupMembers.firstWhere(
      (m) => (m['bot_id']?.toString() ?? m['id']?.toString()) == botId,
      orElse: () => <String, dynamic>{},
    );
    if (member.isNotEmpty && member['name'] != null) {
      return member['name'] as String;
    }
  } catch (_) {}
  return bot['name'] as String?;
}

String? resolveBotAvatar(
  String? botId,
  List<Map<String, dynamic>> groupMembers,
  Map<String, dynamic> bot,
) {
  if (botId == null) return null;
  try {
    final member = groupMembers.firstWhere(
      (m) => (m['bot_id']?.toString() ?? m['id']?.toString()) == botId,
      orElse: () => <String, dynamic>{},
    );
    if (member.isNotEmpty) {
      return member['image_url'] ?? member['avatar'];
    }
  } catch (_) {}
  return bot['image_url'] as String?;
}

Color resolveBotColor(
  String? botId,
  List<Map<String, dynamic>> groupMembers,
  Map<String, dynamic> bot,
) {
  if (botId == null) return parseColor(bot['color']);
  try {
    final member = groupMembers.firstWhere(
      (m) => (m['bot_id']?.toString() ?? m['id']?.toString()) == botId,
      orElse: () => <String, dynamic>{},
    );
    if (member.isNotEmpty && member['color'] != null) {
      return parseColor(member['color']);
    }
  } catch (_) {}
  return parseColor(bot['color']);
}
