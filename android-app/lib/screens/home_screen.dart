import 'dart:async';
import 'package:flutter/material.dart';
import '../services/wunderground_service.dart';
import '../models/weather.dart';
import '../repositories/station_repository.dart';
import '../models/station.dart';
import 'settings_screen.dart';
import '../models/observation.dart';
import '../repositories/observation_repository.dart';
import '../widgets/widget_helper.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final WundergroundService _svc = WundergroundService();
  final StationRepository _stationRepo = StationRepository();
  final ObservationRepository _obsRepo = ObservationRepository();

  Future<Weather>? _weatherFuture;
  List<Station> _stations = [];
  Station? _selected;

  @override
  void initState() {
    super.initState();
    _loadStationsAndFetch();
    _startPolling();
  }

  Future _loadStationsAndFetch() async {
    _stations = await _stationRepo.getAll();
    if (_stations.isNotEmpty) {
      _selected = _stations.first;
      setState(() {
        _weatherFuture = _svc.fetchCurrent(apiKey: _selected!.apiKey, stationId: _selected!.stationId);
        _weatherFuture!.then((w) async {
          // Save observation to DB
          final now = DateTime.now().toUtc();
          final obs = Observation(
            stationDbId: _selected!.id!,
            ts: now.millisecondsSinceEpoch ~/ 1000,
            temperature: w.temperature,
            feelsLike: w.feelsLike,
            dewPoint: w.dewPoint,
            windSpeed: w.windSpeed,
            windGust: w.windGust,
            windDir: w.windDir,
            precip: w.precipToday,
            pressure: w.pressure,
          );
          try {
            await _obsRepo.create(obs);
          } catch (_) {}
        });
      });
    }
  }

  // Periodic polling every 30 seconds to refresh; save to DB only when needed.
  Timer? _pollTimer;

  void _startPolling() {
    _pollTimer ??= Timer.periodic(const Duration(seconds: 30), (_) async {
      if (_selected == null) return;
      try {
        final w = await _svc.fetchCurrent(apiKey: _selected!.apiKey, stationId: _selected!.stationId);
        setState(() {
          _weatherFuture = Future.value(w);
        });

        // Decide whether to persist this observation to DB.
        final last = await _obsRepo.getLastObservation(_selected!.id!);
        final nowTs = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
        var shouldSave = false;
        if (last == null) {
          shouldSave = true;
        } else {
          final age = nowTs - last.ts;
          // Save if older than 5 minutes
          if (age >= 5 * 60) shouldSave = true;

          // Or if significant changes: temp>0.5°C, precip increased >0.1mm, wind gust >1m/s
          if (!shouldSave) {
            if ((w.temperature - (last.temperature ?? 0)).abs() >= 0.5) shouldSave = true;
            if ((w.precipToday - (last.precip ?? 0)).abs() >= 0.1) shouldSave = true;
            if ((w.windGust - (last.windGust ?? 0)).abs() >= 1.0) shouldSave = true;
          }
        }

        if (shouldSave) {
          final obs = Observation(
            stationDbId: _selected!.id!,
            ts: nowTs,
            temperature: w.temperature,
            feelsLike: w.feelsLike,
            dewPoint: w.dewPoint,
            windSpeed: w.windSpeed,
            windGust: w.windGust,
            windDir: w.windDir,
            precip: w.precipToday,
            pressure: w.pressure,
          );
          try {
            await _obsRepo.create(obs);
            // Update widget after saving
            await WidgetHelper.updateWeatherWidget(
              temperature: w.temperature,
              condition: w.condition,
              windSpeed: w.windSpeed,
              precip: w.precipToday,
              stationName: _selected?.name ?? 'Estación',
            );
          } catch (_) {}
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Widget _iconForCondition(String cond) {
    final c = cond.toLowerCase();
    if (c.contains('rain') || c.contains('shower') || c.contains('storm')) {
      return const Icon(Icons.umbrella, size: 64, color: Colors.blueAccent);
    }
    if (c.contains('cloud')) return const Icon(Icons.cloud, size: 64);
    return const Icon(Icons.wb_sunny, size: 64, color: Colors.orangeAccent);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Estación Meteorológica')),
      body: Center(
        child: FutureBuilder<Weather>(
          future: _weatherFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const CircularProgressIndicator();
            }
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Error: ${snapshot.error}'),
              );
            }

            final weather = snapshot.data!;

              return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Estación: '),
                      DropdownButton<Station>(
                        value: _selected,
                        hint: const Text('Selecciona'),
                        items: _stations.map((s) => DropdownMenuItem(value: s, child: Text(s.name))).toList(),
                        onChanged: (s) {
                          setState(() {
                            _selected = s;
                            _weatherFuture = _svc.fetchCurrent(apiKey: s!.apiKey, stationId: s.stationId);
                          });
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.show_chart),
                        onPressed: () async {
                          if (_selected != null) {
                            await Navigator.of(context).push(MaterialPageRoute(builder: (_) => GraphsScreen(station: _selected!)));
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings),
                        onPressed: () async {
                          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
                          await _loadStationsAndFetch();
                        },
                      )
                    ],
                  ),
                  _iconForCondition(weather.condition),
                  const SizedBox(height: 12),
                  Text('${weather.temperature.toStringAsFixed(1)} °C', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Sensación: ${weather.feelsLike.toStringAsFixed(1)} °C'),
                  Text('Punto de rocío: ${weather.dewPoint.toStringAsFixed(1)} °C'),
                  const SizedBox(height: 8),
                  Text('Viento: ${weather.windSpeed.toStringAsFixed(1)} m/s  Racha: ${weather.windGust.toStringAsFixed(1)} m/s'),
                  Text('Dirección: ${weather.windDir}'),
                  const SizedBox(height: 8),
                  Text('Precipitación hoy: ${weather.precipToday.toStringAsFixed(1)} mm'),
                  Text('Presión: ${weather.pressure.toStringAsFixed(1)} hPa'),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.mobile_friendly),
                    label: const Text('Actualizar widget'),
                    onPressed: () async {
                      try {
                        await WidgetHelper.updateWeatherWidget(
                          temperature: weather.temperature,
                          condition: weather.condition,
                          windSpeed: weather.windSpeed,
                          precip: weather.precipToday,
                          stationName: _selected?.name ?? 'Estación',
                        );
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Widget actualizado')));
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo actualizar el widget')));
                      }
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
