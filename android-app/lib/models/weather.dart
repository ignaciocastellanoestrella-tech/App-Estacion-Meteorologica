class Weather {
  final double temperature;
  final double feelsLike;
  final double dewPoint;
  final double windSpeed;
  final double windGust;
  final String windDir;
  final double precipToday;
  final double precipRate;
  final double pressure;
  final String condition;
  final double humidity;
  final double? tempIndoor;
  final double? humidityIndoor;

  Weather({
    required this.temperature,
    required this.feelsLike,
    required this.dewPoint,
    required this.windSpeed,
    required this.windGust,
    required this.windDir,
    required this.precipToday,
    required this.precipRate,
    required this.pressure,
    required this.condition,
    required this.humidity,
    this.tempIndoor,
    this.humidityIndoor,
  });

  factory Weather.fromWundergroundJson(Map<String, dynamic> json) {
    // This mapping may need adjustment depending on the exact API response structure.
    final obs = json['observations'] != null && json['observations'].isNotEmpty
        ? json['observations'][0]
        : json;

    return Weather.fromObservation(obs);
  }

  factory Weather.fromObservation(Map<String, dynamic> obs) {
    return Weather(
      temperature: _num(obs['metric']?['temp'] ?? obs['temp']),
      feelsLike: _num(obs['metric']?['heatIndex'] ?? obs['feelslike']),
      dewPoint: _num(obs['metric']?['dewpt'] ?? obs['dewPoint']),
      windSpeed: _num(obs['metric']?['windSpeed'] ?? obs['windSpeed']),
      windGust: _num(obs['metric']?['windGust'] ?? obs['gust'] ?? obs['windGust']),
      windDir: obs['winddir']?.toString() ?? obs['windDir']?.toString() ?? 'N',
      precipToday: _num(obs['metric']?['precipTotal'] ?? obs['precip_total']),
      precipRate: _num(obs['metric']?['precipRate'] ?? obs['precip_rate']),
      pressure: _num(obs['metric']?['pressure'] ?? obs['pressure']),
      condition: obs['weather']?.toString() ?? obs['obsType']?.toString() ?? 'Unknown',
      humidity: _num(obs['humidity']),
      tempIndoor: _numNullable(obs['metric']?['tempIndoor'] ?? obs['tempIndoor']),
      humidityIndoor: _numNullable(obs['humidityIndoor']),
    );
  }

  static double _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  static double? _numNullable(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}
