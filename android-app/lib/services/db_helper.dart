import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DBHelper {
  static final DBHelper instance = DBHelper._init();

  static Database? _database;

  DBHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDB('weather_app.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE stations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        station_id TEXT NOT NULL,
        api_key TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE observations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        station_id INTEGER NOT NULL,
        ts INTEGER NOT NULL,
        temperature REAL,
        feels_like REAL,
        dew_point REAL,
        wind_speed REAL,
        wind_gust REAL,
        wind_dir TEXT,
        precip REAL,
        pressure REAL,
        FOREIGN KEY (station_id) REFERENCES stations(id)
      );
    ''');
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
