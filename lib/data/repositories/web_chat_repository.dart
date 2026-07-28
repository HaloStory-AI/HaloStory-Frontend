import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_message.dart';
import '../models/chat_metadata.dart';
import 'chat_repository.dart';

class WebChatRepository implements ChatRepository {
  static const String _webPrefix = 'chat_history_';
  static const String _webTimePrefix = 'chat_time_';
  static const String _webSummaryPrefix = 'chat_summary_';
  static const String _webMemoriesPrefix = 'bot_memories_';
  static const String _webPinsKey = 'chat_pinned_ids';

  static final StreamController<String> _updateController =
      StreamController<String>.broadcast();
  @override
  Stream<String> get onChatUpdated => _updateController.stream;

  Future<String> _getStoragePath() async {
    if (Platform.isAndroid) {
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/BlueTalkData';
      final dir = Directory(path);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return path;
    }
    if (Platform.isWindows || Platform.isLinux) {
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

  @override
  Future<void> saveChat(String chatId, List<ChatMessage> messages) async {
    final jsonContent = jsonEncode(messages.map((m) => m.toLegacyMap()).toList());

    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_webPrefix$chatId', jsonContent);
      await prefs.setString('$_webTimePrefix$chatId', DateTime.now().toIso8601String());
      _updateController.add(chatId);
      return;
    }

    try {
      final path = await _getStoragePath();
      final file = File('$path/$chatId.json');
      final tempFile = File('$path/$chatId.json.tmp');
      await tempFile.writeAsString(jsonContent);
      await tempFile.rename(file.path);
      _updateController.add(chatId);
    } catch (e) {
      if (kDebugMode) debugPrint('DEBUG: Error saving chat: $e');
    }
  }

  @override
  Future<List<ChatMessage>> loadChat(String chatId) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString('$_webPrefix$chatId');
      if (data != null) {
        final list = List<Map<String, dynamic>>.from(jsonDecode(data));
        return list.map((m) => ChatMessage.fromLegacyMap(chatId, m)).toList();
      }
      return [];
    }

    try {
      final path = await _getStoragePath();
      final file = File('$path/$chatId.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final decoded = jsonDecode(content);
        List<Map<String, dynamic>> list;
        if (decoded is List) {
          list = List<Map<String, dynamic>>.from(decoded);
        } else if (decoded is Map && decoded['messages'] is List) {
          list = List<Map<String, dynamic>>.from(decoded['messages']);
        } else {
          return [];
        }
        return list.map((m) => ChatMessage.fromLegacyMap(chatId, m)).toList();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('DEBUG: Error loading chat ($chatId): $e');
      }
    }
    return [];
  }

  @override
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
      if (kDebugMode) debugPrint('DEBUG: Error loading summary: $e');
    }
    return {};
  }

  @override
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
      if (kDebugMode) debugPrint('DEBUG: Error saving summary: $e');
    }
  }

  @override
  Future<List<ChatMetadata>> getAllChatMetadata() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getKeys().where((key) => key.startsWith(_webPrefix)).map((key) {
        final id = key.replaceFirst(_webPrefix, '');
        final timeStr = prefs.getString('$_webTimePrefix$id');
        return ChatMetadata(
          id: id,
          lastModified: timeStr != null
              ? DateTime.parse(timeStr)
              : DateTime.fromMillisecondsSinceEpoch(0),
        );
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
            .where((file) {
              final name = file.uri.pathSegments.last;
              return !name.startsWith('pinned_chats') &&
                  !name.endsWith('.summary.json') &&
                  !name.endsWith('.tmp');
            })
            .map((file) => ChatMetadata(
              id: file.uri.pathSegments.last.replaceFirst('.json', ''),
              lastModified: file.lastModifiedSync(),
            ))
            .toList();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('DEBUG: Error listing chats: $e');
    }
    return [];
  }

  @override
  Future<List<String>> getPinnedChats() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_webPinsKey) ?? [];
    }

    try {
      final path = await _getStoragePath();
      final file = File('$path/pinned_chats.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        return List<String>.from(jsonDecode(content));
      }
    } catch (e) {
      if (kDebugMode) debugPrint('DEBUG: Error loading pinned chats: $e');
    }
    return [];
  }

  @override
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
      if (kDebugMode) debugPrint('DEBUG: Error saving pinned chats: $e');
    }
  }

  @override
  Future<void> saveMemories(String botId, List<String> memories) async {
    final jsonContent = jsonEncode(memories);

    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_webMemoriesPrefix$botId', jsonContent);
      return;
    }

    try {
      final path = await _getStoragePath();
      final file = File('$path/$botId.memories.json');
      await file.writeAsString(jsonContent);
    } catch (e) {
      if (kDebugMode) debugPrint('DEBUG: Error saving memories: $e');
    }
  }

  @override
  Future<List<String>> loadMemories(String botId) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString('$_webMemoriesPrefix$botId');
      if (data != null) {
        return List<String>.from(jsonDecode(data));
      }
      return [];
    }

    try {
      final path = await _getStoragePath();
      final file = File('$path/$botId.memories.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        return List<String>.from(jsonDecode(content));
      }
    } catch (e) {
      if (kDebugMode) debugPrint('DEBUG: Error loading memories: $e');
    }
    return [];
  }

  @override
  Future<void> deleteChat(String chatId) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_webPrefix$chatId');
      await prefs.remove('$_webTimePrefix$chatId');
      await prefs.remove('$_webSummaryPrefix$chatId');
      await prefs.remove('$_webMemoriesPrefix$chatId');
      return;
    }

    try {
      final path = await _getStoragePath();
      final file = File('$path/$chatId.json');
      if (await file.exists()) await file.delete();
      final summaryFile = File('$path/$chatId.summary.json');
      if (await summaryFile.exists()) await summaryFile.delete();
    } catch (e) {
      if (kDebugMode) debugPrint('DEBUG: Error deleting chat: $e');
    }

    _updateController.add(chatId);
    final pins = await getPinnedChats();
    if (pins.contains(chatId)) {
      pins.remove(chatId);
      await savePinnedChats(pins);
    }
  }

  @override
  Future<void> deleteChatOnly(String chatId) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_webPrefix$chatId');
      await prefs.remove('$_webTimePrefix$chatId');
      return;
    }

    try {
      final path = await _getStoragePath();
      final file = File('$path/$chatId.json');
      if (await file.exists()) await file.delete();
    } catch (e) {
      if (kDebugMode) debugPrint('DEBUG: Error deleting chat (keeping summary): $e');
    }

    _updateController.add(chatId);
    final pins = await getPinnedChats();
    if (pins.contains(chatId)) {
      pins.remove(chatId);
      await savePinnedChats(pins);
    }
  }

  @override
  Future<bool> updateGroupMetadata(String chatId, {String? name, String? bio, List<Map<String, dynamic>>? members}) async {
    final messages = await loadChat(chatId);
    final metadata = <String, dynamic>{'id': chatId, 'isGroup': true};

    int systemIndex = -1;
    for (int i = 0; i < messages.length; i++) {
      final msg = messages[i];
      if (msg.role == 'system' && msg.metadata != null) {
        systemIndex = i;
        metadata.addAll(msg.metadata!);
        break;
      }
    }

    if (name != null) metadata['name'] = name;
    if (bio != null) {
      metadata['bio'] = bio;
      metadata['description'] = bio;
    }
    if (members != null) metadata['members'] = members;

    final updatedMessages = List<ChatMessage>.from(messages);

    if (systemIndex >= 0) {
      updatedMessages[systemIndex] = ChatMessage(
        id: updatedMessages[systemIndex].id,
        chatId: chatId,
        role: 'system',
        content: updatedMessages[systemIndex].content,
        timestamp: updatedMessages[systemIndex].timestamp,
        metadata: metadata,
      );
    } else {
      updatedMessages.insert(0, ChatMessage(
        chatId: chatId,
        role: 'system',
        content: 'Group metadata updated.',
        metadata: metadata,
      ));
    }

    await saveChat(chatId, updatedMessages);
    return true;
  }

  @override
  Future<void> insertMessage(ChatMessage message) async {
    final chatId = message.chatId;
    final existing = await loadChat(chatId);
    existing.add(message);
    final jsonContent = jsonEncode(existing.map((m) => m.toLegacyMap()).toList());

    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_webPrefix$chatId', jsonContent);
      await prefs.setString('$_webTimePrefix$chatId', DateTime.now().toIso8601String());
      _updateController.add(chatId);
      return;
    }

    try {
      final path = await _getStoragePath();
      final file = File('$path/$chatId.json');
      final tempFile = File('$path/$chatId.json.tmp');
      await tempFile.writeAsString(jsonContent);
      await tempFile.rename(file.path);
      _updateController.add(chatId);
    } catch (e) {
      if (kDebugMode) debugPrint('DEBUG: Error inserting message: $e');
    }
  }

  @override
  Future<void> insertSummary(String chatId, int startIndex, String text) async {
    final existing = await loadSummaries(chatId);
    existing[startIndex] = text;

    final Map<String, String> stringified = existing.map(
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
      if (kDebugMode) debugPrint('DEBUG: Error inserting summary: $e');
    }
  }
}
