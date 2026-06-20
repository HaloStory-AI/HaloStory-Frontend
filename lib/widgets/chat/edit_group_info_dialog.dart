import 'package:flutter/material.dart';

Future<({String name, String bio})?> showEditGroupInfoDialog({
  required BuildContext context,
  required String initialName,
  required String initialBio,
}) async {
  final nameController = TextEditingController(text: initialName);
  final bioController = TextEditingController(text: initialBio);

  final shouldSave = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Edit Group Info'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Group name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bioController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Group bio',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Save'),
          ),
        ],
      );
    },
  );

  if (shouldSave != true) return null;

  final newName = nameController.text.trim();
  final newBio = bioController.text.trim();

  if (newName.isEmpty) {
    if (!context.mounted) return null;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Group name cannot be empty.')),
    );
    return null;
  }

  return (name: newName, bio: newBio);
}
