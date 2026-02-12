package com.example.app_estacion_meteorologica

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews

open class WeatherWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        super.onUpdate(context, appWidgetManager, appWidgetIds)
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        fun updateAllWidgets(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
            for (appWidgetId in appWidgetIds) {
                updateAppWidget(context, appWidgetManager, appWidgetId)
            }
        }
        
        fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            
            // Read values with fallbacks
            val temp = prefs.getString("flutter.temp", null) ?: prefs.getString("temp", null) ?: "--"
            val cond = prefs.getString("flutter.condition", null) ?: prefs.getString("condition", null) ?: "--"
            val station = prefs.getString("flutter.station", null) ?: prefs.getString("station", null) ?: "Estación"
            val precip = prefs.getString("flutter.precip", null) ?: prefs.getString("precip", null) ?: "0.0"
            val hum = prefs.getString("flutter.humidity", null) ?: prefs.getString("humidity", null) ?: "--"
            val windStr = prefs.getString("flutter.wind", null) ?: prefs.getString("wind", null) ?: "0"
            val pressure = prefs.getString("flutter.pressure", null) ?: prefs.getString("pressure", null) ?: "--"
            val precipRate = prefs.getString("flutter.precipRate", null) ?: prefs.getString("precipRate", null) ?: "0.0"
            
            val windSpeed = windStr.toFloatOrNull() ?: 0f
            
            // Determine widget size and layout
            val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
            val minWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
            
            val layoutId = when {
                minWidth >= 250 -> R.layout.widget_large
                minWidth >= 150 -> R.layout.widget_medium
                else -> R.layout.widget_small
            }
            
            val views = RemoteViews(context.packageName, layoutId)
            
            // Set weather icon based on condition
            val iconRes = getWeatherIcon(cond.lowercase(), windSpeed)
            safeSetImageResource(views, R.id.w_icon, iconRes)
            
            // Set text values
            views.setTextViewText(R.id.w_temp, "$temp°")
            views.setTextViewText(R.id.w_station, station)
            
            // Optional fields depending on layout
            safeSetText(views, R.id.w_hum, "$hum%")
            safeSetText(views, R.id.w_precip, "${precip}mm")
            safeSetText(views, R.id.w_wind, "$windStr km/h")
            safeSetText(views, R.id.w_pressure, "$pressure hPa")
            safeSetText(views, R.id.w_precip_rate, "$precipRate mm/hr")
            
            // Show wind indicator for extreme winds (>30 km/h)
            if (windSpeed > 30) {
                safeSetViewVisibility(views, R.id.w_wind_indicator, android.view.View.VISIBLE)
            } else {
                safeSetViewVisibility(views, R.id.w_wind_indicator, android.view.View.GONE)
            }
            
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
        
        private fun getWeatherIcon(condition: String, windSpeed: Float): Int {
            return when {
                condition.contains("thunder") || condition.contains("storm") -> 
                    android.R.drawable.ic_dialog_alert
                condition.contains("rain") || condition.contains("shower") || condition.contains("drizzle") -> 
                    android.R.drawable.ic_menu_gallery
                condition.contains("snow") -> 
                    android.R.drawable.star_big_on
                condition.contains("cloud") || condition.contains("overcast") -> 
                    android.R.drawable.ic_menu_today
                condition.contains("clear") || condition.contains("sunny") || condition.contains("fair") -> 
                    android.R.drawable.ic_menu_day
                windSpeed > 50 -> // Extreme wind
                    android.R.drawable.ic_media_ff
                else -> 
                    android.R.drawable.ic_menu_day
            }
        }
        
        private fun safeSetText(views: RemoteViews, viewId: Int, text: String) {
            try {
                views.setTextViewText(viewId, text)
            } catch (e: Exception) {
                // View doesn't exist in this layout
            }
        }
        
        private fun safeSetImageResource(views: RemoteViews, viewId: Int, resId: Int) {
            try {
                views.setImageViewResource(viewId, resId)
            } catch (e: Exception) {
                // View doesn't exist in this layout
            }
        }
        
        private fun safeSetViewVisibility(views: RemoteViews, viewId: Int, visibility: Int) {
            try {
                views.setViewVisibility(viewId, visibility)
            } catch (e: Exception) {
                // View doesn't exist in this layout
            }
        }
    }
}
