import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Theme.of(ctx).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (canRegenerate) ...[
              ListTile(
                tileColor: Colors.transparent,
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
              tileColor: Colors.transparent,
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
              tileColor: Colors.transparent,
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
              tileColor: Colors.transparent,
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
      );
    },
  );
}
