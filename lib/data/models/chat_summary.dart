class ChatSummary {
  final String chatId;
  final int startIndex;
  final String summaryText;

  const ChatSummary({
    required this.chatId,
    required this.startIndex,
    required this.summaryText,
  });

  Map<String, dynamic> toMap() => {
    'chat_id': chatId,
    'start_index': startIndex,
    'summary_text': summaryText,
  };

  factory ChatSummary.fromMap(Map<String, dynamic> map) => ChatSummary(
    chatId: map['chat_id'] as String,
    startIndex: map['start_index'] as int,
    summaryText: map['summary_text'] as String,
  );
}
