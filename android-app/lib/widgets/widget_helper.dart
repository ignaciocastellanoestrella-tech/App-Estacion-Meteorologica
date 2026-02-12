import 'package:home_widget/home_widget.dart';
import 'dart:async';

class WidgetHelper {
  /// Update the Android home widget with provided key-values.
  /// Keys used by native widget layout: 'temp', 'condition', 'wind', 'precip'
  static Future<void> updateWeatherWidget({
    required double temperature,
    required String condition,
    required double windSpeed,
    required double precip,
    required String stationName,
  }) async {
    try {
      await HomeWidget.saveWidgetData<String>('condition', condition);
      await HomeWidget.saveWidgetData<String>('station', stationName);
      await HomeWidget.saveWidgetData<String>('wind', windSpeed.toStringAsFixed(1));
      await HomeWidget.saveWidgetData<String>('precip', precip.toStringAsFixed(1));
      await HomeWidget.saveWidgetData<String>('temp', temperature.toStringAsFixed(1));
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
      await HomeWidget.saveWidgetData<String>('precip', '');
      await HomeWidget.saveWidgetData<String>('temp', '');
      await HomeWidget.updateWidget(name: 'WeatherWidgetProvider', iOSName: '');
    } catch (e) {}
  }
}
