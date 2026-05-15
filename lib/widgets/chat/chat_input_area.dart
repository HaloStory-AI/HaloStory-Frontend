import 'package:flutter/material.dart';
import '../../services/localization_service.dart';
import '../../utils/chat_theme_helpers.dart';

class ChatInputArea extends StatelessWidget {
  final TextEditingController controller;
  final bool isGroup;
  final bool isTypingEffectActive;
  final bool isCharacterMenuOpen;
  final String? selectedBotId;
  final List<Map<String, dynamic>> groupMembers;
  final Map<String, dynamic> bot;
  final bool isSystemNoteOpen;
  final VoidCallback onSend;
  final VoidCallback onToggleCharacterMenu;
  final VoidCallback onToggleSystemNote;

  const ChatInputArea({
    super.key,
    required this.controller,
    required this.isGroup,
    required this.isTypingEffectActive,
    required this.isCharacterMenuOpen,
    this.selectedBotId,
    required this.groupMembers,
    required this.bot,
    required this.isSystemNoteOpen,
    required this.onSend,
    required this.onToggleCharacterMenu,
    required this.onToggleSystemNote,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
          decoration: BoxDecoration(color: colorScheme.surfaceContainer),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (isGroup) ...[
                      _buildCharacterButton(context),
                      const SizedBox(width: 4),
                    ] else ...[
                      _buildSystemNoteButton(context),
                      const SizedBox(width: 4),
                    ],
                    Expanded(child: _buildTextField(context)),
                    const SizedBox(width: 4),
                    if (isGroup) ...[_buildSystemNoteButton(context)],
                    _buildSendButton(context),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  tr('chat_fictional_disclaimer'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    color: subtitleColor(context),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCharacterButton(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      decoration: const BoxDecoration(shape: BoxShape.circle),
      child: IconButton(
        onPressed: onToggleCharacterMenu,
        icon: _buildLeftInputIcon(context),
        iconSize: 34,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(
          minWidth: 34,
          minHeight: 34,
        ),
      ),
    );
  }

  Widget _buildLeftInputIcon(BuildContext context) {
    if (isGroup && selectedBotId == 'random') {
      return CircleAvatar(
        radius: 19,
        backgroundColor: Colors.transparent,
        child: Icon(
          Icons.shuffle,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          size: 28,
        ),
      );
    }

    String? avatarUrl;
    String initial = '?';
    Color bgColor = Colors.blueGrey;

    if (isGroup && selectedBotId != null) {
      final member = groupMembers.firstWhere(
        (m) =>
            (m['bot_id']?.toString() ?? m['id']?.toString()) == selectedBotId,
        orElse: () => <String, dynamic>{},
      );
      if (member.isNotEmpty) {
        avatarUrl = member['image_url'] ?? member['avatar'];
        initial = (member['name'] ?? '?')[0].toUpperCase();
        bgColor = parseColor(member['color']);
      }
    } else {
      avatarUrl = bot['image_url'];
      initial = (bot['name'] ?? '?')[0].toUpperCase();
      bgColor = parseColor(bot['color']);
    }

    return CircleAvatar(
      radius: 17,
      backgroundColor: bgColor,
      backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
      child: avatarUrl == null
          ? Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            )
          : null,
    );
  }

  Widget _buildSystemNoteButton(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return IconButton(
      onPressed: onToggleSystemNote,
      icon: Icon(
        isSystemNoteOpen ? Icons.sticky_note_2 : Icons.sticky_note_2_outlined,
        color: isSystemNoteOpen
            ? colorScheme.primary
            : colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
      ),
      iconSize: 22,
      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
      padding: const EdgeInsets.all(4),
    );
  }

  Widget _buildTextField(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    String hintText;
    if (isGroup) {
      final name = selectedBotId == 'random'
          ? tr('chat_hint_someone')
          : (groupMembers.firstWhere(
              (m) => (m['bot_id']?.toString() ?? m['id']?.toString()) == selectedBotId,
              orElse: () => {'name': bot['name']},
            )['name'] as String);
      hintText = '${tr('chat_hint_group')} $name';
    } else {
      hintText = '${tr('tab_chat')} ${bot['name']}';
    }

    return TextField(
      controller: controller,
      style: TextStyle(
        color: colorScheme.onSurface,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        hintText: hintText,
        hintStyle: TextStyle(
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
          fontSize: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(50),
          borderSide: const BorderSide(color: Colors.transparent),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(50),
          borderSide: const BorderSide(color: Colors.transparent),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(50),
          borderSide: const BorderSide(color: Colors.transparent),
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 8,
        ),
      ),
      onSubmitted: (_) {
        if (!isTypingEffectActive) {
          onSend();
        }
      },
    );
  }

  Widget _buildSendButton(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: isTypingEffectActive ? null : onSend,
      child: Container(
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.all(6),
        child: Icon(
          Icons.send,
          color: isTypingEffectActive
              ? colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
              : colorScheme.primary,
          size: 24,
        ),
      ),
    );
  }
}
