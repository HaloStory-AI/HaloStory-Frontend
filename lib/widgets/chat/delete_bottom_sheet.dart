import 'package:flutter/material.dart';
import '../../services/localization_service.dart';

Future<String?> showDeleteChatSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (context) {
      final cs = Theme.of(context).colorScheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  tr('chat_delete_sheet_title'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: cs.onSurface),
                ),
              ),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(Icons.delete_forever, color: cs.error),
              title: Text(tr('chat_delete_option_all'), style: TextStyle(color: cs.error)),
              onTap: () => Navigator.pop(context, 'delete_all'),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: cs.tertiary),
              title: Text(tr('chat_delete_option_chat_only'), style: TextStyle(color: cs.tertiary)),
              onTap: () => Navigator.pop(context, 'delete_chat_only'),
            ),
            ListTile(
              leading: Icon(Icons.cancel_outlined, color: cs.primary),
              title: Text(tr('chat_delete_option_cancel'), style: TextStyle(color: cs.primary)),
              onTap: () => Navigator.pop(context, 'cancel'),
            ),
          ],
        ),
      ),
      );
    },
  );
}
