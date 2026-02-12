import 'package:sqflite/sqflite.dart';
import '../models/observation.dart';
import '../services/db_helper.dart';

class ObservationRepository {
  final DBHelper _dbHelper = DBHelper.instance;

  Future<Observation> create(Observation o) async {
    final db = await _dbHelper.database;
    final id = await db.insert('observations', o.toMap());
    return Observation(
      id: id,
      stationDbId: o.stationDbId,
      ts: o.ts,
      temperature: o.temperature,
      feelsLike: o.feelsLike,
      dewPoint: o.dewPoint,
      windSpeed: o.windSpeed,
      windGust: o.windGust,
      windDir: o.windDir,
      precip: o.precip,
      pressure: o.pressure,
    );
  }

  Future<List<Observation>> getBetween(int stationDbId, int fromTs, int toTs) async {
    final db = await _dbHelper.database;
    final rows = await db.query('observations',
        where: 'station_id = ? AND ts >= ? AND ts <= ?', whereArgs: [stationDbId, fromTs, toTs], orderBy: 'ts ASC');
    return rows.map((r) => Observation.fromMap(r)).toList();
  }

  Future<Map<String, dynamic>> summaryForPeriod(int stationDbId, int fromTs, int toTs) async {
    final db = await _dbHelper.database;
    final res = await db.rawQuery('''
      SELECT
        AVG(temperature) as temp_avg,
        MIN(temperature) as temp_min,
        MAX(temperature) as temp_max,
        SUM(precip) as precip_total,
        MAX(precip) as precip_max,
        AVG(wind_speed) as wind_avg,
        MAX(wind_gust) as wind_gust_max
      FROM observations
      WHERE station_id = ? AND ts >= ? AND ts <= ?
    ''', [stationDbId, fromTs, toTs]);

    return res.isNotEmpty ? res.first : <String, dynamic>{};
  }

  Future<Observation?> getLastObservation(int stationDbId) async {
    final db = await _dbHelper.database;
    final rows = await db.query('observations',
        where: 'station_id = ?', whereArgs: [stationDbId], orderBy: 'ts DESC', limit: 1);
    if (rows.isEmpty) return null;
    return Observation.fromMap(rows.first);
  }
}
