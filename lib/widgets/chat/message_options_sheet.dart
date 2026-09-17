import 'package:flutter/material.dart';
import '../../services/localization_service.dart';

Future<void> showMessageOptionsSheet({
  required BuildContext context,
  required String content,
  required bool canRegenerate,
  required VoidCallback onRegenerate,
  required VoidCallback onRewind,
  required VoidCallback onCopy,
  required VoidCallback onEdit,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: scheme.outlineVariant, borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 16),
              if (canRegenerate) ...[
                ListTile(
                leading: CircleAvatar(
                  backgroundColor: scheme.primaryContainer,
                  child: Icon(
                    Icons.refresh_rounded,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                title: const Text(
                  'Regenerate Response',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Retry getting a new answer from the AI',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  onRegenerate();
                },
              ),
              const Divider(height: 1),
            ],
            ListTile(
              leading: CircleAvatar(
                backgroundColor: scheme.secondaryContainer,
                child: Icon(
                  Icons.fast_rewind_rounded,
                  color: scheme.onSecondaryContainer,
                ),
              ),
              title: Text(
                tr('chat_rewind_title'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                tr('chat_rewind_subtitle'),
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                onRewind();
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: scheme.primaryContainer,
                child: Icon(
                  Icons.copy_rounded,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              title: Text(
                tr('chat_copy_text'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              onTap: () {
                Navigator.pop(ctx);
                onCopy();
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: scheme.tertiaryContainer,
                child: Icon(
                  Icons.edit_rounded,
                  color: scheme.onTertiaryContainer,
                ),
              ),
              title: Text(
                tr('chat_edit_message'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              onTap: () {
                Navigator.pop(ctx);
                onEdit();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
      );
    },
  );
}
