import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import '../../utils/chat_helpers.dart';
import 'dot_animation.dart';

class BotMessageBubble extends StatelessWidget {
  final String content;
  final String? timestampStr;
  final int? visibleParts;
  final bool isTypingNext;
  final bool hideItalics;
  final double maxWidth;
  final String botName;
  final String? botAvatarUrl;
  final Color botColor;
  final Color titleTextColor;
  final Color timestampColor;
  final Color bubbleBgColor;

  const BotMessageBubble({
    super.key,
    required this.content,
    this.timestampStr,
    this.visibleParts,
    this.isTypingNext = false,
    required this.hideItalics,
    required this.maxWidth,
    required this.botName,
    this.botAvatarUrl,
    required this.botColor,
    required this.titleTextColor,
    required this.timestampColor,
    required this.bubbleBgColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final parts = content
        .split('\n\n')
        .where((s) => s.trim().isNotEmpty)
        .toList();
    if (parts.isEmpty) return const SizedBox.shrink();

    final partsToRender = visibleParts != null
        ? parts.take(visibleParts!).toList()
        : parts;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: botColor,
            backgroundImage: botAvatarUrl != null
                ? NetworkImage(botAvatarUrl!)
                : null,
            child: botAvatarUrl == null
                ? Text(
                    botName[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  botName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: titleTextColor,
                  ),
                ),
                const SizedBox(height: 6),
                ...partsToRender.asMap().entries.map((entry) {
                  int idx = entry.key;
                  String part = entry.value;
                  bool isFirst = idx == 0;

                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: idx == partsToRender.length - 1 ? 0 : 4,
                    ),
                    child: IntrinsicWidth( // <-- PERUBAHAN DI SINI
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: bubbleBgColor,
                          borderRadius: BorderRadius.only(
                            topLeft: isFirst
                                ? const Radius.circular(2)
                                : const Radius.circular(12),
                            topRight: const Radius.circular(12),
                            bottomLeft: const Radius.circular(12),
                            bottomRight: const Radius.circular(12),
                          ),
                        ),
                        constraints: BoxConstraints(maxWidth: maxWidth),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            MarkdownBody(
                              data: filterItalics(part, hideItalics),
                              selectable: false,
                              extensionSet: md.ExtensionSet(
                                md.ExtensionSet.gitHubFlavored.blockSyntaxes,
                                <md.InlineSyntax>[
                                  md.EmojiSyntax(),
                                  ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
                                ],
                              ),
                              styleSheet: MarkdownStyleSheet(
                                p: TextStyle(
                                  color: colorScheme.onSurface,
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                                strong: TextStyle(
                                  color: colorScheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                ),
                                em: TextStyle(
                                  color: colorScheme.onSurface.withValues(
                                    alpha: 0.86,
                                  ),
                                  fontStyle: FontStyle.italic,
                                ),
                                code: TextStyle(
                                  color: colorScheme.primary,
                                  backgroundColor: colorScheme.surfaceContainer,
                                  fontSize: 14,
                                ),
                                codeblockDecoration: BoxDecoration(
                                  color: colorScheme.surfaceContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                listBullet: TextStyle(
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ),
                            if (timestampStr != null &&
                                idx == partsToRender.length - 1)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    timestampStr!,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: timestampColor,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                if (isTypingNext)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: bubbleBgColor,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                          bottomLeft: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DotAnim(delay: 0),
                          SizedBox(width: 4),
                          DotAnim(delay: 0.2),
                          SizedBox(width: 4),
                          DotAnim(delay: 0.4),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
