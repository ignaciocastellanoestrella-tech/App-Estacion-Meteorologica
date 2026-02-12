import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/weather.dart';

class WundergroundService {
  /// Fetch current observation for a given station credentials.
  Future<Weather> fetchCurrent({required String apiKey, required String stationId}) async {
    if (apiKey.isEmpty || stationId.isEmpty) {
      throw Exception('Wunderground API key or station id missing');
    }

    final uri = Uri.parse(
        'https://api.weather.com/v2/pws/observations/current?apiKey=$apiKey&stationId=$stationId&format=json&units=m');

    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Failed to fetch weather: ${res.statusCode} ${res.body}');
    }

    final Map<String, dynamic> json = jsonDecode(res.body);
    return Weather.fromWundergroundJson(json);
  }
}
