import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/models/chat_message.dart';
import '../data/repositories/chat_repository.dart';
import '../data/repositories/sqlite_chat_repository.dart';
import '../data/repositories/web_chat_repository.dart';

class LocalChatService {
  late final ChatRepository _repo;

  static final StreamController<String> _updateController =
      StreamController<String>.broadcast();
  static Stream<String> get onChatUpdated => _updateController.stream;

  LocalChatService() {
    if (kIsWeb) {
      _repo = WebChatRepository();
    } else {
      _repo = SqliteChatRepository();
    }
    _repo.onChatUpdated.listen((chatId) {
      _updateController.add(chatId);
    });
  }

  Future<void> saveChat(
    String chatId,
    List<Map<String, dynamic>> messages,
  ) async {
    final typed = messages
        .map((m) => ChatMessage.fromLegacyMap(chatId, m))
        .toList();
    await _repo.saveChat(chatId, typed);
  }

  Future<List<Map<String, dynamic>>> loadChat(String chatId) async {
    final typed = await _repo.loadChat(chatId);
    return typed.map((m) => m.toLegacyMap()).toList();
  }

  Future<void> saveSummaries(String chatId, Map<int, String> summaries) async {
    await _repo.saveSummaries(chatId, summaries);
  }

  Future<Map<int, String>> loadSummaries(String chatId) async {
    return await _repo.loadSummaries(chatId);
  }

  Future<List<Map<String, dynamic>>> getAllChatMetadata() async {
    final metadata = await _repo.getAllChatMetadata();
    return metadata.map((m) => m.toLegacyMap()).toList();
  }

  Future<List<String>> getPinnedChats() async {
    return await _repo.getPinnedChats();
  }

  Future<void> savePinnedChats(List<String> pins) async {
    await _repo.savePinnedChats(pins);
  }

  Future<void> insertMessage(
    String chatId,
    Map<String, dynamic> message,
  ) async {
    final typed = ChatMessage.fromLegacyMap(chatId, message);
    await _repo.insertMessage(typed);
  }

  Future<void> insertSummary(
    String chatId,
    int startIndex,
    String text,
  ) async {
    await _repo.insertSummary(chatId, startIndex, text);
  }

  Future<void> saveMemories(String botId, List<String> memories) async {
    await _repo.saveMemories(botId, memories);
  }

  Future<List<String>> loadMemories(String botId) async {
    return await _repo.loadMemories(botId);
  }

  Future<void> deleteChat(String chatId) async {
    await _repo.deleteChat(chatId);
  }

  Future<void> deleteChatOnly(String chatId) async {
    await _repo.deleteChatOnly(chatId);
  }

  Future<bool> updateGroupMetadata(
    String chatId, {
    String? name,
    String? bio,
    List<Map<String, dynamic>>? members,
  }) async {
    return await _repo.updateGroupMetadata(
      chatId,
      name: name,
      bio: bio,
      members: members,
    );
  }
}
