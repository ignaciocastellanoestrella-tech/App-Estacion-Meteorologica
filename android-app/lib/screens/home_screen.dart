import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:weather_icons/weather_icons.dart';
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

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final WundergroundService _svc = WundergroundService();
  final StationRepository _stationRepo = StationRepository();
  final ScrollController _scrollController = ScrollController();

  Future<Weather>? _weatherFuture;
  List<Station> _stations = [];
  Station? _selected;
  bool _isRefreshing = false;
  HistoryPeriod _historyPeriod = HistoryPeriod.day;
  DateTime _historyDate = DateTime.now();
  int _historyWeek = 1;
  HistorySummary? _historySummary;
  bool _historyLoading = false;
  final Map<String, HistorySummary> _historyCache = {};
  DateTime _now = DateTime.now();
  Timer? _clockTimer;
  Timer? _pollTimer;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadStationsAndFetch();
    _startPolling();
    _startClock();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _clockTimer?.cancel();
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future _loadStationsAndFetch() async {
    _stations = await _stationRepo.getAll();
    if (_stations.isNotEmpty) {
      _selected = _stations.first;
      // Fetch current weather and update widget on app start
      final weather = await _svc.fetchCurrent(apiKey: _selected!.apiKey, stationId: _selected!.stationId);
      setState(() {
        _weatherFuture = Future.value(weather);
      });
      _updateWidget(weather);
    }
  }

  void _startPolling() {
    _pollTimer ??= Timer.periodic(const Duration(seconds: 30), (_) {
      if (_selected != null) {
        _svc.fetchCurrent(apiKey: _selected!.apiKey, stationId: _selected!.stationId).then((weather) {
          if (mounted) {
            setState(() {
              _weatherFuture = Future.value(weather);
              _now = DateTime.now();
            });
            _updateWidget(weather);
          }
        });
      } else {
        if (mounted) {
          setState(() => _now = DateTime.now());
        }
      }
    });
  }

  void _startClock() {
    _clockTimer ??= Timer.periodic(const Duration(seconds: 30), (_) {
      setState(() => _now = DateTime.now());
    });
  }

  Future<void> _manualRefresh() async {
    if (_selected == null || _isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      final weather = await _svc.fetchCurrent(apiKey: _selected!.apiKey, stationId: _selected!.stationId);
      setState(() {
        _weatherFuture = Future.value(weather);
        _now = DateTime.now();
      });
      _updateWidget(weather);
    } finally {
      setState(() => _isRefreshing = false);
    }
  }

  Future<void> _updateWidget(Weather weather) async {
    if (_selected != null) {
      await WidgetHelper.updateWeatherWidget(
        stationName: _stationLabel(_selected!),
        temperature: weather.temperature,
        condition: weather.condition,
        humidity: weather.humidity,
        windSpeed: weather.windSpeed,
        precip: weather.precipToday,
        pressure: weather.pressure,
        precipRate: weather.precipRate,
      );
    }
  }

  Future<void> _loadHistory() async {
    if (_selected == null) return;
    final cacheKey = _historyCacheKey(_selected!);
    if (cacheKey != null && _historyCache.containsKey(cacheKey)) {
      setState(() {
        _historySummary = _historyCache[cacheKey];
        _historyLoading = false;
      });
      return;
    }
    setState(() => _historyLoading = true);
    try {
      HistorySummary summary;
      if (_historyPeriod == HistoryPeriod.day) {
        summary = await _svc.fetchHistoryDaily(
          apiKey: _selected!.apiKey,
          stationId: _selected!.stationId,
          date: _historyDate,
        );
      } else if (_historyPeriod == HistoryPeriod.week) {
        final range = _effectiveWeekRange(_historyDate, _historyWeek);
        summary = await _svc.fetchHistoryRange(
          apiKey: _selected!.apiKey,
          stationId: _selected!.stationId,
          start: range.start,
          end: range.end,
        );
      } else {
        final range = _monthRange(_historyDate);
        summary = await _svc.fetchHistoryRange(
          apiKey: _selected!.apiKey,
          stationId: _selected!.stationId,
          start: range.start,
          end: range.end,
        );
      }
      setState(() {
        _historySummary = summary;
        _historyLoading = false;
      });
      if (cacheKey != null) {
        _historyCache[cacheKey] = summary;
      }
    } catch (e) {
      setState(() {
        _historySummary = null;
        _historyLoading = false;
      });
    }
  }

  Widget _weatherIcon(String condition) {
    final c = condition.toLowerCase();
    if (c.contains('thunder') || c.contains('storm')) {
      return const Icon(WeatherIcons.thunderstorm, size: 80, color: Color(0xFF6B7AFA));
    }
    if (c.contains('rain') || c.contains('shower')) {
      return const Icon(WeatherIcons.rain, size: 80, color: Color(0xFF5BA3F5));
    }
    if (c.contains('snow')) {
      return const Icon(WeatherIcons.snow, size: 80, color: Color(0xFF8EC5FC));
    }
    if (c.contains('fog') || c.contains('mist')) {
      return const Icon(WeatherIcons.fog, size: 80, color: Color(0xFF9CA3AF));
    }
    if (c.contains('cloud')) {
      return const Icon(WeatherIcons.cloudy, size: 80, color: Color(0xFF94A3B8));
    }
    if (c.contains('clear') || c.contains('sunny')) {
      return const Icon(WeatherIcons.day_sunny, size: 80, color: Color(0xFFFFA726));
    }
    return const Icon(WeatherIcons.day_cloudy, size: 80, color: Color(0xFFFFB74D));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<Weather>(
        future: _weatherFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Center(child: CircularProgressIndicator(color: Colors.white)),
            );
          }
          if (snapshot.hasError) {
            return Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white)),
                ),
              ),
            );
          }

          final weather = snapshot.data!;
          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  _buildTabBar(),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildCurrentTab(weather),
                        _buildHistoryTab(),
                      ],
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

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Estación Meteorológica',
                      style: GoogleFonts.manrope(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _dateTimeLabel(_now),
                        style: GoogleFonts.manrope(
                          fontSize: 11.5,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _isRefreshing
                  ? const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white, size: 28),
                      onPressed: _manualRefresh,
                      tooltip: 'Refrescar datos',
                    ),
              IconButton(
                icon: const Icon(Icons.settings, color: Colors.white, size: 28),
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                  await _loadStationsAndFetch();
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.sensors, size: 20, color: Color(0xFF667EEA)),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButton<Station>(
                    isExpanded: true,
                    underline: const SizedBox(),
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
                      if (_tabController.index == 1) {
                        _loadHistory();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        dividerColor: Colors.transparent,
        labelColor: const Color(0xFF667EEA),
        unselectedLabelColor: Colors.white,
        labelStyle: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 15),
        unselectedLabelStyle: GoogleFonts.manrope(fontWeight: FontWeight.w600, fontSize: 15),
        labelPadding: EdgeInsets.zero,
        onTap: (index) {
          if (index == 1 && _historySummary == null && !_historyLoading) {
            _loadHistory();
          }
        },
        tabs: const [
          Tab(text: 'Actual'),
          Tab(text: 'Histórico'),
        ],
      ),
    );
  }

  Widget _buildCurrentTab(Weather weather) {
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.all(16.0),
      children: [
        const SizedBox(height: 8),
        Card(
          elevation: 8,
          shadowColor: Colors.black.withOpacity(0.3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFFFFF), Color(0xFFF8F9FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                _weatherIcon(weather.condition),
                const SizedBox(height: 16),
                Text(
                  '${weather.temperature.toStringAsFixed(1)} °C',
                  style: GoogleFonts.manrope(
                    fontSize: 56,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1F2937),
                  ),
                ),
                Text(
                  'Sensación térmica ${weather.feelsLike.toStringAsFixed(1)} °C',
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    _modernChip(Icons.water_drop, 'Humedad', '${weather.humidity.toStringAsFixed(1)} %'),
                    _modernChip(Icons.thermostat, 'Punto rocío', '${weather.dewPoint.toStringAsFixed(1)} °C'),
                    _modernChip(Icons.speed, 'Presión', '${weather.pressure.toStringAsFixed(2)} hPa'),
                    _modernChip(Icons.umbrella, 'Lluvia hoy', '${weather.precipToday.toStringAsFixed(1)} mm'),
                    _modernChip(Icons.water, 'Ratio precip.', '${weather.precipRate.toStringAsFixed(1)} mm/hr'),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 8,
          shadowColor: Colors.black.withOpacity(0.3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFFFFF), Color(0xFFF0F9FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(WeatherIcons.strong_wind, size: 20, color: Color(0xFF667EEA)),
                    const SizedBox(width: 8),
                    Text(
                      'Viento',
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1F2937),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _infoRow('Velocidad', '${weather.windSpeed.toStringAsFixed(1)} km/h'),
                _infoRow('Ráfaga', '${weather.windGust.toStringAsFixed(1)} km/h'),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Dirección',
                      style: GoogleFonts.manrope(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w500),
                    ),
                    Row(
                      children: [
                        Text(
                          _windDirectionLabel(weather.windDir),
                          style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1F2937)),
                        ),
                        const SizedBox(width: 8),
                        Transform.rotate(
                          angle: (double.tryParse(weather.windDir) ?? 0) * 3.14159 / 180,
                          child: Icon(
                            Icons.navigation,
                            size: 20,
                            color: weather.windSpeed > 30 ? Colors.red : const Color(0xFF667EEA),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (weather.tempIndoor != null || weather.humidityIndoor != null) ...[
          const SizedBox(height: 16),
          Card(
            elevation: 8,
            shadowColor: Colors.black.withOpacity(0.3),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFFFFF), Color(0xFFFFF7ED)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.home, size: 20, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 8),
                      Text(
                        'Interior',
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1F2937),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (weather.tempIndoor != null)
                    _infoRow('Temperatura', '${weather.tempIndoor!.toStringAsFixed(1)} °C'),
                  if (weather.humidityIndoor != null)
                    _infoRow('Humedad', '${weather.humidityIndoor!.toStringAsFixed(1)} %'),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildHistoryTab() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        const SizedBox(height: 8),
        Card(
          elevation: 8,
          shadowColor: Colors.black.withOpacity(0.3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFFFFF), Color(0xFFF8F9FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Datos históricos',
                  style: GoogleFonts.manrope(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButton<HistoryPeriod>(
                          isExpanded: true,
                          underline: const SizedBox(),
                          value: _historyPeriod,
                          isDense: true,
                          style: GoogleFonts.manrope(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w600),
                          items: const [
                            DropdownMenuItem(value: HistoryPeriod.day, child: Text('Día')),
                            DropdownMenuItem(value: HistoryPeriod.week, child: Text('Semana')),
                            DropdownMenuItem(value: HistoryPeriod.month, child: Text('Mes')),
                          ],
                          onChanged: (p) {
                            if (p == null) return;
                            setState(() => _historyPeriod = p);
                            _loadHistory();
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: _historySelector()),
                  ],
                ),
                const SizedBox(height: 16),
                if (_historyLoading)
                  const Center(child: CircularProgressIndicator())
                else if (_historySummary == null)
                  Center(
                    child: Text(
                      'Sin datos para el periodo seleccionado',
                      style: GoogleFonts.manrope(color: Colors.black54),
                    ),
                  )
                else ...[
                  _historyCard('Temperatura', [
                    _historyItem('Media', '${_historySummary!.tempAvg.toStringAsFixed(1)} °C', Icons.thermostat),
                    _historyItem('Mínima', '${_historySummary!.tempMin.toStringAsFixed(1)} °C', Icons.arrow_downward),
                    _historyItem('Máxima', '${_historySummary!.tempMax.toStringAsFixed(1)} °C', Icons.arrow_upward),
                  ]),
                  const SizedBox(height: 12),
                  _historyCard('Precipitación', [
                    _historyItem('Total', '${_historySummary!.precipTotal.toStringAsFixed(1)} mm', Icons.umbrella),
                    _historyItem('Ratio máx', '${_historySummary!.precipRateMax.toStringAsFixed(1)} mm/hr', Icons.water),
                  ]),
                  const SizedBox(height: 12),
                  _historyCard('Viento', [
                    _historyItem('Media', '${_historySummary!.windAvg.toStringAsFixed(1)} km/h', WeatherIcons.strong_wind),
                    _historyItem('Racha máx', '${_historySummary!.windGustMax.toStringAsFixed(1)} km/h', WeatherIcons.wind),
                  ]),
                  const SizedBox(height: 12),
                  _historyCard('Otros', [
                    _historyItem('Humedad media', '${_historySummary!.humidityAvg.toStringAsFixed(1)} %', Icons.water_drop),
                    _historyItem('Presión media', '${_historySummary!.pressureAvg.toStringAsFixed(2)} hPa', Icons.speed),
                  ]),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _modernChip(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF667EEA).withOpacity(0.1), const Color(0xFF764BA2).withOpacity(0.1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF667EEA).withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF667EEA)),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.manrope(fontSize: 10, color: Colors.black54, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF1F2937)),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.manrope(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1F2937)),
          ),
        ],
      ),
    );
  }

  Widget _historyCard(String title, List<Widget> items) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF667EEA).withOpacity(0.05), const Color(0xFF764BA2).withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF667EEA).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF667EEA)),
          ),
          const SizedBox(height: 8),
          ...items,
        ],
      ),
    );
  }

  Widget _historyItem(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF667EEA)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.manrope(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF1F2937)),
          ),
        ],
      ),
    );
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
    const labels = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
    return labels[(weekday - 1).clamp(0, labels.length - 1)];
  }

  String _windDirectionLabel(String value) {
    final deg = double.tryParse(value.replaceAll(',', '.'));
    if (deg == null) return value;
    const labels = ['N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE', 'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW'];
    final idx = ((deg % 360) / 22.5).round() % labels.length;
    return labels[idx];
  }

  Widget _historySelector() {
    if (_historyPeriod == HistoryPeriod.day) {
      final label = '${_historyDate.year}-${_historyDate.month.toString().padLeft(2, '0')}-${_historyDate.day.toString().padLeft(2, '0')}';
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: TextButton(
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _historyDate,
              firstDate: DateTime(2020, 1, 1),
              lastDate: DateTime.now(),
            );
            if (picked != null) {
              setState(() => _historyDate = picked);
              _loadHistory();
            }
          },
          child: Text(label, style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      );
    }
    if (_historyPeriod == HistoryPeriod.week) {
      final ranges = _availableWeekRanges(_historyDate);
      if (ranges.isEmpty) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text('Sin semanas', style: GoogleFonts.manrope(fontSize: 13)),
        );
      }
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: DropdownButton<int>(
          isExpanded: true,
          underline: const SizedBox(),
          value: _historyWeek.clamp(1, ranges.length),
          items: List.generate(ranges.length, (i) {
            final r = ranges[i];
            return DropdownMenuItem(value: i + 1, child: Text(_rangeLabel(r.start, r.end)));
          }),
          onChanged: (w) {
            if (w == null) return;
            setState(() => _historyWeek = w);
            _loadHistory();
          },
        ),
      );
    }
    final label = '${_historyDate.year}-${_historyDate.month.toString().padLeft(2, '0')}';
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextButton(
        onPressed: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: _historyDate,
            firstDate: DateTime(2020, 1, 1),
            lastDate: DateTime.now(),
          );
          if (picked != null) {
            setState(() => _historyDate = DateTime(picked.year, picked.month, 1));
            _loadHistory();
          }
        },
        child: Text(label, style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600)),
      ),
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
    final effectiveEnd = range.end.isAfter(today) ? today : range.end;
    return DateTimeRange(start: range.start, end: effectiveEnd);
  }

  List<DateTimeRange> _availableWeekRanges(DateTime date) {
    final ranges = <DateTimeRange>[];
    final weeks = _weeksInMonth(date);
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
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
