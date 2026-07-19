import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants.dart';
import '../../services/localization_service.dart';
import '../../services/auth_service.dart';
import '../../services/local_chat_service.dart';
import '../../services/security_service.dart';
import '../qr_host_screen.dart';
import '../qr_scanner_screen.dart';
import '../splash_screen.dart';
import '../../services/local_backup_service.dart';

class BackupSettingsPage extends StatefulWidget {
  final bool isDesktop;

  const BackupSettingsPage({super.key, this.isDesktop = false});

  @override
  State<BackupSettingsPage> createState() => _BackupSettingsPageState();
}

class _BackupSettingsPageState extends State<BackupSettingsPage> {
  final AuthService _authService = AuthService();

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
            // ── P2P Sync Section ──
            Text(
              tr('settings_tab_p2p_title'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF135ACF),
              ),
            ),
            const SizedBox(height: 8),
            Text(tr('settings_tab_p2p_desc')),
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              color: const Color(0xFFFFF7E6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    if (!kIsWeb &&
                        (Platform.isWindows ||
                            Platform.isMacOS ||
                            Platform.isLinux)) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => QrHostScreen(
                                  mode: 'download',
                                  getDownloadPayload: _getBackupPayload,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.qr_code_2),
                          label: Text(tr('settings_p2p_btn_copy_to_mobile')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
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
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => QrHostScreen(
                                  mode: 'upload',
                                  onUploadReceived: (payload) async {
                                    await _processRestorePayload(payload);
                                    if (mounted) {
                                      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                                        MaterialPageRoute(
                                          builder: (_) => const SplashScreen(),
                                        ),
                                        (route) => false,
                                      );
                                    }
                                  },
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.qr_code_scanner),
                          label:
                              Text(tr('settings_p2p_btn_receive_from_mobile')),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.orange),
                            foregroundColor: Colors.orange,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final payload = await _getBackupPayload();
                            if (mounted) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => QrScannerScreen(
                                    mode: 'upload',
                                    payloadToUpload: payload,
                                    onComplete: (_) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            tr('settings_p2p_success_mobile'),
                                          ),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.upload_file),
                          label:
                              Text(tr('settings_p2p_btn_copy_to_desktop')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
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
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => QrScannerScreen(
                                  mode: 'download',
                                  onComplete: (payload) async {
                                    if (payload != null) {
                                      await _processRestorePayload(payload);
                                      if (mounted) {
                                        Navigator.of(context, rootNavigator: true)
                                            .pushAndRemoveUntil(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const SplashScreen(),
                                          ),
                                          (route) => false,
                                        );
                                      }
                                    }
                                  },
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.download),
                          label: Text(
                              tr('settings_p2p_btn_receive_from_desktop')),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.orange),
                            foregroundColor: Colors.orange,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // ── Local Backup Section ──
            if (!kIsWeb) ...[
              const SizedBox(height: 32),
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
                            padding:
                                const EdgeInsets.symmetric(vertical: 16),
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
                            padding:
                                const EdgeInsets.symmetric(vertical: 16),
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
            ],

            const SizedBox(height: 32),

            // ── Cloud Backup Section ──
            Text(
              tr('settings_backup_title'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tr('settings_backup_desc'),
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
                        onPressed: _backupData,
                        icon: const Icon(Icons.cloud_upload),
                        label: Text(tr('settings_btn_backup')),
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
                        onPressed: _restoreData,
                        icon: const Icon(Icons.cloud_download),
                        label: Text(tr('settings_btn_restore')),
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

  // ── Backup / Restore Methods ──

  Future<Map<String, dynamic>> _getBackupPayload() async {
    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys();
    final Map<String, dynamic> settingsData = {};

    for (String key in allKeys) {
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
    for (String key in allKeys) {
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

  Future<void> _backupData() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('settings_backup_title')),
        content: Text(tr('settings_backup_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Backup'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    String? errorMsg;

    await _runWithLoadingOverlay(
      message: tr('settings_backup_loading'),
      task: () async {
        try {
          final fullPayload = await _getBackupPayload();
          final plainJson = jsonEncode(fullPayload);
          final encryptedJson = SecurityService.encryptData(plainJson);
          final token = await _authService.getToken();

          final response = await http.post(
            Uri.parse('${AppConstants.apiUrl}/user/backup'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'data': encryptedJson}),
          );

          if (response.statusCode != 200) {
            errorMsg = 'Backup failed: ${response.statusCode}';
          }
        } catch (e) {
          errorMsg = 'Error: $e';
        }
      },
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(errorMsg ?? tr('settings_backup_success')),
        backgroundColor: errorMsg == null ? Colors.green : Colors.red,
      ),
    );
  }

  Future<void> _restoreData() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('settings_backup_title')),
        content: Text(tr('settings_restore_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    bool success = false;
    String? errorMsg;
    bool hasData = false;

    await _runWithLoadingOverlay(
      message: tr('settings_restore_loading'),
      task: () async {
        try {
          final token = await _authService.getToken();
          final response = await http.get(
            Uri.parse('${AppConstants.apiUrl}/user/restore'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          );

          if (response.statusCode == 200) {
            final Map<String, dynamic> responseBody = jsonDecode(response.body);
            if (responseBody['success'] == true && responseBody['data'] != null) {
              hasData = true;
              final String encryptedData = responseBody['data'];
              final String plainJson =
                  SecurityService.decryptData(encryptedData);
              final Map<String, dynamic> fullPayload = jsonDecode(plainJson);

              if (fullPayload.containsKey('settings')) {
                final Map<String, dynamic> settings = fullPayload['settings'];
                final prefs = await SharedPreferences.getInstance();
                for (var entry in settings.entries) {
                  final k = entry.key;
                  final v = entry.value;
                  if (v is double) {
                    await prefs.setDouble(k, v);
                  } else if (v is int) {
                    await prefs.setInt(k, v);
                  } else if (v is String) {
                    await prefs.setString(k, v);
                  } else if (v is bool) {
                    await prefs.setBool(k, v);
                  }
                }
              }

              if (fullPayload.containsKey('chats')) {
                final Map<String, dynamic> chats = fullPayload['chats'];
                final chatService = LocalChatService();
                for (var entry in chats.entries) {
                  final id = entry.key;
                  final messages =
                      List<Map<String, dynamic>>.from(entry.value);
                  await chatService.saveChat(id, messages);
                }
              }

              if (fullPayload.containsKey('summaries')) {
                final Map<String, dynamic> summaries = fullPayload['summaries'];
                final chatService = LocalChatService();
                for (var entry in summaries.entries) {
                  final id = entry.key;
                  final summaryMap = Map<String, dynamic>.from(entry.value);
                  final properSummaries = summaryMap.map(
                    (k, v) => MapEntry(int.parse(k), v.toString()),
                  );
                  await chatService.saveSummaries(id, properSummaries);
                }
              }

              success = true;
            } else {
              errorMsg = tr('settings_restore_fail');
            }
          } else {
            errorMsg = tr('settings_restore_fail');
          }
        } catch (e) {
          errorMsg = 'Restore Error: $e';
        }
      },
    );

    if (!mounted) return;

    if (success && hasData) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('settings_restore_success')),
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
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Backup'),
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
        } catch (e) {
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
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final String? encryptedData = await LocalBackupService.pickBackup();
    if (encryptedData == null) return;

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
          content: Text(errorMsg ?? 'Restore failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
