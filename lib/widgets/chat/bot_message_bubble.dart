import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import '../../utils/chat_helpers.dart';
import 'dot_animation.dart';

class BotMessageBubble extends StatelessWidget {
  final String content;
  final String? timestampStr;
  final int? visibleParts;
  final bool isTypingNext;
  final bool isStreaming;
  final bool hideItalics;
  final double maxWidth;
  final String botName;
  final String? botAvatarUrl;
  final Color botColor;
  final Color titleTextColor;
  final Color timestampColor;
  final Color bubbleBgColor;
  final VoidCallback? onCopy;
  final VoidCallback? onEdit;
  final VoidCallback? onRewind;
  final VoidCallback? onRegenerate;
  final bool canRegenerate;

  const BotMessageBubble({
    super.key,
    required this.content,
    this.timestampStr,
    this.visibleParts,
    this.isTypingNext = false,
    this.isStreaming = false,
    required this.hideItalics,
    required this.maxWidth,
    required this.botName,
    this.botAvatarUrl,
    required this.botColor,
    required this.titleTextColor,
    required this.timestampColor,
    required this.bubbleBgColor,
    this.onCopy,
    this.onEdit,
    this.onRewind,
    this.onRegenerate,
    this.canRegenerate = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
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
                ? CachedNetworkImageProvider(botAvatarUrl!)
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
                  style: (textTheme.titleSmall ?? const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)).copyWith(color: titleTextColor),
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
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: Card(
                        color: bubbleBgColor,
                        elevation: 0,
                        margin: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.only(
                            topLeft: isFirst
                                ? const Radius.circular(4)
                                : const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: const Radius.circular(16),
                            bottomRight: const Radius.circular(16),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
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
                                  p: (textTheme.bodyMedium ?? const TextStyle(fontSize: 14)).copyWith(color: colorScheme.onSurface, height: 1.4),
                                  strong: (textTheme.bodyMedium ?? const TextStyle()).copyWith(color: colorScheme.onSurface, fontWeight: FontWeight.bold),
                                  em: (textTheme.bodyMedium ?? const TextStyle()).copyWith(color: colorScheme.onSurface.withValues(alpha: 0.86), fontStyle: FontStyle.italic),
                                  code: (textTheme.bodySmall ?? const TextStyle(fontSize: 14)).copyWith(color: colorScheme.primary, backgroundColor: colorScheme.surfaceContainer),
                                  codeblockDecoration: BoxDecoration(
                                    color: colorScheme.surfaceContainer,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  listBullet: TextStyle(color: colorScheme.onSurface),
                                ),
                              ),
                              if (timestampStr != null &&
                                  idx == partsToRender.length - 1)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    timestampStr!,
                                    style: (textTheme.labelSmall ?? const TextStyle(fontSize: 11)).copyWith(color: timestampColor),
                                  ),
                                ),
                              if (idx == partsToRender.length - 1 && (onCopy != null || onEdit != null || onRewind != null || (canRegenerate && onRegenerate != null)))
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Wrap(
                                    spacing: 6,
                                    children: [
                                      if (onCopy != null)
                                        _bubbleAction(context, Icons.copy_rounded, onCopy!),
                                      if (onEdit != null)
                                        _bubbleAction(context, Icons.edit_rounded, onEdit!),
                                      if (onRewind != null)
                                        _bubbleAction(context, Icons.fast_rewind_rounded, onRewind!),
                                      if (canRegenerate && onRegenerate != null)
                                        _bubbleAction(context, Icons.refresh_rounded, onRegenerate!, isPrimary: true),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                if (isTypingNext || isStreaming)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Card(
                      color: bubbleBgColor,
                      elevation: 0,
                      margin: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const DotAnim(delay: 0),
                            const SizedBox(width: 4),
                            const DotAnim(delay: 0.2),
                            const SizedBox(width: 4),
                            const DotAnim(delay: 0.4),
                            if (isStreaming && !isTypingNext) ...[
                              const SizedBox(width: 8),
                              Container(width: 2, height: 14, color: colorScheme.primary),
                            ],
                          ],
                        ),
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

  Widget _bubbleAction(BuildContext context, IconData icon, VoidCallback onTap, {bool isPrimary = false}) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isPrimary ? cs.primaryContainer : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 14, color: isPrimary ? cs.onPrimaryContainer : cs.onSurfaceVariant),
      ),
    );
  }
}
