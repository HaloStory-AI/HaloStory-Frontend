import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/localization_service.dart';
import '../../services/local_chat_service.dart';
import '../../services/security_service.dart';
import '../../services/local_backup_service.dart';
import '../splash_screen.dart';

class BackupSettingsPage extends StatefulWidget {
  final bool isDesktop;

  const BackupSettingsPage({super.key, this.isDesktop = false});

  @override
  State<BackupSettingsPage> createState() => _BackupSettingsPageState();
}

class _BackupSettingsPageState extends State<BackupSettingsPage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;
    final Color textColor = colorScheme.onSurface;

    return Scaffold(
      appBar: widget.isDesktop
          ? null
          : AppBar(
              title: Text(
                tr('settings_tab_backup'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              tr('settings_local_backup_title'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tr('settings_local_backup_desc'),
              style: TextStyle(color: textColor.withValues(alpha: 0.8)),
            ),
            const SizedBox(height: 24),
            Card(
              elevation: 0,
              color: isDark
                  ? colorScheme.surface
                  : colorScheme.surfaceContainerHighest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _localBackup,
                        icon: const Icon(Icons.save_alt),
                        label: Text(tr('settings_btn_local_backup')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _localRestore,
                        icon: const Icon(Icons.folder_open),
                        label: Text(tr('settings_btn_local_restore')),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: colorScheme.primary),
                          foregroundColor: colorScheme.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? colorScheme.surface
                    : colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_outline, size: 20, color: colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('settings_local_backup_title'),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: textColor,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '.hsai • ${tr('settings_local_backup_desc')}',
                          style: TextStyle(
                            color: textColor.withValues(alpha: 0.7),
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── Helper ──

  Future<T> _runWithLoadingOverlay<T>({
    required Future<T> Function() task,
    required String message,
  }) async {
    final loading = showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: Center(
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  Text(message, textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    try {
      return await task();
    } finally {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      await loading;
    }
  }

  // ── Payload helpers ──

  Future<Map<String, dynamic>> _getBackupPayload() async {
    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys();
    final Map<String, dynamic> settingsData = {};

    for (final key in allKeys) {
      if (key.startsWith('ai_') ||
          key.startsWith('byok_') ||
          key.startsWith('byom_') ||
          key == 'default_provider' ||
          key == 'app_language' ||
          key == 'app_theme_mode') {
        settingsData[key] = prefs.get(key);
      }
    }

    final Map<String, dynamic> chatData = {};
    final Map<String, dynamic> summaryData = {};

    final chatService = LocalChatService();
    final metadata = await chatService.getAllChatMetadata();
    final pinnedChats = await chatService.getPinnedChats();

    for (var meta in metadata) {
      final id = meta['id'].toString();
      final messages = await chatService.loadChat(id);
      final summaries = await chatService.loadSummaries(id);

      chatData[id] = messages;
      summaryData[id] = summaries.map((k, v) => MapEntry(k.toString(), v));
    }

    return {
      'settings': settingsData,
      'chats': chatData,
      'summaries': summaryData,
      'pinned_chats': pinnedChats,
      'exported_at': DateTime.now().toIso8601String(),
    };
  }

  Future<void> _processRestorePayload(Map<String, dynamic> fullPayload) async {
    final prefs = await SharedPreferences.getInstance();
    final chatService = LocalChatService();

    final allKeys = prefs.getKeys();
    for (final key in allKeys) {
      if (key.startsWith('ai_') ||
          key.startsWith('byok_') ||
          key.startsWith('byom_')) {
        await prefs.remove(key);
      }
    }

    final metadataList = await chatService.getAllChatMetadata();
    for (var meta in metadataList) {
      await chatService.deleteChat(meta['id'].toString());
    }

    if (fullPayload.containsKey('settings')) {
      final Map<String, dynamic> stData = fullPayload['settings'];
      for (var entry in stData.entries) {
        final k = entry.key;
        if (entry.value is String) await prefs.setString(k, entry.value);
        if (entry.value is int) await prefs.setInt(k, entry.value);
        if (entry.value is double) await prefs.setDouble(k, entry.value);
        if (entry.value is bool) await prefs.setBool(k, entry.value);
      }
    }

    if (fullPayload.containsKey('chats')) {
      final Map<String, dynamic> ctData = fullPayload['chats'];
      for (var entry in ctData.entries) {
        final chatId = entry.key;
        final msgs = List<Map<String, dynamic>>.from(entry.value);
        await chatService.saveChat(chatId, msgs);
      }
    }

    if (fullPayload.containsKey('summaries')) {
      final Map<String, dynamic> smData = fullPayload['summaries'];
      for (var entry in smData.entries) {
        final chatId = entry.key;
        final sumMapStr = Map<String, dynamic>.from(entry.value);
        final sumMapInt = sumMapStr.map(
          (k, v) => MapEntry(int.parse(k), v.toString()),
        );
        await chatService.saveSummaries(chatId, sumMapInt);
      }
    }

    if (fullPayload.containsKey('pinned_chats')) {
      final List<dynamic> pins = fullPayload['pinned_chats'];
      await chatService.savePinnedChats(List<String>.from(pins));
    }
  }

  // ── Local Backup / Restore ──

  Future<void> _localBackup() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('settings_local_backup_title')),
        content: Text(tr('settings_local_backup_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('btn_cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('settings_btn_local_backup')),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    bool saved = false;

    await _runWithLoadingOverlay(
      message: tr('settings_local_backup_loading'),
      task: () async {
        try {
          final fullPayload = await _getBackupPayload();
          final plainJson = jsonEncode(fullPayload);
          final encryptedData = SecurityService.encryptData(plainJson);

          saved = await LocalBackupService.saveBackup(encryptedData);
        } catch (_) {
          // ignore
        }
      },
    );

    if (!mounted) return;
    if (saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('settings_local_backup_success')),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _localRestore() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('settings_local_backup_title')),
        content: Text(tr('settings_local_restore_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('btn_cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('settings_btn_local_restore')),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final String? encryptedData = await LocalBackupService.pickBackup();
    if (encryptedData == null) return;
    if (!mounted) return;

    bool success = false;
    String? errorMsg;

    await _runWithLoadingOverlay(
      message: tr('settings_local_restore_loading'),
      task: () async {
        try {
          final plainJson = SecurityService.decryptData(encryptedData);
          final Map<String, dynamic> fullPayload = jsonDecode(plainJson);
          await _processRestorePayload(fullPayload);
          success = true;
        } catch (e) {
          errorMsg = 'Restore Error: $e';
        }
      },
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('settings_local_restore_success')),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const SplashScreen(),
        ),
        (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg ?? tr('settings_restore_fail')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
