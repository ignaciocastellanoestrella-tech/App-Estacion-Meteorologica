class Weather {
  final double temperature;
  final double feelsLike;
  final double dewPoint;
  final double windSpeed;
  final double windGust;
  final String windDir;
  final double precipToday;
  final double pressure;
  final String condition;

  Weather({
    required this.temperature,
    required this.feelsLike,
    required this.dewPoint,
    required this.windSpeed,
    required this.windGust,
    required this.windDir,
    required this.precipToday,
    required this.pressure,
    required this.condition,
  });

  factory Weather.fromWundergroundJson(Map<String, dynamic> json) {
    // This mapping may need adjustment depending on the exact API response structure.
    final obs = json['observations'] != null && json['observations'].isNotEmpty
        ? json['observations'][0]
        : json;

    return Weather(
      temperature: (obs['metric']?['temp'] ?? obs['temp'] ?? 0).toDouble(),
      feelsLike: (obs['metric']?['heatIndex'] ?? obs['feelslike'] ?? 0).toDouble(),
      dewPoint: (obs['metric']?['dewpt'] ?? obs['dewPoint'] ?? 0).toDouble(),
      windSpeed: (obs['metric']?['windSpeed'] ?? obs['windSpeed'] ?? 0).toDouble(),
      windGust: (obs['metric']?['gust'] ?? obs['windGust'] ?? 0).toDouble(),
      windDir: obs['winddir']?.toString() ?? obs['windDir']?.toString() ?? 'N',
      precipToday: (obs['metric']?['precipTotal'] ?? obs['precip_total'] ?? 0).toDouble(),
      pressure: (obs['metric']?['pressure'] ?? obs['pressure'] ?? 0).toDouble(),
      condition: obs['weather']?.toString() ?? obs['obsType']?.toString() ?? 'Unknown',
    );
  }
}
