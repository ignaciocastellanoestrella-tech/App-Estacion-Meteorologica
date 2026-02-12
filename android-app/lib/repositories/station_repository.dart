import 'package:sqflite/sqflite.dart';
import '../models/station.dart';
import '../services/db_helper.dart';

class StationRepository {
  final DBHelper _dbHelper = DBHelper.instance;

  Future<Station> create(Station s) async {
    final db = await _dbHelper.database;
    final id = await db.insert('stations', s.toMap());
    return Station(id: id, name: s.name, stationId: s.stationId, apiKey: s.apiKey);
  }

  Future<List<Station>> getAll() async {
    final db = await _dbHelper.database;
    final rows = await db.query('stations', orderBy: 'id DESC');
    return rows.map((r) => Station.fromMap(r)).toList();
  }

  Future<int> update(Station s) async {
    final db = await _dbHelper.database;
    return db.update('stations', s.toMap(), where: 'id = ?', whereArgs: [s.id]);
  }

  Future<int> delete(int id) async {
    final db = await _dbHelper.database;
    return db.delete('stations', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> count() async {
    final db = await _dbHelper.database;
    final res = await db.rawQuery('SELECT COUNT(*) as c FROM stations');
    return Sqflite.firstIntValue(res) ?? 0;
  }
}
