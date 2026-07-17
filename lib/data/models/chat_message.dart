import 'dart:convert';

class ChatMessage {
  final int? id;
  final String chatId;
  final String role;
  final String content;
  final String? timestamp;
  final String? status;
  final String? uuid;
  final String? botId;
  final String? botName;
  final String? botAvatar;
  final int? visibleParts;
  final bool isTypingNext;
  final bool isTempSummary;
  final Map<String, dynamic>? metadata;
  final dynamic rawError;

  const ChatMessage({
    this.id,
    required this.chatId,
    required this.role,
    required this.content,
    this.timestamp,
    this.status,
    this.uuid,
    this.botId,
    this.botName,
    this.botAvatar,
    this.visibleParts,
    this.isTypingNext = false,
    this.isTempSummary = false,
    this.metadata,
    this.rawError,
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'chat_id': chatId,
    'role': role,
    'content': content,
    'timestamp': timestamp,
    'status': status,
    'uuid': uuid,
    'bot_id': botId,
    'bot_name': botName,
    'bot_avatar': botAvatar,
    'visible_parts': visibleParts,
    'is_typing_next': isTypingNext ? 1 : 0,
    'is_temp_summary': isTempSummary ? 1 : 0,
    'metadata': metadata != null ? jsonEncode(metadata) : null,
    'raw_error': rawError != null ? jsonEncode(rawError) : null,
  };

  factory ChatMessage.fromMap(Map<String, dynamic> map) => ChatMessage(
    id: map['id'] as int?,
    chatId: map['chat_id'] as String,
    role: map['role'] as String,
    content: map['content'] as String,
    timestamp: map['timestamp'] as String?,
    status: map['status'] as String?,
    uuid: map['uuid'] as String?,
    botId: map['bot_id'] as String?,
    botName: map['bot_name'] as String?,
    botAvatar: map['bot_avatar'] as String?,
    visibleParts: map['visible_parts'] as int?,
    isTypingNext: (map['is_typing_next'] as int?) == 1,
    isTempSummary: (map['is_temp_summary'] as int?) == 1,
    metadata: map['metadata'] != null
        ? jsonDecode(map['metadata'] as String) as Map<String, dynamic>
        : null,
    rawError: map['raw_error'] != null ? jsonDecode(map['raw_error'] as String) : null,
  );

  Map<String, dynamic> toLegacyMap() => {
    if (id != null) 'sqlite_id': id,
    'role': role,
    'content': content,
    'timestamp': timestamp,
    'status': status,
    'uuid': uuid,
    'bot_id': botId,
    'bot_name': botName,
    'bot_avatar': botAvatar,
    'visible_parts': visibleParts,
    'is_typing_next': isTypingNext,
    'isTempSummary': isTempSummary,
    if (metadata != null) 'metadata': Map<String, dynamic>.from(metadata!),
    if (rawError != null) 'raw_error': rawError,
  };

  factory ChatMessage.fromLegacyMap(String chatId, Map<String, dynamic> map) =>
      ChatMessage(
        chatId: chatId,
        role: map['role'] as String? ?? 'user',
        content: map['content']?.toString() ?? '',
        timestamp: map['timestamp'] as String?,
        status: map['status'] as String?,
        uuid: map['uuid'] as String?,
        botId: map['bot_id'] as String?,
        botName: map['bot_name'] as String?,
        botAvatar: map['bot_avatar'] as String?,
        visibleParts: map['visible_parts'] as int?,
        isTypingNext: map['is_typing_next'] == true,
        isTempSummary: map['isTempSummary'] == true,
        metadata: map['metadata'] is Map
            ? Map<String, dynamic>.from(map['metadata'] as Map)
            : null,
        rawError: map['raw_error'],
      );
}
