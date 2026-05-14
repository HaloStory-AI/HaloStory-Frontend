import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import '../../utils/chat_theme_helpers.dart';

class UserBubble extends StatelessWidget {
  final String content;
  final DateTime? timestamp;
  final String? status;

  const UserBubble({
    super.key,
    required this.content,
    this.timestamp,
    this.status,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (timestamp != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4, right: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formatMessageTime(timestamp),
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (status != null) ...[
                    const SizedBox(width: 4),
                    _buildStatusIcon(colorScheme),
                  ],
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(0),
                ),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.7,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    MarkdownBody(
                      data: content,
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
                          color: colorScheme.onPrimary,
                          fontSize: 14,
                        ),
                        strong: TextStyle(
                          color: colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                        em: TextStyle(
                          color: colorScheme.onPrimary.withValues(alpha: 0.86),
                          fontStyle: FontStyle.italic,
                        ),
                        listBullet: TextStyle(color: colorScheme.onPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(ColorScheme colorScheme) {
    if (status == 'sending') {
      return Icon(
        Icons.access_time,
        size: 12,
        color: colorScheme.onSurfaceVariant,
      );
    } else if (status == 'sent') {
      return Icon(Icons.check, size: 14, color: colorScheme.onSurfaceVariant);
    } else if (status == 'processing' || status == 'completed') {
      return Icon(Icons.done_all, size: 14, color: colorScheme.primary);
    }
    return const SizedBox.shrink();
  }
}
