class Observation {
  final int? id;
  final int stationDbId;
  final int ts; // epoch seconds
  final double? temperature;
  final double? feelsLike;
  final double? dewPoint;
  final double? windSpeed;
  final double? windGust;
  final String? windDir;
  final double? precip;
  final double? pressure;
  final double? humidity;
  final double? tempIndoor;
  final double? humidityIndoor;

  Observation({
    this.id,
    required this.stationDbId,
    required this.ts,
    this.temperature,
    this.feelsLike,
    this.dewPoint,
    this.windSpeed,
    this.windGust,
    this.windDir,
    this.precip,
    this.pressure,
    this.humidity,
    this.tempIndoor,
    this.humidityIndoor,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'station_id': stationDbId,
      'ts': ts,
      'temperature': temperature,
      'feels_like': feelsLike,
      'dew_point': dewPoint,
      'wind_speed': windSpeed,
      'wind_gust': windGust,
      'wind_dir': windDir,
      'precip': precip,
      'pressure': pressure,
      'humidity': humidity,
      'temp_indoor': tempIndoor,
      'humidity_indoor': humidityIndoor,
    };
  }

  factory Observation.fromMap(Map<String, dynamic> m) => Observation(
        id: m['id'] as int?,
        stationDbId: m['station_id'] as int,
        ts: m['ts'] as int,
        temperature: (m['temperature'] as num?)?.toDouble(),
        feelsLike: (m['feels_like'] as num?)?.toDouble(),
        dewPoint: (m['dew_point'] as num?)?.toDouble(),
        windSpeed: (m['wind_speed'] as num?)?.toDouble(),
        windGust: (m['wind_gust'] as num?)?.toDouble(),
        windDir: m['wind_dir'] as String?,
        precip: (m['precip'] as num?)?.toDouble(),
        pressure: (m['pressure'] as num?)?.toDouble(),
        humidity: (m['humidity'] as num?)?.toDouble(),
        tempIndoor: (m['temp_indoor'] as num?)?.toDouble(),
        humidityIndoor: (m['humidity_indoor'] as num?)?.toDouble(),
      );
}
