import '../models/chat_message.dart';
import '../models/chat_metadata.dart';

abstract class ChatRepository {
  Stream<String> get onChatUpdated;

  Future<void> saveChat(String chatId, List<ChatMessage> messages);

  Future<List<ChatMessage>> loadChat(String chatId);

  Future<void> saveSummaries(String chatId, Map<int, String> summaries);

  Future<Map<int, String>> loadSummaries(String chatId);

  Future<List<ChatMetadata>> getAllChatMetadata();

  Future<List<String>> getPinnedChats();

  Future<void> savePinnedChats(List<String> pins);

  Future<void> deleteChat(String chatId);

  Future<void> deleteChatOnly(String chatId);

  Future<bool> updateGroupMetadata(String chatId, {String? name, String? bio, List<Map<String, dynamic>>? members});

  Future<void> saveMemories(String botId, List<String> memories);

  Future<List<String>> loadMemories(String botId);

  Future<void> insertMessage(ChatMessage message);

  Future<void> insertSummary(String chatId, int startIndex, String text);
}
