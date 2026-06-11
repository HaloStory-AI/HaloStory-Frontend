import 'package:flutter/material.dart';
import '../../services/localization_service.dart';
import '../../utils/chat_helpers.dart';
import 'system_note_area.dart';

class ChatInputArea extends StatelessWidget {
  final bool isGroup;
  final Widget? leadingAvatar;
  final VoidCallback? onToggleCharacterMenu;
  final TextEditingController messageController;
  final String hintText;
  final bool isSendEnabled;
  final VoidCallback onSend;
  final bool isSystemNoteOpen;
  final VoidCallback? onToggleSystemNote;

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
    this.onToggleSystemNote,
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
                      if (onToggleSystemNote != null)
                        SystemNoteIconButton(
                          isOpen: isSystemNoteOpen,
                          onToggle: onToggleSystemNote!,
                        ),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: TextField(
                        controller: messageController,
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest,
                          hintText: hintText,
                          hintStyle: TextStyle(
                            color:
                                colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.7,
                            ),
                            fontSize: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(50),
                            borderSide: const BorderSide(
                              color: Colors.transparent,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(50),
                            borderSide: const BorderSide(
                              color: Colors.transparent,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(50),
                            borderSide: const BorderSide(
                              color: Colors.transparent,
                            ),
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                        ),
                        onSubmitted: (_) {
                          if (isSendEnabled) {
                            onSend();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 4),
                    if (isGroup && onToggleSystemNote != null) ...[
                      SystemNoteIconButton(
                        isOpen: isSystemNoteOpen,
                        onToggle: onToggleSystemNote!,
                      )
                    ],
                    GestureDetector(
                      onTap: isSendEnabled ? onSend : null,
                      child: Container(
                        margin: const EdgeInsets.only(right: 4),
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          Icons.send,
                          color: isSendEnabled
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant.withValues(
                                  alpha: 0.5,
                                ),
                          size: 24,
                        ),
                      ),
                    ),
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
}
