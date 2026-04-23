import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalChatService {
  static const String _webPrefix = 'chat_history_';
  static const String _webTimePrefix = 'chat_time_';
  static const String _webSummaryPrefix = 'chat_summary_';
  static const String _webPinsKey = 'chat_pinned_ids';

  // Reactive Stream for UI updates
  static final StreamController<String> _updateController =
      StreamController<String>.broadcast();
  static Stream<String> get onChatUpdated => _updateController.stream;

  // Get the directory for Android storage
  Future<String> _getStoragePath() async {
    if (kIsWeb) return '';

    if (Platform.isAndroid) {
      // In a real app with proper permissions, we'd aim for External Storage
      // For now, using ApplicationDocumentsDirectory which is standard.
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/BlueTalkData';
      final dir = Directory(path);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return path;
    }

    if (Platform.isWindows) {
      // For Windows, create HaloStoryData folder in Documents
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/HaloStoryData';
      final dir = Directory(path);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return path;
    }

    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  // Save a chat session
  Future<void> saveChat(
    String chatId,
    List<Map<String, dynamic>> messages,
  ) async {
    final jsonContent = jsonEncode(messages);

    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_webPrefix$chatId', jsonContent);
      await prefs.setString(
        '$_webTimePrefix$chatId',
        DateTime.now().toIso8601String(),
      );
      _updateController.add(chatId);
      return;
    }

    try {
      final path = await _getStoragePath();
      final file = File('$path/$chatId.json');
      await file.writeAsString(jsonContent);
      _updateController.add(chatId);
    } catch (e) {
      print('DEBUG: Error saving chat: $e');
    }
  }

  // Load a chat session
  Future<List<Map<String, dynamic>>> loadChat(String chatId) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString('$_webPrefix$chatId');
      if (data != null) {
        return List<Map<String, dynamic>>.from(jsonDecode(data));
      }
      return [];
    }

    try {
      final path = await _getStoragePath();
      final file = File('$path/$chatId.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        return List<Map<String, dynamic>>.from(jsonDecode(content));
      }
    } catch (e) {
      print('DEBUG: Error loading chat: $e');
    }
    return [];
  }

  // --- Summary Methods ---

  Future<void> saveSummaries(String chatId, Map<int, String> summaries) async {
    final Map<String, String> stringified = summaries.map(
      (k, v) => MapEntry(k.toString(), v),
    );
    final jsonContent = jsonEncode(stringified);

    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_webSummaryPrefix$chatId', jsonContent);
      return;
    }

    try {
      final path = await _getStoragePath();
      final file = File('$path/$chatId.summary.json');
      await file.writeAsString(jsonContent);
    } catch (e) {
      print('DEBUG: Error saving summary: $e');
    }
  }

  Future<Map<int, String>> loadSummaries(String chatId) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString('$_webSummaryPrefix$chatId');
      if (data != null) {
        final Map<String, dynamic> decoded = jsonDecode(data);
        return decoded.map((k, v) => MapEntry(int.parse(k), v.toString()));
      }
      return {};
    }

    try {
      final path = await _getStoragePath();
      final file = File('$path/$chatId.summary.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final Map<String, dynamic> decoded = jsonDecode(content);
        return decoded.map((k, v) => MapEntry(int.parse(k), v.toString()));
      }
    } catch (e) {
      print('DEBUG: Error loading summary: $e');
    }
    return {};
  }

  // List all active chat session IDs
  Future<List<Map<String, dynamic>>> getAllChatMetadata() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getKeys().where((key) => key.startsWith(_webPrefix)).map((
        key,
      ) {
        final id = key.replaceFirst(_webPrefix, '');
        final timeStr = prefs.getString('$_webTimePrefix$id');
        return {
          'id': id,
          'lastModified': timeStr != null
              ? DateTime.parse(timeStr)
              : DateTime.fromMillisecondsSinceEpoch(0),
        };
      }).toList();
    }

    try {
      final path = await _getStoragePath();
      final dir = Directory(path);
      if (await dir.exists()) {
        return dir
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith('.json'))
            .map(
              (file) => {
                'id': file.uri.pathSegments.last.replaceFirst('.json', ''),
                'lastModified': file.lastModifiedSync(),
              },
            )
            .toList();
      }
    } catch (e) {
      print('DEBUG: Error listing chats: $e');
    }
    return [];
  }

  // --- Pinned Chats Methods ---

  Future<List<String>> getPinnedChats() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getStringList(_webPinsKey);
      return data ?? [];
    }

    try {
      final path = await _getStoragePath();
      final file = File('$path/pinned_chats.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        return List<String>.from(jsonDecode(content));
      }
    } catch (e) {
      print('DEBUG: Error loading pinned chats: $e');
    }
    return [];
  }

  Future<void> savePinnedChats(List<String> pins) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_webPinsKey, pins);
      return;
    }

    try {
      final path = await _getStoragePath();
      final file = File('$path/pinned_chats.json');
      await file.writeAsString(jsonEncode(pins));
    } catch (e) {
      print('DEBUG: Error saving pinned chats: $e');
    }
  }

  // Clear a chat
  Future<void> deleteChat(String chatId) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_webPrefix$chatId');
      await prefs.remove('$_webTimePrefix$chatId');
      await prefs.remove('$_webSummaryPrefix$chatId');
      return;
    }

    try {
      final path = await _getStoragePath();
      final file = File('$path/$chatId.json');
      if (await file.exists()) {
        await file.delete();
      }
      final summaryFile = File('$path/$chatId.summary.json');
      if (await summaryFile.exists()) {
        await summaryFile.delete();
      }
    } catch (e) {
      print('DEBUG: Error deleting chat: $e');
    }

    _updateController.add(chatId);

    // Auto-remove from pins if deleted
    final pins = await getPinnedChats();
    if (pins.contains(chatId)) {
      pins.remove(chatId);
      await savePinnedChats(pins);
    }
  }
}
