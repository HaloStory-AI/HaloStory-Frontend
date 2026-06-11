import 'package:flutter/material.dart';
import '../../services/localization_service.dart';

Future<String?> showDeleteChatSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    builder: (context) {
      final cs = Theme.of(context).colorScheme;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              child: Text(
                tr('chat_delete_sheet_title'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(
                Icons.delete_forever,
                color: Colors.red.shade400,
              ),
              title: Text(
                tr('chat_delete_option_all'),
                style: TextStyle(color: Colors.red.shade400),
              ),
              onTap: () => Navigator.pop(context, 'delete_all'),
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Colors.orange.shade400,
              ),
              title: Text(
                tr('chat_delete_option_chat_only'),
                style: TextStyle(color: Colors.orange.shade400),
              ),
              onTap: () => Navigator.pop(context, 'delete_chat_only'),
            ),
            ListTile(
              leading: Icon(
                Icons.cancel_outlined,
                color: Colors.blue.shade400,
              ),
              title: Text(
                tr('chat_delete_option_cancel'),
                style: TextStyle(color: Colors.blue.shade400),
              ),
              onTap: () => Navigator.pop(context, 'cancel'),
            ),
          ],
        ),
      );
    },
  );
}
