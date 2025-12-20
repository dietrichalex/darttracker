import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert'; // For JSON encoding

class DBHelper {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await openDatabase(
      join(await getDatabasesPath(), 'darts_pro_final.db'), // New DB name to force refresh
      onCreate: (db, version) async {
        // Table for Match History (Now with details column)
        await db.execute(
          "CREATE TABLE matches(id INTEGER PRIMARY KEY, winner TEXT, avg REAL, date TEXT, details TEXT)",
        );
        // Table for Player Roster
        await db.execute(
          "CREATE TABLE saved_players(id INTEGER PRIMARY KEY, name TEXT UNIQUE)",
        );
      },
      version: 1,
    );
    return _db!;
  }

  // --- PLAYER ROSTER ---
  static Future<int> addPlayer(String name) async {
    final db = await database;
    return await db.insert('saved_players', {'name': name}, 
      conflictAlgorithm: ConflictAlgorithm.ignore); // Ignore if already exists
  }

  static Future<List<String>> getPlayers() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('saved_players', orderBy: "name ASC");
    return List.generate(maps.length, (i) => maps[i]['name'] as String);
  }

  static Future<void> deletePlayer(String name) async {
    final db = await database;
    await db.delete('saved_players', where: 'name = ?', whereArgs: [name]);
  }

  // --- MATCH HISTORY ---
  static Future<int> saveMatch(Map<String, dynamic> matchData) async {
    final db = await database;
    return await db.insert('matches', matchData);
  }

  static Future<List<Map<String, dynamic>>> getHistory() async {
    final db = await database;
    return await db.query('matches', orderBy: 'id DESC');
  }
}