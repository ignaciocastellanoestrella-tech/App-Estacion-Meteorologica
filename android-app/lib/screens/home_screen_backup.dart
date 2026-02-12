import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/wunderground_service.dart';
import '../models/weather.dart';
import '../repositories/station_repository.dart';
import '../models/station.dart';
import 'settings_screen.dart';
import '../models/history_summary.dart';
import '../widgets/widget_helper.dart';

enum HistoryPeriod { day, week, month }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final WundergroundService _svc = WundergroundService();
  final StationRepository _stationRepo = StationRepository();

  Future<Weather>? _weatherFuture;
  List<Station> _stations = [];
  Station? _selected;
  HistoryPeriod _historyPeriod = HistoryPeriod.day;
  DateTime _historyDate = DateTime.now();
  int _historyWeek = 1;
  HistorySummary? _historySummary;
  bool _historyLoading = false;
  bool _historyExpanded = false;
  final Map<String, HistorySummary> _historyCache = {};
  DateTime _now = DateTime.now();
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _loadStationsAndFetch();
    _startPolling();
    _startClock();
  }

  Future _loadStationsAndFetch() async {
    _stations = await _stationRepo.getAll();
    if (_stations.isNotEmpty) {
      _selected = _stations.first;
      setState(() {
        _weatherFuture = _svc.fetchCurrent(apiKey: _selected!.apiKey, stationId: _selected!.stationId);
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
        await WidgetHelper.updateWeatherWidget(
          temperature: w.temperature,
          condition: w.condition,
          windSpeed: w.windSpeed,
          precip: w.precipToday,
          stationName: _selected?.name ?? 'Estación',
          humidity: w.humidity,
        );
      } catch (_) {}
    });
  }

  void _startClock() {
    _clockTimer ??= Timer.periodic(const Duration(seconds: 30), (_) {
      setState(() => _now = DateTime.now());
    });
  }

  Future<void> _loadHistory() async {
    if (_selected == null) return;
    final cacheKey = _historyCacheKey(_selected!);
    if (cacheKey != null) {
      final cached = _historyCache[cacheKey];
      if (cached != null) {
        setState(() {
          _historySummary = cached;
          _historyLoading = false;
        });
        return;
      }
    }
    setState(() => _historyLoading = true);
    try {
      final station = _selected!;
      late HistorySummary summary;
      if (_historyPeriod == HistoryPeriod.day) {
        summary = await _svc.fetchHistoryDaily(
          apiKey: station.apiKey,
          stationId: station.stationId,
          date: _historyDate,
        );
      } else {
        final range = _historyPeriod == HistoryPeriod.week
            ? _effectiveWeekRange(_historyDate, _historyWeek)
            : _monthRange(_historyDate);
        summary = await _svc.fetchHistoryRange(
          apiKey: station.apiKey,
          stationId: station.stationId,
          start: range.start,
          end: range.end,
        );
      }
      setState(() {
        _historySummary = summary;
        if (cacheKey != null) {
          _historyCache[cacheKey] = summary;
        }
        _historyLoading = false;
      });
    } catch (_) {
      setState(() {
        _historySummary = null;
        _historyLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _clockTimer?.cancel();
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
      body: FutureBuilder<Weather>(
        future: _weatherFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Error: ${snapshot.error}'),
            );
          }

          final weather = snapshot.data!;
          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFF7F3FF), Color(0xFFEFF7FF)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  Text('Estación Meteorológica', style: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFFE3E6EE)),
                      ),
                      child: Text(
                        _dateTimeLabel(_now),
                        style: GoogleFonts.manrope(fontSize: 11.5, color: Colors.black54, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.sensors, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButton<Station>(
                          isExpanded: true,
                          value: _selected,
                          hint: const Text('Selecciona estación'),
                          items: _stations
                              .map((s) => DropdownMenuItem(value: s, child: Text(_stationLabel(s))))
                              .toList(),
                          onChanged: (s) {
                            setState(() {
                              _selected = s;
                              _weatherFuture = _svc.fetchCurrent(apiKey: s!.apiKey, stationId: s.stationId);
                            });
                            if (_historyExpanded) {
                              _loadHistory();
                            }
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings),
                        onPressed: () async {
                          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
                          await _loadStationsAndFetch();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 0,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          _iconForCondition(weather.condition),
                          const SizedBox(height: 8),
                          Text('${weather.temperature.toStringAsFixed(1)} °C',
                              style: GoogleFonts.manrope(fontSize: 40, fontWeight: FontWeight.w800)),
                            Text('Sensación térmica ${weather.feelsLike.toStringAsFixed(1)} °C',
                              style: GoogleFonts.manrope(fontSize: 14, color: Colors.black54)),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              _chip('Humedad', '${weather.humidity.toStringAsFixed(1)} %'),
                              _chip('Punto de rocío', '${weather.dewPoint.toStringAsFixed(1)} °C'),
                              _chip('Presión', '${weather.pressure.toStringAsFixed(2)} hPa'),
                              _chip('Lluvia hoy', '${weather.precipToday.toStringAsFixed(1)} mm'),
                              _chip('Ratio precip.', '${weather.precipRate.toStringAsFixed(1)} mm/hr'),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _sectionTitle('Viento'),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Velocidad', style: GoogleFonts.manrope(fontSize: 12, color: Colors.black54)),
                              Text('${_toKmh(weather.windSpeed).toStringAsFixed(1)} km/h',
                                  style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Racha', style: GoogleFonts.manrope(fontSize: 12, color: Colors.black54)),
                              Text('${_toKmh(weather.windGust).toStringAsFixed(1)} km/h',
                                  style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Dirección', style: GoogleFonts.manrope(fontSize: 12, color: Colors.black54)),
                              Text(_windDirectionLabel(weather.windDir),
                                  style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
                            ],
                          ),
                          if (weather.tempIndoor != null || weather.humidityIndoor != null) ...[
                            const SizedBox(height: 12),
                            _sectionTitle('Interior'),
                            const SizedBox(height: 6),
                            if (weather.tempIndoor != null)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Temperatura', style: GoogleFonts.manrope(fontSize: 12, color: Colors.black54)),
                                  Text('${weather.tempIndoor!.toStringAsFixed(1)} °C',
                                      style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
                                ],
                              ),
                            if (weather.humidityIndoor != null)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Humedad', style: GoogleFonts.manrope(fontSize: 12, color: Colors.black54)),
                                  Text('${weather.humidityIndoor!.toStringAsFixed(1)} %',
                                      style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
                                ],
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 0,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            onTap: () {
                              setState(() => _historyExpanded = !_historyExpanded);
                              if (_historyExpanded && _historySummary == null) {
                                _loadHistory();
                              }
                            },
                            child: Row(
                              children: [
                                _sectionTitle('Historico'),
                                const Spacer(),
                                Icon(_historyExpanded ? Icons.expand_less : Icons.expand_more),
                              ],
                            ),
                          ),
                          if (_historyExpanded) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                DropdownButton<HistoryPeriod>(
                                  value: _historyPeriod,
                                  items: const [
                                    DropdownMenuItem(value: HistoryPeriod.day, child: Text('Diario')),
                                    DropdownMenuItem(value: HistoryPeriod.week, child: Text('Semanal')),
                                    DropdownMenuItem(value: HistoryPeriod.month, child: Text('Mensual')),
                                  ],
                                  onChanged: (p) {
                                    if (p == null) return;
                                    setState(() => _historyPeriod = p);
                                    _loadHistory();
                                  },
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: _historySelector()),
                              ],
                            ),
                            const SizedBox(height: 10),
                            if (_historyLoading)
                              const Center(child: CircularProgressIndicator())
                            else if (_historySummary == null)
                              const Text('Sin datos para el periodo seleccionado')
                            else
                              Wrap(
                                spacing: 12,
                                runSpacing: 8,
                                children: [
                                  _chip('Temp media', '${_historySummary!.tempAvg.toStringAsFixed(1)} °C'),
                                  _chip('Temp min', '${_historySummary!.tempMin.toStringAsFixed(1)} °C'),
                                  _chip('Temp max', '${_historySummary!.tempMax.toStringAsFixed(1)} °C'),
                                  _chip('Humedad media', '${_historySummary!.humidityAvg.toStringAsFixed(1)} %'),
                                  _chip('Lluvia total', '${_historySummary!.precipTotal.toStringAsFixed(1)} mm'),
                                  _chip('Ratio precip. max', '${_historySummary!.precipRateMax.toStringAsFixed(1)} mm/hr'),
                                  _chip('Viento medio', '${_toKmh(_historySummary!.windAvg).toStringAsFixed(1)} km/h'),
                                  _chip('Racha max', '${_toKmh(_historySummary!.windGustMax).toStringAsFixed(1)} km/h'),
                                  _chip('Presión media', '${_historySummary!.pressureAvg.toStringAsFixed(2)} hPa'),
                                ],
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _chip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text('$label: $value', style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(text, style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700));
  }

  double _toKmh(double value) => value;

  String _windDirectionLabel(String value) {
    final deg = double.tryParse(value.replaceAll(',', '.'));
    if (deg == null) return value;
    const labels = [
      'N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE',
      'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW'
    ];
    final idx = ((deg % 360) / 22.5).round() % labels.length;
    return labels[idx];
  }

  String _stationLabel(Station s) {
    if (s.name.trim().isEmpty || s.name == 'Default') return s.stationId;
    return s.name;
  }

  String? _historyCacheKey(Station station) {
    if (_historyPeriod == HistoryPeriod.day) {
      if (_isToday(_historyDate)) return null;
      return '${station.stationId}|day|${_formatDateKey(_historyDate)}';
    }
    if (_historyPeriod == HistoryPeriod.week) {
      final range = _effectiveWeekRange(_historyDate, _historyWeek);
      return '${station.stationId}|week|${_formatDateKey(range.start)}-${_formatDateKey(range.end)}';
    }
    final range = _monthRange(_historyDate);
    return '${station.stationId}|month|${_formatDateKey(range.start)}-${_formatDateKey(range.end)}';
  }

  String _formatDateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y$m$d';
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  String _dateTimeLabel(DateTime date) {
    final weekday = _weekdayLabel(date.weekday);
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    return '$weekday, $d/$m/$y • $hh:$mm';
  }

  String _weekdayLabel(int weekday) {
    const labels = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ];
    return labels[(weekday - 1).clamp(0, labels.length - 1)];
  }

  Widget _historySelector() {
    if (_historyPeriod == HistoryPeriod.day) {
      final label = '${_historyDate.year}-${_historyDate.month.toString().padLeft(2, '0')}-${_historyDate.day.toString().padLeft(2, '0')}';
      return Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _historyDate,
              firstDate: DateTime.now().subtract(const Duration(days: 365)),
              lastDate: DateTime.now(),
            );
            if (picked != null) {
              setState(() => _historyDate = picked);
              _loadHistory();
            }
          },
          child: Text(label),
        ),
      );
    }

    if (_historyPeriod == HistoryPeriod.week) {
      final ranges = _availableWeekRanges(_historyDate);
      if (ranges.isEmpty) {
        return const SizedBox.shrink();
      }
      if (_historyWeek > ranges.length) {
        _historyWeek = ranges.length;
      }
      final range = ranges[_historyWeek - 1];
      final rangeLabel = _rangeLabel(range.start, range.end);
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          DropdownButton<int>(
            value: _historyWeek,
            items: List.generate(
              ranges.length,
              (i) => DropdownMenuItem(value: i + 1, child: Text(_rangeLabel(ranges[i].start, ranges[i].end))),
            ),
            onChanged: (v) {
              if (v == null) return;
              setState(() => _historyWeek = v);
              _loadHistory();
            },
          ),
          const SizedBox(width: 8),
          Text(rangeLabel, style: GoogleFonts.manrope(fontSize: 12, color: Colors.black54)),
        ],
      );
    }

    final monthLabel = '${_historyDate.month.toString().padLeft(2, '0')}/${_historyDate.year}';
    return Align(
      alignment: Alignment.centerRight,
      child: Text(monthLabel, style: GoogleFonts.manrope(fontSize: 12, color: Colors.black54)),
    );
  }

  DateTimeRange _weekRange(DateTime date, int weekIndex) {
    final first = DateTime(date.year, date.month, 1);
    var start = first.add(Duration(days: (weekIndex - 1) * 7));
    final last = DateTime(date.year, date.month + 1, 0);
    if (start.isAfter(last)) start = last;
    var end = start.add(const Duration(days: 6));
    if (end.isAfter(last)) end = last;
    return DateTimeRange(start: start, end: end);
  }

  DateTimeRange _effectiveWeekRange(DateTime date, int weekIndex) {
    final range = _weekRange(date, weekIndex);
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    if (range.start.isAfter(today)) {
      throw Exception('Week range is in the future');
    }
    if (range.end.isAfter(today)) {
      return DateTimeRange(start: range.start, end: today);
    }
    return range;
  }

  List<DateTimeRange> _availableWeekRanges(DateTime date) {
    final weeks = _weeksInMonth(date);
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final ranges = <DateTimeRange>[];
    for (var i = 1; i <= weeks; i++) {
      final range = _weekRange(date, i);
      if (range.start.isAfter(today)) continue;
      ranges.add(_effectiveWeekRange(date, i));
    }
    return ranges;
  }

  int _weeksInMonth(DateTime date) {
    final first = DateTime(date.year, date.month, 1);
    final last = DateTime(date.year, date.month + 1, 0);
    final days = last.day + first.weekday - 1;
    return (days / 7).ceil();
  }

  DateTimeRange _monthRange(DateTime date) {
    final start = DateTime(date.year, date.month, 1);
    final end = DateTime(date.year, date.month + 1, 0);
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    if (start.isAfter(today)) {
      throw Exception('Month range is in the future');
    }
    final effectiveEnd = end.isAfter(today) ? today : end;
    return DateTimeRange(start: start, end: effectiveEnd);
  }

  String _rangeLabel(DateTime start, DateTime end) {
    final s = '${start.day.toString().padLeft(2, '0')}/${start.month.toString().padLeft(2, '0')}';
    final e = '${end.day.toString().padLeft(2, '0')}/${end.month.toString().padLeft(2, '0')}';
    return '$s - $e';
  }
}
