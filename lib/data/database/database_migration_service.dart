import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_message.dart';
import '../repositories/sqlite_chat_repository.dart';
import 'app_database.dart';

class MigrationProgress {
  final String phase;
  final int current;
  final int total;
  final String? currentFile;
  final String? errorMessage;

  const MigrationProgress({
    required this.phase,
    required this.current,
    required this.total,
    this.currentFile,
    this.errorMessage,
  });
}

class FailedItem {
  final String type;
  final String chatId;
  final String filePath;
  final String error;

  const FailedItem({
    required this.type,
    required this.chatId,
    required this.filePath,
    required this.error,
  });
}

class MigrationReport {
  final int chatsMigrated;
  final int messagesMigrated;
  final int summariesMigrated;
  final int pinnedMigrated;
  final List<String> errors;
  final bool stoppedEarly;
  final List<FailedItem> failedItems;

  const MigrationReport({
    this.chatsMigrated = 0,
    this.messagesMigrated = 0,
    this.summariesMigrated = 0,
    this.pinnedMigrated = 0,
    this.errors = const [],
    this.stoppedEarly = false,
    this.failedItems = const [],
  });

  bool get hasError => errors.isNotEmpty || failedItems.isNotEmpty;
  int get totalItems => chatsMigrated + messagesMigrated + summariesMigrated + pinnedMigrated;
}

class DatabaseMigrationService {
  static const _migrationDoneKey = 'sqlite_migration_done';
  static const _archiveSuffix = '_migrated';

  static Future<bool> isMigrationNeeded() async {
    if (kIsWeb) return false;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_migrationDoneKey) == true) return false;
    final path = await _getOldStoragePath();
    final dir = Directory(path);
    if (!await dir.exists()) return false;
    try {
      final files = dir.listSync().whereType<File>().where((f) {
        final name = p.basename(f.path);
        return f.path.endsWith('.json') &&
            !name.startsWith('pinned_chats') &&
            !name.endsWith('.summary.json') &&
            !name.endsWith('.tmp');
      });
      return files.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<MigrationReport> performMigration({
    void Function(MigrationProgress)? onProgress,
    List<FailedItem>? retryItems,
  }) async {
    if (kIsWeb) {
      return const MigrationReport();
    }

    final repo = SqliteChatRepository();
    final path = await _getOldStoragePath();
    final dir = Directory(path);

    if (!await dir.exists()) {
      return const MigrationReport();
    }

    int chats = 0;
    int messages = 0;
    int summaries = 0;
    int pins = 0;
    final errors = <String>[];
    final failedItems = <FailedItem>[];
    bool stoppedEarly = false;

    if (kDebugMode) debugPrint('DEBUG: Migration starting from: $path');

    try {
      // 1. Migrate pinned chats
      onProgress?.call(const MigrationProgress(
        phase: 'pinned', current: 0, total: 0, currentFile: null));
      final pinFile = File('$path/pinned_chats.json');
      List<String> pinnedIds = [];
      if (await pinFile.exists()) {
        if (retryItems == null || retryItems.any((i) => i.type == 'pinned')) {
          try {
            final pinContent = await pinFile.readAsString();
            pinnedIds = List<String>.from(jsonDecode(pinContent));
            await repo.savePinnedChats(pinnedIds);
            pins = pinnedIds.length;
          } catch (e) {
            failedItems.add(FailedItem(
              type: 'pinned', chatId: '', filePath: pinFile.path, error: e.toString()));
            errors.add('Failed to migrate pinned chats: $e');
            return MigrationReport(
              chatsMigrated: 0, messagesMigrated: 0,
              summariesMigrated: 0, pinnedMigrated: 0,
              errors: errors, stoppedEarly: true, failedItems: failedItems,
            );
          }
        }
      }

      // 2. Discover chat files
      List<File> allChatFiles;
      if (retryItems != null) {
        allChatFiles = retryItems
            .where((i) => i.type == 'chat')
            .map((i) => File(i.filePath))
            .where((f) => f.existsSync())
            .toList();
      } else {
        allChatFiles = dir.listSync().whereType<File>().where((f) {
          final name = f.uri.pathSegments.last;
          return f.path.endsWith('.json') &&
              !name.startsWith('pinned_chats') &&
              !name.endsWith('.summary.json') &&
              !name.endsWith('.tmp');
        }).toList();
      }
      if (kDebugMode) debugPrint('DEBUG: Found ${allChatFiles.length} chat files to migrate');
      onProgress?.call(MigrationProgress(
        phase: 'chats', current: 0, total: allChatFiles.length));

      // 3. Migrate each chat
      for (int i = 0; i < allChatFiles.length; i++) {
        final file = allChatFiles[i];
        final chatId = file.uri.pathSegments.last.replaceFirst('.json', '');
        if (kDebugMode) debugPrint('DEBUG: Migrating chat: $chatId');
        onProgress?.call(MigrationProgress(
          phase: 'chats', current: i + 1, total: allChatFiles.length, currentFile: chatId));
        try {
          final content = await file.readAsString();
          final decoded = jsonDecode(content);

          List<Map<String, dynamic>> messageList;
          if (decoded is List) {
            messageList = List<Map<String, dynamic>>.from(decoded);
          } else if (decoded is Map && decoded['messages'] is List) {
            messageList = List<Map<String, dynamic>>.from(decoded['messages']);
          } else {
            errors.add('Skipped $chatId: unknown format');
            continue;
          }

          final isGroup = chatId.startsWith('group_');
          final chatMessages = messageList
              .map((m) => ChatMessage.fromLegacyMap(chatId, m))
              .toList();

          final lastModified = file.lastModifiedSync();
          await repo.upsertChat(
            id: chatId,
            isGroup: isGroup,
            lastModified: lastModified,
          );

          for (final msg in chatMessages) {
            await repo.insertMessage(msg);
            messages++;
          }

          chats++;
        } catch (e) {
          failedItems.add(FailedItem(
            type: 'chat', chatId: chatId, filePath: file.path, error: e.toString()));
          errors.add('Failed to migrate chat $chatId: $e');
          stoppedEarly = true;
          onProgress?.call(MigrationProgress(
            phase: 'chats', current: i + 1, total: allChatFiles.length,
            currentFile: chatId, errorMessage: e.toString()));
          return MigrationReport(
            chatsMigrated: chats, messagesMigrated: messages,
            summariesMigrated: summaries, pinnedMigrated: pins,
            errors: errors, stoppedEarly: true, failedItems: failedItems,
          );
        }
      }

      // 4. Archive old folder
      onProgress?.call(const MigrationProgress(
        phase: 'archive', current: 0, total: 0));
      await _archiveOldFolder(path);
      if (kDebugMode) debugPrint('DEBUG: Old folder archived');

      // 5. Mark migration done
      onProgress?.call(const MigrationProgress(
        phase: 'finalize', current: 0, total: 0));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_migrationDoneKey, true);
      if (kDebugMode) debugPrint('DEBUG: Migration flag set');

    } catch (e) {
      errors.add('Migration failed: $e');
      failedItems.add(FailedItem(
        type: 'general', chatId: '', filePath: path, error: e.toString()));
      return MigrationReport(
        chatsMigrated: chats, messagesMigrated: messages,
        summariesMigrated: summaries, pinnedMigrated: pins,
        errors: errors, stoppedEarly: true, failedItems: failedItems,
      );
    }

    if (kDebugMode) {
      debugPrint('DEBUG: Migration finished — chats: $chats, msgs: $messages, '
          'summaries: $summaries, pins: $pins, errors: ${errors.length}');
    }

    return MigrationReport(
      chatsMigrated: chats,
      messagesMigrated: messages,
      summariesMigrated: summaries,
      pinnedMigrated: pins,
      errors: errors,
      stoppedEarly: stoppedEarly,
      failedItems: failedItems,
    );
  }

  static Future<String> _getOldStoragePath() async {
    final directory = await getApplicationDocumentsDirectory();
    if (Platform.isAndroid) {
      return p.join(directory.path, 'BlueTalkData');
    }
    return p.join(directory.path, 'HaloStoryData');
  }

  static Future<void> _archiveOldFolder(String path) async {
    try {
      final dir = Directory(path);
      if (!await dir.exists()) return;
      final now = DateTime.now();
      final ts = '${now.year}'
          '${now.month.toString().padLeft(2, '0')}'
          '${now.day.toString().padLeft(2, '0')}';
      final parent = dir.parent;
      final oldName = p.basename(path);
      final newName = '$oldName${_archiveSuffix}_$ts';
      final newPath = p.join(parent.path, newName);
      await dir.rename(newPath);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('DEBUG: Failed to archive old folder: $e');
      }
    }
  }

  static Future<void> resetMigrationFlag() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_migrationDoneKey);
  }

  static Future<void> clearAllData() async {
    final appDb = AppDatabase();
    await appDb.openFresh();
    await resetMigrationFlag();
  }
}
