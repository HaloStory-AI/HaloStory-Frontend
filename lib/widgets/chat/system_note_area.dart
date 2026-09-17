import 'package:flutter/material.dart';
import '../../services/localization_service.dart';
import '../../utils/chat_helpers.dart';

class SystemNoteArea extends StatelessWidget {
  final bool isOpen;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;
  final String? title;
  final String? hintText;
  final int? maxLength;

  const SystemNoteArea({
    super.key,
    required this.isOpen,
    required this.controller,
    required this.onChanged,
    required this.onClose,
    this.title,
    this.hintText,
    this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    if (!isOpen) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Card.outlined(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      color: surfaceBackground(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: fieldBorderColor(context))),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 0),
              child: Row(
                children: [
                  Expanded(child: Text(title ?? tr('chat_system_note'), style: (tt.labelSmall ?? const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)).copyWith(color: cs.primary))),
                  IconButton(onPressed: onClose, icon: Icon(Icons.close, color: subtitleColor(context), size: 18), style: IconButton.styleFrom(minimumSize: const Size(28, 28), tapTargetSize: MaterialTapTargetSize.shrinkWrap)),
                ],
              ),
            ),
            TextField(
              controller: controller,
              maxLines: 3,
              minLines: 1,
              maxLength: maxLength,
              style: (tt.bodySmall ?? const TextStyle(fontSize: 13)).copyWith(color: titleColor(context)),
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: hintText ?? tr('chat_system_note_hint'),
                hintStyle: (tt.bodySmall ?? const TextStyle(fontSize: 12)).copyWith(color: hintColor(context)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                counterStyle: (tt.labelSmall ?? const TextStyle(fontSize: 11)).copyWith(color: subtitleColor(context)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
