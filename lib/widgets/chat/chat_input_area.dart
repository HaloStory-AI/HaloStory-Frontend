import 'package:flutter/material.dart';
import '../../services/localization_service.dart';
import '../../utils/chat_helpers.dart';

class ChatInputArea extends StatelessWidget {
  final bool isGroup;
  final Widget? leadingAvatar;
  final VoidCallback? onToggleCharacterMenu;
  final TextEditingController messageController;
  final String hintText;
  final bool isSendEnabled;
  final VoidCallback onSend;
  final bool isSystemNoteOpen;
  final bool isPersonaOpen;
  final VoidCallback? onToggleSystemNote;
  final VoidCallback? onTogglePersona;
  final bool hasSystemError;
  final VoidCallback? onRetry;
  final bool isStreaming;
  final VoidCallback? onStop;

  const ChatInputArea({
    super.key,
    required this.isGroup,
    this.leadingAvatar,
    this.onToggleCharacterMenu,
    required this.messageController,
    required this.hintText,
    required this.isSendEnabled,
    required this.onSend,
    required this.isSystemNoteOpen,
    required this.isPersonaOpen,
    this.onToggleSystemNote,
    this.onTogglePersona,
    this.hasSystemError = false,
    this.onRetry,
    this.isStreaming = false,
    this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final hasNoteToggle = onToggleSystemNote != null;
    final hasPersonaToggle = onTogglePersona != null;
    final anyOpen = isSystemNoteOpen || isPersonaOpen;

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
                      Container(
                        margin: const EdgeInsets.only(left: 4),
                        decoration:
                            const BoxDecoration(shape: BoxShape.circle),
                        child: IconButton(
                          onPressed: onToggleCharacterMenu,
                          icon: leadingAvatar ??
                              const Icon(Icons.person),
                          iconSize: 34,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 34,
                            minHeight: 34,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ] else ...[
                      if (hasNoteToggle || hasPersonaToggle)
                        _buildPopupMenuButton(context, colorScheme, anyOpen),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: hasSystemError
                          ? _buildRetryPrompt(context, colorScheme)
                          : _buildTextField(context, colorScheme),
                    ),
                    const SizedBox(width: 4),
                    if (isGroup && (hasNoteToggle || hasPersonaToggle))
                      _buildPopupMenuButton(context, colorScheme, anyOpen),
                    _buildSendOrRetryButton(colorScheme),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  tr('chat_fictional_disclaimer'),
                  textAlign: TextAlign.center,
                  style: (Theme.of(context).textTheme.labelSmall ?? const TextStyle(fontSize: 10)).copyWith(color: subtitleColor(context), fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(BuildContext context, ColorScheme colorScheme) {
    final textTheme = Theme.of(context).textTheme;
    return TextField(
      controller: messageController,
      style: (textTheme.bodyMedium ?? const TextStyle(fontSize: 14)).copyWith(color: colorScheme.onSurface),
      decoration: InputDecoration(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        hintText: hintText,
        hintStyle: (textTheme.bodyMedium ?? const TextStyle(fontSize: 14)).copyWith(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(50),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(50),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(50),
          borderSide: BorderSide.none,
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      onSubmitted: (_) {
        if (isSendEnabled) {
          onSend();
        }
      },
    );
  }

  Widget _buildRetryPrompt(BuildContext context, ColorScheme colorScheme) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(50),
      ),
      child: Text(
        tr('chat_retry_prompt'),
        style: (textTheme.bodyMedium ?? const TextStyle(fontSize: 14)).copyWith(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildSendOrRetryButton(ColorScheme colorScheme) {
    if (hasSystemError) {
      return Padding(
        padding: const EdgeInsets.only(right: 4),
        child: IconButton(
          onPressed: onRetry,
          icon: Icon(Icons.refresh, color: colorScheme.primary),
          style: IconButton.styleFrom(minimumSize: const Size(40, 40)),
        ),
      );
    }
    if (isStreaming) {
      return Padding(
        padding: const EdgeInsets.only(right: 4),
        child: IconButton.filled(
          onPressed: onStop,
          icon: const Icon(Icons.stop_rounded),
          style: IconButton.styleFrom(backgroundColor: colorScheme.error, foregroundColor: colorScheme.onError, minimumSize: const Size(40, 40)),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: IconButton.filled(
        onPressed: isSendEnabled ? onSend : null,
        icon: const Icon(Icons.send_rounded),
        style: IconButton.styleFrom(minimumSize: const Size(40, 40)),
      ),
    );
  }

  Widget _buildPopupMenuButton(
      BuildContext context, ColorScheme colorScheme, bool anyOpen) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'system_note') {
          onToggleSystemNote?.call();
        } else if (value == 'persona') {
          onTogglePersona?.call();
        }
      },
      icon: Icon(
        anyOpen ? Icons.sticky_note_2 : Icons.sticky_note_2_outlined,
        color: anyOpen
            ? colorScheme.primary
            : colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
      ),
      iconSize: 22,
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'system_note',
          child: Row(
            children: [
              Icon(
                isSystemNoteOpen
                    ? Icons.check_box
                    : Icons.check_box_outline_blank,
                size: 18,
                color: colorScheme.onSurface,
              ),
              const SizedBox(width: 8),
              Text(
                tr('chat_system_note'),
                style: TextStyle(color: colorScheme.onSurface),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'persona',
          child: Row(
            children: [
              Icon(
                isPersonaOpen
                    ? Icons.check_box
                    : Icons.check_box_outline_blank,
                size: 18,
                color: colorScheme.onSurface,
              ),
              const SizedBox(width: 8),
              Text(
                tr('chat_persona'),
                style: TextStyle(color: colorScheme.onSurface),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
