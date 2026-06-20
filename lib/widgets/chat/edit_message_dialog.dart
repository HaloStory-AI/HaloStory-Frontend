import 'package:flutter/material.dart';
import '../../services/localization_service.dart';

Future<void> showEditMessageDialog({
  required BuildContext context,
  required String initialContent,
  required Future<void> Function(String newContent) onSave,
}) async {
  final editController = TextEditingController(text: initialContent);

  await showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(tr('chat_edit_message')),
      content: TextField(
        controller: editController,
        maxLines: 10,
        minLines: 1,
        decoration: const InputDecoration(border: OutlineInputBorder()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(tr('btn_skip')),
        ),
        ElevatedButton(
          onPressed: () async {
            await onSave(editController.text);
            if (dialogContext.mounted) {
              Navigator.pop(dialogContext);
            }
          },
          child: Text(tr('settings_save_btn')),
        ),
      ],
    ),
  );

  editController.dispose();
}
