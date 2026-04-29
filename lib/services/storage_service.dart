import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/message.dart';

class StorageService {
  static Database? _db;

  Future<Database> get _database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'ghost_mesh.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE messages (
            id TEXT PRIMARY KEY,
            chat_id TEXT NOT NULL,
            sender_id TEXT NOT NULL,
            text TEXT NOT NULL,
            timestamp INTEGER NOT NULL,
            status INTEGER NOT NULL DEFAULT 0,
            is_ghost INTEGER NOT NULL DEFAULT 0,
            is_deleted INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_chat_id ON messages (chat_id, timestamp)',
        );
      },
    );
  }

  Future<void> insertMessage(Message m) async {
    final db = await _database;
    await db.insert(
      'messages',
      m.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Message>> getMessages(String chatId) async {
    final db = await _database;
    final maps = await db.query(
      'messages',
      where: 'chat_id = ? AND is_deleted = 0',
      whereArgs: [chatId],
      orderBy: 'timestamp ASC',
    );
    return maps.map(Message.fromMap).toList();
  }

  Future<void> updateStatus(String id, MessageStatus status) async {
    final db = await _database;
    await db.update(
      'messages',
      {'status': status.index},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteMessage(String id) async {
    final db = await _database;
    await db.update(
      'messages',
      {'is_deleted': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteGhostsForChat(String chatId) async {
    final db = await _database;
    await db.update(
      'messages',
      {'is_deleted': 1},
      where: 'chat_id = ? AND is_ghost = 1',
      whereArgs: [chatId],
    );
  }
}
