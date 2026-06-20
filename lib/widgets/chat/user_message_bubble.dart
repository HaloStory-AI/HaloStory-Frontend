import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;

class UserMessageBubble extends StatelessWidget {
  final String content;
  final String? timestampStr;
  final String? status;
  final double maxWidth;

  const UserMessageBubble({
    super.key,
    required this.content,
    this.timestampStr,
    this.status,
    required this.maxWidth,
  });

  Widget _buildStatusIcon() {
    if (status == 'sending') {
      return const Icon(Icons.access_time, size: 12, color: Colors.white);
    } else if (status == 'sent') {
      return const Icon(Icons.check, size: 14, color: Colors.white);
    } else if (status == 'processing' || status == 'completed') {
      return const Icon(Icons.done_all, size: 14, color: Colors.white);
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: BoxConstraints(maxWidth: maxWidth),
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
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (timestampStr != null)
                    Text(
                      timestampStr!,
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onPrimary.withValues(alpha: 0.7),
                      ),
                    ),
                  if (timestampStr != null) const SizedBox(width: 4),
                  if (status != null) _buildStatusIcon(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
