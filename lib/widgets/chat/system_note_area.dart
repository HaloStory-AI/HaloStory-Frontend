import 'package:flutter/material.dart';
import '../../services/localization_service.dart';
import '../../utils/chat_helpers.dart';

class SystemNoteArea extends StatelessWidget {
  final bool isOpen;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;

  const SystemNoteArea({
    super.key,
    required this.isOpen,
    required this.controller,
    required this.onChanged,
    required this.onClose,
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
            onChanged: onChanged,
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

class SystemNoteIconButton extends StatelessWidget {
  final bool isOpen;
  final VoidCallback onToggle;

  const SystemNoteIconButton({
    super.key,
    required this.isOpen,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return IconButton(
      onPressed: onToggle,
      icon: Icon(
        isOpen ? Icons.sticky_note_2 : Icons.sticky_note_2_outlined,
        color: isOpen
            ? colorScheme.primary
            : colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
      ),
      iconSize: 22,
      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
      padding: const EdgeInsets.all(4),
    );
  }
}
