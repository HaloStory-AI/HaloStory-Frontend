import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../utils/chat_helpers.dart';

class CompactCharacterMenu extends StatelessWidget {
  final List<Map<String, dynamic>> groupMembers;
  final String? selectedBotId;
  final void Function(String? id) onSelected;

  const CompactCharacterMenu({
    super.key,
    required this.groupMembers,
    required this.selectedBotId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: surfaceBackground(context),
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...groupMembers.map((member) {
                final memberId = member['bot_id']?.toString() ?? member['id']?.toString();
                final isSelected = selectedBotId == memberId;
                final color = parseColor(member['color']);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () => onSelected(memberId),
                    customBorder: const CircleBorder(),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: isSelected ? color : Colors.transparent, width: 2.5),
                      ),
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: color,
                        backgroundImage: member['image_url'] != null
                            ? CachedNetworkImageProvider(member['image_url'])
                            : (member['avatar'] != null ? CachedNetworkImageProvider(member['avatar']) : null),
                        child: (member['image_url'] == null && member['avatar'] == null)
                            ? Text((member['name'] as String)[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold))
                            : null,
                      ),
                    ),
                  ),
                );
              }),
              InkWell(
                onTap: () => onSelected('random'),
                customBorder: const CircleBorder(),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: selectedBotId == 'random' ? cs.tertiary : Colors.transparent, width: 2.5),
                  ),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: selectedBotId == 'random' ? cs.tertiaryContainer : Colors.transparent,
                    child: Icon(Icons.shuffle, size: 22, color: selectedBotId == 'random' ? cs.onTertiaryContainer : cs.onSurfaceVariant),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
