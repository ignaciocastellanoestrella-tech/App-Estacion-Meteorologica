import 'dart:typed_data';
import 'dart:io';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import '../repositories/observation_repository.dart';

class ReportService {
  final ObservationRepository _obsRepo = ObservationRepository();

  Future<Uint8List> generateReportPdf(int stationDbId, DateTime from, DateTime to, String title) async {
    final pdf = pw.Document();
    final fromTs = from.toUtc().millisecondsSinceEpoch ~/ 1000;
    final toTs = to.toUtc().millisecondsSinceEpoch ~/ 1000;
    final summary = await _obsRepo.summaryForPeriod(stationDbId, fromTs, toTs);

    pdf.addPage(pw.Page(build: (ctx) {
      return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(title, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.Text('Periodo: ${from.toIso8601String()} - ${to.toIso8601String()}'),
        pw.SizedBox(height: 8),
        pw.Text('Resumen:'),
        pw.Bullet(text: 'Temperatura media: ${_fmt(summary['temp_avg'])} °C'),
        pw.Bullet(text: 'Temperatura mínima: ${_fmt(summary['temp_min'])} °C'),
        pw.Bullet(text: 'Temperatura máxima: ${_fmt(summary['temp_max'])} °C'),
        pw.Bullet(text: 'Precipitación total: ${_fmt(summary['precip_total'])} mm'),
        pw.Bullet(text: 'Máx precipitación: ${_fmt(summary['precip_max'])} mm'),
        pw.Bullet(text: 'Velocidad media viento: ${_fmt(summary['wind_avg'])} m/s'),
        pw.Bullet(text: 'Máx racha: ${_fmt(summary['wind_gust_max'])} m/s'),
      ]);
    }));

    return pdf.save();
  }

  /// Save generated PDF to application documents and return the path.
  Future<String> generateAndSavePdf(int stationDbId, DateTime from, DateTime to, String title) async {
    final bytes = await generateReportPdf(stationDbId, from, to, title);
    // Save to documents
    try {
      final dir = await getApplicationDocumentsDirectory();
      final fileName = '${title.replaceAll(' ', '_')}_${from.toIso8601String()}.pdf';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (e) {
      rethrow;
    }
  }

  String _fmt(dynamic v) {
    if (v == null) return 'N/A';
    if (v is num) return v.toStringAsFixed(2);
    return v.toString();
  }
}
