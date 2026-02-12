package com.example.app_estacion_meteorologica

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.view.FlutterMain

class WeatherWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        super.onUpdate(context, appWidgetManager, appWidgetIds)
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            val views = RemoteViews(context.packageName, R.layout.widget_small)

            // Read saved values from HomeWidget (SharedPreferences under app group) - the Flutter plugin writes keys.
            // For simplicity read from default SharedPreferences where the plugin stores them.
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            // The plugin uses keys prefixed; attempt safe reads
            val temp = prefs.getString("flutter.temp", null) ?: prefs.getString("temp", "--")
            val cond = prefs.getString("flutter.condition", null) ?: prefs.getString("condition", "--")
            val station = prefs.getString("flutter.station", null) ?: prefs.getString("station", "Estación")
            val precip = prefs.getString("flutter.precip", null) ?: prefs.getString("precip", "0")

            views.setTextViewText(R.id.w_temp, "$temp°C")
            views.setTextViewText(R.id.w_cond, cond)
            // For medium/large layouts update other views if present
            try {
                views.setTextViewText(R.id.w_station, station)
                views.setTextViewText(R.id.w_precip, "Precip: ${precip}mm")
            } catch (e: Exception) {
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
