import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static final AppDatabase _instance = AppDatabase._();
  factory AppDatabase() => _instance;
  AppDatabase._();

  Database? _db;

  static const _databaseName = 'halostory.db';
  static const _databaseVersion = 2;

  Future<Database> get database async {
    if (_db != null) return _db!;
    if (kIsWeb) throw UnsupportedError('AppDatabase not supported on web');
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'HaloStory', _databaseName);
    final dbDir = p.dirname(dbPath);
    final dbDirFile = Directory(dbDir);
    if (!await dbDirFile.exists()) {
      await dbDirFile.create(recursive: true);
    }
    return await openDatabase(dbPath, version: _databaseVersion, onCreate: _onCreate, onUpgrade: _onUpgrade);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE chats (
        id TEXT PRIMARY KEY,
        is_group INTEGER NOT NULL DEFAULT 0,
        last_modified TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        chat_id TEXT NOT NULL,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        timestamp TEXT,
        status TEXT,
        uuid TEXT,
        bot_id TEXT,
        bot_name TEXT,
        bot_avatar TEXT,
        visible_parts INTEGER,
        is_typing_next INTEGER NOT NULL DEFAULT 0,
        is_temp_summary INTEGER NOT NULL DEFAULT 0,
        metadata TEXT,
        raw_error TEXT,
        FOREIGN KEY (chat_id) REFERENCES chats(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_messages_chat_id ON messages(chat_id)
    ''');

    await db.execute('''
      CREATE TABLE summaries (
        chat_id TEXT NOT NULL,
        start_index INTEGER NOT NULL,
        summary_text TEXT NOT NULL,
        PRIMARY KEY (chat_id, start_index),
        FOREIGN KEY (chat_id) REFERENCES chats(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE pinned_chats (
        chat_id TEXT PRIMARY KEY,
        pinned_at TEXT NOT NULL,
        FOREIGN KEY (chat_id) REFERENCES chats(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE bot_memories (
        bot_id TEXT NOT NULL,
        memory_item TEXT NOT NULL,
        created_at TEXT NOT NULL,
        PRIMARY KEY (bot_id, memory_item)
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS bot_memories (
          bot_id TEXT NOT NULL,
          memory_item TEXT NOT NULL,
          created_at TEXT NOT NULL,
          PRIMARY KEY (bot_id, memory_item)
        )
      ''');
    }
  }

  Future<Database> openFresh() async {
    await close();
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'HaloStory', _databaseName);
    final file = File(dbPath);
    if (await file.exists()) {
      await file.delete();
    }
    return await database;
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
