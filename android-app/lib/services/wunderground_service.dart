import 'dart:convert';
import 'dart:math' as math;
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
    final humidityAvg = _num(obs['humidityAvg'] ?? obs['humidity']);
    final windAvg = _num(metric['windspeedAvg']);

    return HistorySummary(
      tempAvg: _num(metric['tempAvg']),
      tempMin: _num(metric['tempLow']),
      tempMax: _num(metric['tempHigh']),
      humidityAvg: humidityAvg,
      humidityMin: humidityAvg,
      humidityMax: humidityAvg,
      precipTotal: _num(metric['precipTotal']),
      precipRateMax: _num(metric['precipRate']),
      windAvg: windAvg,
      windMin: _num(metric['windspeedLow']) == 0 ? windAvg : _num(metric['windspeedLow']),
      windMax: _num(metric['windspeedHigh']) == 0 ? windAvg : _num(metric['windspeedHigh']),
      windGustMax: _num(metric['windgustHigh']),
      windGustAvg: _num(metric['windgustHigh']),
      windDirAvg: 0,
      pressureAvg: pressureAvg,
      pressureMin: pressureMin,
      pressureMax: pressureMax,
      heatIndexAvg: _num(metric['heatindexAvg']),
    );
  }

  Future<HistorySummary> fetchHistoryHourlySummary({
    required String apiKey,
    required String stationId,
    required DateTime date,
  }) async {
    final dateStr = _formatDate(date);
    final uri = Uri.parse(
        'https://api.weather.com/v2/pws/history/hourly?apiKey=$apiKey&stationId=$stationId&format=json&units=m&date=$dateStr&numericPrecision=decimal');
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Failed to fetch history hourly: ${res.statusCode} ${res.body}');
    }
    final Map<String, dynamic> json = jsonDecode(res.body);
    final observations = json['observations'];
    if (observations is! List || observations.isEmpty) {
      throw Exception('No observations for requested date');
    }

    double sumTempAvg = 0;
    int countTempAvg = 0;
    double sumHumAvg = 0;
    int countHumAvg = 0;
    double sumWindAvg = 0;
    int countWindAvg = 0;
    double sumGustAvg = 0;
    int countGustAvg = 0;
    double sumPressureAvg = 0;
    int countPressureAvg = 0;
    double sumHeatIndexAvg = 0;
    int countHeatIndexAvg = 0;

    double? tempMin;
    double? tempMax;
    double? humidityMin;
    double? humidityMax;
    double? precipTotalMax;
    double? precipRateMax;
    double? windMin;
    double? windMax;
    double? windGustMax;
    double? pressureMin;
    double? pressureMax;

    double windDirSin = 0;
    double windDirCos = 0;
    int windDirCount = 0;

    for (final obs in observations) {
      if (obs is! Map) continue;
      final metric = obs['metric'];
      if (metric is! Map) continue;

      final tempHigh = _numNullable(metric['tempHigh']);
      if (tempHigh != null) tempMax = tempMax == null ? tempHigh : math.max(tempMax, tempHigh);
      final tempLow = _numNullable(metric['tempLow']);
      if (tempLow != null) tempMin = tempMin == null ? tempLow : math.min(tempMin, tempLow);
      final tempAvg = _numNullable(metric['tempAvg']);
      if (tempAvg != null) {
        sumTempAvg += tempAvg;
        countTempAvg += 1;
      }

      final humHigh = _numNullable(obs['humidityHigh']);
      if (humHigh != null) humidityMax = humidityMax == null ? humHigh : math.max(humidityMax, humHigh);
      final humLow = _numNullable(obs['humidityLow']);
      if (humLow != null) humidityMin = humidityMin == null ? humLow : math.min(humidityMin, humLow);
      final humAvg = _numNullable(obs['humidityAvg']);
      if (humAvg != null) {
        sumHumAvg += humAvg;
        countHumAvg += 1;
      }

      final precipTotal = _numNullable(metric['precipTotal']);
      if (precipTotal != null) {
        precipTotalMax = precipTotalMax == null ? precipTotal : math.max(precipTotalMax, precipTotal);
      }
      final precipRate = _numNullable(metric['precipRate']);
      if (precipRate != null) {
        precipRateMax = precipRateMax == null ? precipRate : math.max(precipRateMax, precipRate);
      }

      final windHigh = _numNullable(metric['windspeedHigh']);
      if (windHigh != null) windMax = windMax == null ? windHigh : math.max(windMax, windHigh);
      final windLow = _numNullable(metric['windspeedLow']);
      if (windLow != null) windMin = windMin == null ? windLow : math.min(windMin, windLow);
      final windAvg = _numNullable(metric['windspeedAvg']);
      if (windAvg != null) {
        sumWindAvg += windAvg;
        countWindAvg += 1;
      }

      final gustHigh = _numNullable(metric['windgustHigh']);
      if (gustHigh != null) windGustMax = windGustMax == null ? gustHigh : math.max(windGustMax, gustHigh);
      final gustAvg = _numNullable(metric['windgustAvg']);
      if (gustAvg != null) {
        sumGustAvg += gustAvg;
        countGustAvg += 1;
      }

      final pressureHigh = _numNullable(metric['pressureMax']);
      if (pressureHigh != null) pressureMax = pressureMax == null ? pressureHigh : math.max(pressureMax, pressureHigh);
      final pressureLow = _numNullable(metric['pressureMin']);
      if (pressureLow != null) pressureMin = pressureMin == null ? pressureLow : math.min(pressureMin, pressureLow);
      if (pressureHigh != null && pressureLow != null) {
        sumPressureAvg += (pressureHigh + pressureLow) / 2.0;
        countPressureAvg += 1;
      }

      final heatIndexAvg = _numNullable(metric['heatindexAvg']);
      if (heatIndexAvg != null) {
        sumHeatIndexAvg += heatIndexAvg;
        countHeatIndexAvg += 1;
      }

      final windDir = _numNullable(obs['winddirAvg']);
      if (windDir != null) {
        final rad = windDir * math.pi / 180.0;
        windDirSin += math.sin(rad);
        windDirCos += math.cos(rad);
        windDirCount += 1;
      }
    }

    final tempAvg = (countTempAvg == 0 ? 0 : sumTempAvg / countTempAvg).toDouble();
    final humAvg = (countHumAvg == 0 ? 0 : sumHumAvg / countHumAvg).toDouble();
    final windAvg = (countWindAvg == 0 ? 0 : sumWindAvg / countWindAvg).toDouble();
    final gustAvg = (countGustAvg == 0 ? 0 : sumGustAvg / countGustAvg).toDouble();
    final pressureAvg = (countPressureAvg == 0 ? 0 : sumPressureAvg / countPressureAvg).toDouble();
    final heatIndexAvg = (countHeatIndexAvg == 0 ? 0 : sumHeatIndexAvg / countHeatIndexAvg).toDouble();
    final windDirAvg = _circularMeanDegrees(windDirSin, windDirCos, windDirCount);

    return HistorySummary(
      tempAvg: tempAvg,
      tempMin: (tempMin ?? tempAvg).toDouble(),
      tempMax: (tempMax ?? tempAvg).toDouble(),
      humidityAvg: humAvg,
      humidityMin: (humidityMin ?? humAvg).toDouble(),
      humidityMax: (humidityMax ?? humAvg).toDouble(),
      precipTotal: (precipTotalMax ?? 0).toDouble(),
      precipRateMax: (precipRateMax ?? 0).toDouble(),
      windAvg: windAvg,
      windMin: (windMin ?? windAvg).toDouble(),
      windMax: (windMax ?? windAvg).toDouble(),
      windGustMax: (windGustMax ?? 0).toDouble(),
      windGustAvg: gustAvg,
      windDirAvg: windDirAvg,
      pressureAvg: pressureAvg,
      pressureMin: (pressureMin ?? pressureAvg).toDouble(),
      pressureMax: (pressureMax ?? pressureAvg).toDouble(),
      heatIndexAvg: heatIndexAvg,
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
        final summary = await fetchHistoryHourlySummary(apiKey: apiKey, stationId: stationId, date: cursor);
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
        humidityMin: 0,
        humidityMax: 0,
        precipTotal: 0,
        precipRateMax: 0,
        windAvg: 0,
        windMin: 0,
        windMax: 0,
        windGustMax: 0,
        windGustAvg: 0,
        windDirAvg: 0,
        pressureAvg: 0,
        pressureMin: 0,
        pressureMax: 0,
        heatIndexAvg: 0,
      );
    }

    double sumTemp = 0;
    double sumHum = 0;
    double sumPrecip = 0;
    double sumWind = 0;
    double sumPressure = 0;
    double sumHeatIndex = 0;
    double sumWindGustAvg = 0;
    double minTemp = days.first.tempMin;
    double maxTemp = days.first.tempMax;
    double minHum = days.first.humidityMin;
    double maxHum = days.first.humidityMax;
    double minPressure = days.first.pressureMin;
    double maxPressure = days.first.pressureMax;
    double minWind = days.first.windMin;
    double maxWind = days.first.windMax;
    double maxGust = days.first.windGustMax;
    double maxPrecipRate = days.first.precipRateMax;
    double windDirSin = 0;
    double windDirCos = 0;
    int windDirCount = 0;

    for (final d in days) {
      sumTemp += d.tempAvg;
      sumHum += d.humidityAvg;
      sumPrecip += d.precipTotal;
      sumWind += d.windAvg;
      sumPressure += d.pressureAvg;
      sumHeatIndex += d.heatIndexAvg;
      sumWindGustAvg += d.windGustAvg;
      if (d.tempMin < minTemp) minTemp = d.tempMin;
      if (d.tempMax > maxTemp) maxTemp = d.tempMax;
      if (d.humidityMin < minHum) minHum = d.humidityMin;
      if (d.humidityMax > maxHum) maxHum = d.humidityMax;
      if (d.pressureMin < minPressure) minPressure = d.pressureMin;
      if (d.pressureMax > maxPressure) maxPressure = d.pressureMax;
      if (d.windMin < minWind) minWind = d.windMin;
      if (d.windMax > maxWind) maxWind = d.windMax;
      if (d.windGustMax > maxGust) maxGust = d.windGustMax;
      if (d.precipRateMax > maxPrecipRate) maxPrecipRate = d.precipRateMax;
      final rad = d.windDirAvg * math.pi / 180.0;
      windDirSin += math.sin(rad);
      windDirCos += math.cos(rad);
      windDirCount += 1;
    }

    final count = days.length.toDouble();
    return HistorySummary(
      tempAvg: (sumTemp / count).toDouble(),
      tempMin: minTemp,
      tempMax: maxTemp,
      humidityAvg: (sumHum / count).toDouble(),
      humidityMin: minHum,
      humidityMax: maxHum,
      precipTotal: sumPrecip,
      precipRateMax: maxPrecipRate,
      windAvg: (sumWind / count).toDouble(),
      windMin: minWind,
      windMax: maxWind,
      windGustMax: maxGust,
      windGustAvg: (sumWindGustAvg / count).toDouble(),
      windDirAvg: _circularMeanDegrees(windDirSin, windDirCos, windDirCount),
      pressureAvg: (sumPressure / count).toDouble(),
      pressureMin: minPressure,
      pressureMax: maxPressure,
      heatIndexAvg: (sumHeatIndex / count).toDouble(),
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

  double? _numNullable(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  Future<Map<String, double>> fetchTodayHourlyPrecip({
    required String apiKey,
    required String stationId,
  }) async {
    final now = DateTime.now();
    final dateStr = _formatDate(now);
    final uri = Uri.parse(
        'https://api.weather.com/v2/pws/history/hourly?apiKey=$apiKey&stationId=$stationId&format=json&units=m&date=$dateStr&numericPrecision=decimal');
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Failed to fetch today hourly: ${res.statusCode} ${res.body}');
    }
    final Map<String, dynamic> json = jsonDecode(res.body);
    final observations = json['observations'];
    if (observations is! List || observations.isEmpty) {
      return {'precipTotal': 0.0, 'precipRate': 0.0};
    }

    double maxPrecip = 0;
    double maxPrecipRate = 0;
    for (final obs in observations) {
      if (obs is! Map) continue;
      final metric = obs['metric'];
      if (metric is! Map) continue;
      final precip = _numNullable(metric['precipTotal']) ?? 0;
      final rate = _numNullable(metric['precipRate']) ?? 0;
      if (precip > maxPrecip) maxPrecip = precip;
      if (rate > maxPrecipRate) maxPrecipRate = rate;
    }
    return {'precipTotal': maxPrecip, 'precipRate': maxPrecipRate};
  }

  double _circularMeanDegrees(double sinSum, double cosSum, int count) {
    if (count == 0) return 0;
    final avgRad = math.atan2(sinSum / count, cosSum / count);
    var deg = avgRad * 180.0 / math.pi;
    if (deg < 0) deg += 360.0;
    return deg;
  }
}
