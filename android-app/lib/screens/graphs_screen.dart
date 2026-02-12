import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../repositories/observation_repository.dart';
import '../models/station.dart';
import '../services/report_service.dart';

enum Period { day, week, month }

class GraphsScreen extends StatefulWidget {
  final Station station;
  const GraphsScreen({super.key, required this.station});

  @override
  State<GraphsScreen> createState() => _GraphsScreenState();
}

class _GraphsScreenState extends State<GraphsScreen> {
  final ObservationRepository _obsRepo = ObservationRepository();
  final ReportService _reportService = ReportService();
  List<FlSpot> _spots = [];
  Period _period = Period.day;
  Map<String, dynamic> _summary = {};
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadForPeriod(_period);
  }
  Future _loadForPeriod(Period p) async {
    DateTime now = DateTime.now().toUtc();
    DateTime from;
    switch (p) {
      case Period.day:
        from = now.subtract(const Duration(hours: 24));
        break;
      case Period.week:
        from = now.subtract(const Duration(days: 7));
        break;
      case Period.month:
        from = DateTime(now.year, now.month - 1, now.day, now.hour, now.minute);
        break;
    }

    final toTs = now.millisecondsSinceEpoch ~/ 1000;
    final fromTs = from.millisecondsSinceEpoch ~/ 1000;
    setState(() => _loading = true);
    final obs = await _obsRepo.getBetween(widget.station.id!, fromTs, toTs);
    final summary = await _obsRepo.summaryForPeriod(widget.station.id!, fromTs, toTs);
    _summary = summary;
    if (obs.isEmpty) {
      setState(() {
        _spots = [];
        _loading = false;
      });
      return;
    }

    // Build spots according to period granularity
    if (p == Period.day) {
      final byHour = <int, List<double>>{};
      for (final o in obs) {
        final dt = DateTime.fromMillisecondsSinceEpoch(o.ts * 1000, isUtc: true).toLocal();
        final hour = dt.hour;
        byHour.putIfAbsent(hour, () => []).add(o.temperature ?? 0);
      }
      final spots = <FlSpot>[];
      for (var h = 0; h < 24; h++) {
        final vals = byHour[h] ?? [];
        final y = vals.isEmpty ? 0.0 : vals.reduce((a, b) => a + b) / vals.length;
        spots.add(FlSpot(h.toDouble(), y));
      }
      setState(() {
        _spots = spots;
        _loading = false;
      });
    } else {
      // For week/month/year, use daily averages
      final byDay = <int, List<double>>{}; // day offset -> temps
      final startDay = DateTime.fromMillisecondsSinceEpoch(from.millisecondsSinceEpoch, isUtc: true).toLocal();
      for (final o in obs) {
        final dt = DateTime.fromMillisecondsSinceEpoch(o.ts * 1000, isUtc: true).toLocal();
        final dayIndex = dt.difference(startDay).inDays;
        byDay.putIfAbsent(dayIndex, () => []).add(o.temperature ?? 0);
      }
      final days = (now.toLocal().difference(startDay)).inDays + 1;
      final spots = <FlSpot>[];
      for (var d = 0; d < days; d++) {
        final vals = byDay[d] ?? [];
        final y = vals.isEmpty ? 0.0 : vals.reduce((a, b) => a + b) / vals.length;
        spots.add(FlSpot(d.toDouble(), y));
      }
      setState(() {
        _spots = spots;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Gráficas - ${widget.station.name}'),
          bottom: TabBar(onTap: (i) {
            final p = Period.values[i];
            setState(() => _period = p);
            _loadForPeriod(p);
          }, tabs: const [Tab(text: 'Día'), Tab(text: 'Semana'), Tab(text: 'Mes')]),
          actions: [
            IconButton(
                onPressed: () async {
                  // export PDF for the current period
                  final now = DateTime.now();
                  DateTime from;
                  String title;
                  switch (_period) {
                    case Period.day:
                      from = now.subtract(const Duration(hours: 24));
                      title = 'Informe_Diario';
                      break;
                    case Period.week:
                      from = now.subtract(const Duration(days: 7));
                      title = 'Informe_Semanal';
                      break;
                    case Period.month:
                      from = DateTime(now.year, now.month - 1, now.day);
                      title = 'Informe_Mensual';
                      break;
                  }
                  final path = await _reportService.generateAndSavePdf(widget.station.id!, from, now, title);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF guardado: $path')));
                },
                icon: const Icon(Icons.picture_as_pdf))
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_periodLabel(_period), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    const Text('Fuente: observaciones guardadas en el dispositivo', style: TextStyle(fontSize: 12, color: Colors.black54)),
                    const SizedBox(height: 6),
                    _summary.isEmpty
                        ? const Text('Sin resumen para el periodo seleccionado')
                        : Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              _summaryChip('Temp media', _fmt(_summary['temp_avg'], '°C')),
                              _summaryChip('Temp min', _fmt(_summary['temp_min'], '°C')),
                              _summaryChip('Temp max', _fmt(_summary['temp_max'], '°C')),
                              _summaryChip('Humedad media', _fmt(_summary['humidity_avg'], '%')),
                              _summaryChip('Lluvia total', _fmt(_summary['precip_total'], 'mm')),
                            ],
                          ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _spots.isEmpty
                          ? const Center(child: Text('No hay datos para el periodo seleccionado'))
                          : LineChart(LineChartData(
                              minX: 0,
                              maxX: _spots.last.x,
                              minY: _spots.map((s) => s.y).reduce((a, b) => a < b ? a : b) - 2,
                              maxY: _spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) + 2,
                              lineBarsData: [LineChartBarData(spots: _spots, isCurved: true, dotData: FlDotData(show: false))],
                            )),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  String _periodLabel(Period p) {
    switch (p) {
      case Period.day:
        return 'Ultimas 24 horas (media por hora)';
      case Period.week:
        return 'Ultimos 7 dias (media diaria)';
      case Period.month:
        return 'Ultimos 30 dias (media diaria)';
    }
  }

  Widget _summaryChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.blueGrey.shade50, borderRadius: BorderRadius.circular(16)),
      child: Text('$label: $value', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  String _fmt(dynamic v, String unit) {
    if (v == null) return '--';
    if (v is num) return '${v.toStringAsFixed(1)} $unit';
    return '$v $unit';
  }
}

