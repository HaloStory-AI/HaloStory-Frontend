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
                  title ?? tr('chat_system_note'),
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
            maxLength: maxLength,
            style: TextStyle(color: titleColor(context), fontSize: 13),
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: hintText ?? tr('chat_system_note_hint'),
              hintStyle: TextStyle(color: hintColor(context), fontSize: 12),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              counterStyle: TextStyle(
                color: subtitleColor(context),
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
