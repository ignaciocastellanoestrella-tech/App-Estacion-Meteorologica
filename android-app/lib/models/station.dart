class Station {
  final int? id;
  final String name;
  final String stationId;
  final String apiKey;

  Station({this.id, required this.name, required this.stationId, required this.apiKey});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'station_id': stationId,
      'api_key': apiKey,
    };
  }

  factory Station.fromMap(Map<String, dynamic> m) => Station(
        id: m['id'] as int?,
        name: m['name'] as String,
        stationId: m['station_id'] as String,
        apiKey: m['api_key'] as String,
      );
}
