import 'package:home_widget/home_widget.dart';
import 'dart:async';

class WidgetHelper {
  /// Update the Android home widget with provided key-values.
  /// Keys used by native widget layout: 'temp', 'condition', 'wind', 'precip'
  static Future<void> updateWeatherWidget({
    required double temperature,
    required String condition,
    required double windSpeed,
    String? windDir,
    required double precip,
    required String stationName,
    String? apiKey,
    String? stationId,
    double? humidity,
    double? pressure,
    double? precipRate,
    double? dewPoint,
    int? conditionCode,
    bool? isDay,
  }) async {
    try {
      final now = DateTime.now();
      final updatedTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      final updatedDate = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}';
      if (apiKey != null) {
        await HomeWidget.saveWidgetData<String>('apiKey', apiKey);
      }
      if (stationId != null) {
        await HomeWidget.saveWidgetData<String>('stationId', stationId);
      }
      await HomeWidget.saveWidgetData<String>('updatedAtTime', updatedTime);
      await HomeWidget.saveWidgetData<String>('updatedAtDate', updatedDate);
      await HomeWidget.saveWidgetData<String>('condition', condition);
      await HomeWidget.saveWidgetData<String>('station', stationName);
      await HomeWidget.saveWidgetData<String>('wind', windSpeed.toStringAsFixed(1));
      if (windDir != null) {
        await HomeWidget.saveWidgetData<String>('windDir', windDir);
      }
      await HomeWidget.saveWidgetData<String>('precip', precip.toStringAsFixed(1));
      await HomeWidget.saveWidgetData<String>('temp', temperature.toStringAsFixed(1));
      if (dewPoint != null) {
        await HomeWidget.saveWidgetData<String>('dewPoint', dewPoint.toStringAsFixed(1));
      }
      if (conditionCode != null) {
        await HomeWidget.saveWidgetData<String>('conditionCode', conditionCode.toString());
      }
      if (humidity != null) {
        await HomeWidget.saveWidgetData<String>('humidity', humidity.toStringAsFixed(1));
      }
      if (pressure != null) {
        await HomeWidget.saveWidgetData<String>('pressure', pressure.toStringAsFixed(2));
      }
      if (precipRate != null) {
        await HomeWidget.saveWidgetData<String>('precipRate', precipRate.toStringAsFixed(1));
      }
      if (isDay != null) {
        await HomeWidget.saveWidgetData<String>('isDay', isDay ? '1' : '0');
      }
      // Request widget update (native side should implement AppWidgetProvider to listen)
      await HomeWidget.updateWidget(name: 'WeatherWidgetProvider', iOSName: '');
    } catch (e) {
      // ignore widget errors on platforms that don't support it
    }
  }

  /// Convenience to clear widget values
  static Future<void> clearWidget() async {
    try {
      await HomeWidget.saveWidgetData<String>('condition', '');
      await HomeWidget.saveWidgetData<String>('station', '');
      await HomeWidget.saveWidgetData<String>('wind', '');
      await HomeWidget.saveWidgetData<String>('windDir', '');
      await HomeWidget.saveWidgetData<String>('apiKey', '');
      await HomeWidget.saveWidgetData<String>('stationId', '');
      await HomeWidget.saveWidgetData<String>('updatedAtTime', '');
      await HomeWidget.saveWidgetData<String>('updatedAtDate', '');
      await HomeWidget.saveWidgetData<String>('precip', '');
      await HomeWidget.saveWidgetData<String>('temp', '');
      await HomeWidget.saveWidgetData<String>('humidity', '');
      await HomeWidget.saveWidgetData<String>('dewPoint', '');
      await HomeWidget.saveWidgetData<String>('conditionCode', '');
      await HomeWidget.saveWidgetData<String>('isDay', '');
      await HomeWidget.updateWidget(name: 'WeatherWidgetProvider', iOSName: '');
    } catch (e) {}
  }
}
