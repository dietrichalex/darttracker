import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await openDatabase(
      join(await getDatabasesPath(), 'darts_history.db'),
      onCreate: (db, version) {
        return db.execute(
          "CREATE TABLE matches(id INTEGER PRIMARY KEY, winner TEXT, avg REAL, date TEXT)",
        );
      },
      version: 1,
    );
    return _db!;
  }
}