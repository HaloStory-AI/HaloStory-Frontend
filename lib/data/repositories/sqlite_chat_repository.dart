import 'dart:async';
import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import '../models/chat_message.dart';
import '../models/chat_metadata.dart';
import 'chat_repository.dart';

class SqliteChatRepository implements ChatRepository {
  static final StreamController<String> _updateController =
      StreamController<String>.broadcast();
  @override
  Stream<String> get onChatUpdated => _updateController.stream;

  final AppDatabase _appDb = AppDatabase();
  Database? _db;

  Future<Database> _getDb() async {
    _db ??= await _appDb.database;
    return _db!;
  }

  @override
  Future<void> saveChat(String chatId, List<ChatMessage> messages) async {
    final db = await _getDb();
    await db.transaction((txn) async {
      await txn.delete('messages', where: 'chat_id = ?', whereArgs: [chatId]);
      await txn.insert(
        'chats',
        {
          'id': chatId,
          'is_group': chatId.startsWith('group_') ? 1 : 0,
          'last_modified': DateTime.now().toIso8601String(),
          'created_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      for (final msg in messages) {
        await txn.insert('messages', msg.toMap());
      }
    });
    _updateController.add(chatId);
  }

  @override
  Future<List<ChatMessage>> loadChat(String chatId) async {
    final db = await _getDb();
    final rows = await db.query(
      'messages',
      where: 'chat_id = ?',
      whereArgs: [chatId],
      orderBy: 'id ASC',
    );
    return rows.map((row) => ChatMessage.fromMap(row)).toList();
  }

  @override
  Future<void> saveSummaries(String chatId, Map<int, String> summaries) async {
    final db = await _getDb();
    await db.transaction((txn) async {
      await txn.delete('summaries', where: 'chat_id = ?', whereArgs: [chatId]);
      for (final entry in summaries.entries) {
        await txn.insert('summaries', {
          'chat_id': chatId,
          'start_index': entry.key,
          'summary_text': entry.value,
        });
      }
    });
  }

  @override
  Future<Map<int, String>> loadSummaries(String chatId) async {
    final db = await _getDb();
    final rows = await db.query(
      'summaries',
      where: 'chat_id = ?',
      whereArgs: [chatId],
      orderBy: 'start_index ASC',
    );
    final map = <int, String>{};
    for (final row in rows) {
      map[row['start_index'] as int] = row['summary_text'] as String;
    }
    return map;
  }

  @override
  Future<List<ChatMetadata>> getAllChatMetadata() async {
    final db = await _getDb();
    final rows = await db.query('chats', orderBy: 'last_modified DESC');
    return rows.map((row) => ChatMetadata(
      id: row['id'] as String,
      lastModified: DateTime.parse(row['last_modified'] as String),
      isGroup: (row['is_group'] as int) == 1,
    )).toList();
  }

  @override
  Future<List<String>> getPinnedChats() async {
    final db = await _getDb();
    final rows = await db.query('pinned_chats', orderBy: 'pinned_at DESC');
    return rows.map((row) => row['chat_id'] as String).toList();
  }

  @override
  Future<void> savePinnedChats(List<String> pins) async {
    final db = await _getDb();
    await db.transaction((txn) async {
      await txn.delete('pinned_chats');
      for (final id in pins) {
        await txn.insert('pinned_chats', {
          'chat_id': id,
          'pinned_at': DateTime.now().toIso8601String(),
        });
      }
    });
  }

  @override
  Future<void> deleteChat(String chatId) async {
    final db = await _getDb();
    await db.transaction((txn) async {
      await txn.delete('messages', where: 'chat_id = ?', whereArgs: [chatId]);
      await txn.delete('summaries', where: 'chat_id = ?', whereArgs: [chatId]);
      await txn.delete('pinned_chats', where: 'chat_id = ?', whereArgs: [chatId]);
      await txn.delete('chats', where: 'id = ?', whereArgs: [chatId]);
    });
    _updateController.add(chatId);
  }

  @override
  Future<void> deleteChatOnly(String chatId) async {
    final db = await _getDb();
    await db.transaction((txn) async {
      await txn.delete('messages', where: 'chat_id = ?', whereArgs: [chatId]);
    });
    _updateController.add(chatId);
  }

  @override
  Future<bool> updateGroupMetadata(
    String chatId, {
    String? name,
    String? bio,
    List<Map<String, dynamic>>? members,
  }) async {
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

  Future<Map<String, dynamic>?> loadRawChatMetadata(String chatId) async {
    final db = await _getDb();
    final rows = await db.query(
      'chats',
      where: 'id = ?',
      whereArgs: [chatId],
    );
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first);
  }

  Future<void> upsertChat({
    required String id,
    required bool isGroup,
    required DateTime lastModified,
    DateTime? createdAt,
  }) async {
    final db = await _getDb();
    await db.insert(
      'chats',
      {
        'id': id,
        'is_group': isGroup ? 1 : 0,
        'last_modified': lastModified.toIso8601String(),
        'created_at': (createdAt ?? lastModified).toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertMessage(ChatMessage message) async {
    final db = await _getDb();
    await db.insert('messages', message.toMap());
  }

  Future<void> insertSummary(String chatId, int startIndex, String text) async {
    final db = await _getDb();
    await db.insert('summaries', {
      'chat_id': chatId,
      'start_index': startIndex,
      'summary_text': text,
    });
  }

  Future<void> insertPinnedChat(String chatId) async {
    final db = await _getDb();
    await db.insert('pinned_chats', {
      'chat_id': chatId,
      'pinned_at': DateTime.now().toIso8601String(),
    });
  }
}
