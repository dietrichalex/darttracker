import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  static Database? _db;

  static Future<Database> _getDB() async {
    if (_db != null) return _db!;
    String path = join(await getDatabasesPath(), 'dart_pro.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('CREATE TABLE players(name TEXT PRIMARY KEY)');
        await db.execute('CREATE TABLE matches(id INTEGER PRIMARY KEY AUTOINCREMENT, winner TEXT, avg TEXT, date TEXT, details TEXT)');
      },
    );
    return _db!;
  }

  // --- PLAYERS ---
  static Future<void> addPlayer(String name) async {
    final db = await _getDB();
    await db.insert('players', {'name': name}, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  static Future<List<String>> getPlayers() async {
    final db = await _getDB();
    final List<Map<String, dynamic>> maps = await db.query('players');
    return List.generate(maps.length, (i) => maps[i]['name'] as String);
  }

  static Future<void> deletePlayer(String name) async {
    final db = await _getDB();
    await db.delete('players', where: 'name = ?', whereArgs: [name]);
  }

  static Future<void> deleteAllPlayers() async {
    final db = await _getDB();
    await db.delete('players');
  }

  // --- MATCHES ---
  static Future<void> saveMatch(Map<String, dynamic> matchData) async {
    final db = await _getDB();
    await db.insert('matches', matchData);
  }

  static Future<List<Map<String, dynamic>>> getMatches() async {
    final db = await _getDB();
    return await db.query('matches', orderBy: 'id DESC');
  }

  static Future<void> deleteMatch(int id) async {
    final db = await _getDB();
    await db.delete('matches', where: 'id = ?', whereArgs: [id]);
  }
}