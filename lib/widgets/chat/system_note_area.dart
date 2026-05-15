import 'package:flutter/material.dart';
import '../../services/localization_service.dart';
import '../../utils/chat_theme_helpers.dart';

class SystemNoteArea extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onClose;
  final VoidCallback onChanged;

  const SystemNoteArea({
    super.key,
    required this.controller,
    required this.onClose,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      decoration: BoxDecoration(
        color: surfaceBackground(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fieldBorderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  tr('chat_system_note'),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                GestureDetector(
                  onTap: onClose,
                  child: Icon(
                    Icons.close,
                    color: subtitleColor(context),
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
          TextField(
            controller: controller,
            maxLines: 3,
            minLines: 1,
            style: TextStyle(color: titleColor(context), fontSize: 13),
            onChanged: (_) => onChanged(),
            decoration: InputDecoration(
              hintText: tr('chat_system_note_hint'),
              hintStyle: TextStyle(color: hintColor(context), fontSize: 12),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
