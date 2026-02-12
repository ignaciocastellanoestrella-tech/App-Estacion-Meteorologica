import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/home_screen.dart';
import 'repositories/station_repository.dart';
import 'models/station.dart';

// Seed default station from .env if DB empty
Future<void> _maybeSeedDefaultStation() async {
  final repo = StationRepository();
  final count = await repo.count();
  if (count == 0) {
    final defaultApi = dotenv.env['WUNDERGROUND_API_KEY'] ?? '';
    final defaultStation = dotenv.env['WUNDERGROUND_STATION_ID'] ?? '';
    if (defaultApi.isNotEmpty && defaultStation.isNotEmpty) {
      await repo.create(Station(name: 'Default', stationId: defaultStation, apiKey: defaultApi));
    }
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
    await _maybeSeedDefaultStation();
    runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Estación Meteorológica',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomeScreen(),
    );
  }
}
