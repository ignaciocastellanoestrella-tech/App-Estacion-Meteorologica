import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/weather.dart';
import '../models/history_summary.dart';

class WundergroundService {
  /// Fetch current observation for a given station credentials.
  Future<Weather> fetchCurrent({required String apiKey, required String stationId}) async {
    if (apiKey.isEmpty || stationId.isEmpty) {
      throw Exception('Wunderground API key or station id missing');
    }

    final uri = Uri.parse(
        'https://api.weather.com/v2/pws/observations/current?apiKey=$apiKey&stationId=$stationId&format=json&units=m&numericPrecision=decimal');

    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Failed to fetch weather: ${res.statusCode} ${res.body}');
    }

    final Map<String, dynamic> json = jsonDecode(res.body);
    return Weather.fromWundergroundJson(json);
  }

  Future<HistorySummary> fetchHistoryDaily({
    required String apiKey,
    required String stationId,
    required DateTime date,
  }) async {
    final dateStr = _formatDate(date);
    final uri = Uri.parse(
        'https://api.weather.com/v2/pws/history/daily?apiKey=$apiKey&stationId=$stationId&format=json&units=m&date=$dateStr&numericPrecision=decimal');
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Failed to fetch history daily: ${res.statusCode} ${res.body}');
    }
    final Map<String, dynamic> json = jsonDecode(res.body);
    final observations = json['observations'];
    if (observations is! List || observations.isEmpty) {
      throw Exception('No observations for requested date');
    }
    final obs = observations[0];
    final metric = obs['metric'];
    if (metric is! Map) {
      throw Exception('No metric data for requested date');
    }
    final pressureMax = _num(metric['pressureMax']);
    final pressureMin = _num(metric['pressureMin']);
    final pressureAvg = (pressureMax + pressureMin) / 2.0;

    return HistorySummary(
      tempAvg: _num(metric['tempAvg']),
      tempMin: _num(metric['tempLow']),
      tempMax: _num(metric['tempHigh']),
      humidityAvg: _num(obs['humidityAvg'] ?? obs['humidity']),
      precipTotal: _num(metric['precipTotal']),
      precipRateMax: _num(metric['precipRate']),
      windAvg: _num(metric['windspeedAvg']),
      windGustMax: _num(metric['windgustHigh']),
      pressureAvg: pressureAvg,
      heatIndexAvg: _num(metric['heatindexAvg']),
    );
  }

  Future<HistorySummary> fetchHistoryRange({
    required String apiKey,
    required String stationId,
    required DateTime start,
    required DateTime end,
  }) async {
    final days = <HistorySummary>[];
    var cursor = DateTime(start.year, start.month, start.day);
    final last = DateTime(end.year, end.month, end.day);
    while (!cursor.isAfter(last)) {
      try {
        final summary = await fetchHistoryDaily(apiKey: apiKey, stationId: stationId, date: cursor);
        days.add(summary);
      } catch (_) {
        // ignore missing days
      }
      cursor = cursor.add(const Duration(days: 1));
    }

    if (days.isEmpty) {
      return HistorySummary(
        tempAvg: 0,
        tempMin: 0,
        tempMax: 0,
        humidityAvg: 0,
        precipTotal: 0,
        precipRateMax: 0,
        windAvg: 0,
        windGustMax: 0,
        pressureAvg: 0,
        heatIndexAvg: 0,
      );
    }

    double sumTemp = 0;
    double sumHum = 0;
    double sumPrecip = 0;
    double sumWind = 0;
    double sumPressure = 0;
    double sumHeatIndex = 0;
    double minTemp = days.first.tempMin;
    double maxTemp = days.first.tempMax;
    double maxGust = days.first.windGustMax;
    double maxPrecipRate = days.first.precipRateMax;

    for (final d in days) {
      sumTemp += d.tempAvg;
      sumHum += d.humidityAvg;
      sumPrecip += d.precipTotal;
      sumWind += d.windAvg;
      sumPressure += d.pressureAvg;
      sumHeatIndex += d.heatIndexAvg;
      if (d.tempMin < minTemp) minTemp = d.tempMin;
      if (d.tempMax > maxTemp) maxTemp = d.tempMax;
      if (d.windGustMax > maxGust) maxGust = d.windGustMax;
      if (d.precipRateMax > maxPrecipRate) maxPrecipRate = d.precipRateMax;
    }

    final count = days.length.toDouble();
    return HistorySummary(
      tempAvg: sumTemp / count,
      tempMin: minTemp,
      tempMax: maxTemp,
      humidityAvg: sumHum / count,
      precipTotal: sumPrecip,
      precipRateMax: maxPrecipRate,
      windAvg: sumWind / count,
      windGustMax: maxGust,
      pressureAvg: sumPressure / count,
      heatIndexAvg: sumHeatIndex / count,
    );
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y$m$d';
  }

  double _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }
}
