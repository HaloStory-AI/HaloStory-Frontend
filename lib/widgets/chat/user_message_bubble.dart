import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;

class UserMessageBubble extends StatelessWidget {
  final String content;
  final String? timestampStr;
  final String? status;
  final double maxWidth;
  final VoidCallback? onCopy;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const UserMessageBubble({
    super.key,
    required this.content,
    this.timestampStr,
    this.status,
    required this.maxWidth,
    this.onCopy,
    this.onEdit,
    this.onDelete,
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
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Card(
            color: colorScheme.primary,
            elevation: 0,
            margin: EdgeInsets.zero,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(4),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
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
                      p: (textTheme.bodyMedium ?? const TextStyle(fontSize: 14)).copyWith(color: Colors.white, height: 1.35),
                      strong: (textTheme.bodyMedium ?? const TextStyle()).copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                      em: (textTheme.bodyMedium ?? const TextStyle()).copyWith(color: Colors.white.withValues(alpha: 0.86), fontStyle: FontStyle.italic),
                      listBullet: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (timestampStr != null)
                        Text(
                          timestampStr!,
                          style: (textTheme.labelSmall ?? const TextStyle(fontSize: 11)).copyWith(color: Colors.white.withValues(alpha: 0.7)),
                        ),
                      if (timestampStr != null) const SizedBox(width: 4),
                      if (status != null) _buildStatusIcon(),
                    ],
                  ),
                  if (onCopy != null || onEdit != null || onDelete != null) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: [
                        if (onCopy != null)
                          InkWell(
                            onTap: onCopy,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.copy_rounded, size: 14, color: Colors.white),
                            ),
                          ),
                        if (onEdit != null)
                          InkWell(
                            onTap: onEdit,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.edit_rounded, size: 14, color: Colors.white),
                            ),
                          ),
                        if (onDelete != null)
                          InkWell(
                            onTap: onDelete,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.delete_outline_rounded, size: 14, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
