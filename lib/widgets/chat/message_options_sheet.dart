import 'package:flutter/material.dart';
import '../../services/localization_service.dart';
import '../../utils/chat_theme_helpers.dart';

class MessageOptionsSheet extends StatelessWidget {
  final bool canRegenerate;
  final VoidCallback onRegenerate;
  final VoidCallback onRewind;
  final VoidCallback onCopy;
  final VoidCallback onEdit;

  const MessageOptionsSheet({
    super.key,
    required this.canRegenerate,
    required this.onRegenerate,
    required this.onRewind,
    required this.onCopy,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: surfaceBackground(context),
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
              color: Theme.of(context).dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          if (canRegenerate) ...[
            ListTile(
              leading: CircleAvatar(
                backgroundColor: scheme.primaryContainer,
                child: Icon(
                  Icons.refresh_rounded,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              title: Text(
                tr('chat_regenerate_response'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                tr('chat_regenerate_subtitle'),
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
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
              Navigator.pop(context);
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
              Navigator.pop(context);
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
              Navigator.pop(context);
              onEdit();
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
