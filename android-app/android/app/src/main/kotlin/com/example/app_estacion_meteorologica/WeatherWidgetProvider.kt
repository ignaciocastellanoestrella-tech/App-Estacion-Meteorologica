package com.example.app_estacion_meteorologica

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.math.abs
import kotlin.math.roundToInt
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.workDataOf

open class WeatherWidgetProvider : AppWidgetProvider() {
    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_REFRESH) {
            val appWidgetId = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
            val inputData = workDataOf("forceFetch" to true, "appWidgetId" to appWidgetId)
            val request = OneTimeWorkRequestBuilder<WidgetUpdateWorker>()
                .setInputData(inputData)
                .build()
            WorkManager.getInstance(context).enqueue(request)
        }
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        super.onUpdate(context, appWidgetManager, appWidgetIds)
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        private const val ACTION_REFRESH = "com.example.app_estacion_meteorologica.ACTION_REFRESH_WIDGET"

        fun updateAllWidgets(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
            for (appWidgetId in appWidgetIds) {
                updateAppWidget(context, appWidgetManager, appWidgetId)
            }
        }
        
        fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            val widgetPrefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            
            // Current date and time
            val currentTime = SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date())
            val currentDate = SimpleDateFormat("EEEE, dd MMM", Locale("es", "ES")).format(Date())
            
            // Read values with fallbacks
            fun getPref(key: String): String? {
                return widgetPrefs.getString(key, null)
                    ?: flutterPrefs.getString("flutter.$key", null)
                    ?: flutterPrefs.getString(key, null)
            }

            val temp = getPref("temp") ?: "--"
            val cond = getPref("condition") ?: "clear"
            val station = getPref("station") ?: "Estación"
            val precip = getPref("precip") ?: "0.0"
            val hum = getPref("humidity") ?: "--"
            val windStr = getPref("wind") ?: "0"
            val windDir = getPref("windDir")
            val pressure = getPref("pressure") ?: "--"
            val precipRate = getPref("precipRate") ?: "0.0"
            val dewPoint = getPref("dewPoint") ?: "0.0"
            val isDayPref = getPref("isDay")
            val updatedAtTime = getPref("updatedAtTime") ?: currentTime
            val updatedAtDate = getPref("updatedAtDate") ?: currentDate
            
            val windSpeed = windStr.toFloatOrNull() ?: 0f
            val tempValue = temp.toFloatOrNull() ?: 0f
            val dewValue = dewPoint.toFloatOrNull() ?: 0f
            val precipRateValue = precipRate.toFloatOrNull() ?: 0f
            val humidityValue = hum.toFloatOrNull() ?: 0f
            val isDay = parseIsDay(isDayPref) ?: isDaytimeNow()
            
            // Use the layout defined by each widget provider (size/variant specific)
            val info = appWidgetManager.getAppWidgetInfo(appWidgetId)
            val layoutId = info?.initialLayout ?: R.layout.widget_small
            
            val views = RemoteViews(context.packageName, layoutId)

            val refreshIntent = Intent(context, WeatherWidgetProvider::class.java).apply {
                action = ACTION_REFRESH
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            }
            val refreshPendingIntent = PendingIntent.getBroadcast(
                context,
                appWidgetId,
                refreshIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            safeSetOnClickPendingIntent(views, R.id.w_refresh, refreshPendingIntent)
            
            // Set weather icon based on condition
            val iconRes = getWeatherIcon(
                condition = cond.lowercase(),
                temp = tempValue,
                dewPoint = dewValue,
                precipRate = precipRateValue,
                windSpeed = windSpeed,
                humidity = humidityValue,
                isDay = isDay
            )
            safeSetImageResource(views, R.id.w_icon, iconRes)
            
            // Set date and time
            val updatedLabel = when (layoutId) {
                R.layout.widget_large, R.layout.widget_large_transparent -> "Act. $updatedAtDate $updatedAtTime"
                R.layout.widget_medium, R.layout.widget_medium_transparent -> "Act. $updatedAtDate $updatedAtTime"
                else -> "Act. $updatedAtTime"
            }
            safeSetText(views, R.id.w_updated, updatedLabel)
            
            // Set temperature (format without decimal if whole number)
            val tempParsed = temp.toFloatOrNull()
            val tempDisplay = if (tempParsed != null) {
                "${String.format(Locale.getDefault(), "%.1f", tempParsed)}°"
            } else {
                "$temp°"
            }
            views.setTextViewText(R.id.w_temp, tempDisplay)
            views.setTextViewText(R.id.w_station, station)
            
            // Set weather data with proper formatting
            safeSetText(views, R.id.w_hum, "$hum%")
            safeSetText(views, R.id.w_precip, "$precip mm")
            val windDirLabel = formatWindDirection(windDir)
            val windDisplay = if (windDirLabel.isNotEmpty()) {
                "$windStr km/h $windDirLabel"
            } else {
                "$windStr km/h"
            }
            safeSetText(views, R.id.w_wind, windDisplay)
            safeSetText(views, R.id.w_pressure, "$pressure hPa")
            safeSetText(views, R.id.w_precip_rate, "$precipRate mm/hr")
            
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
        
        private fun getWeatherIcon(
            condition: String,
            temp: Float,
            dewPoint: Float,
            precipRate: Float,
            windSpeed: Float,
            humidity: Float,
            isDay: Boolean
        ): Int {
            fun has(s: String): Boolean = condition.contains(s)

            if (has("thunder") || has("storm") || has("tormenta")) return R.drawable.ic_thunder
            if (has("hail") || has("granizo") || has("ice pellets")) return R.drawable.ic_hail
            if (has("freezing rain") || has("lluvia helada")) return R.drawable.ic_freezing_rain
            if (has("sleet") || has("aguanieve") || has("ice rain")) return R.drawable.ic_sleet
            if (has("blizzard")) return R.drawable.ic_blizzard
            if (has("blowing snow")) return R.drawable.ic_blowing_snow
            if (has("snow") || has("nieve") || has("flurr")) return R.drawable.ic_snow
            if (has("fog") || has("mist") || has("niebla") || has("bruma")) return R.drawable.ic_fog
            if (has("haze") || has("hazy")) return R.drawable.ic_haze
            if (has("very hot") || has("muy caluroso") || has("muy calor")) return R.drawable.ic_hot
            if (has("very cold") || has("muy frio") || has("muy frío")) return R.drawable.ic_cold
            if (has("drizzle") || has("llovizna")) return R.drawable.ic_rain_light
            if (has("rain") || has("shower") || has("lluv") || has("chubasco")) {
                return when {
                    precipRate >= 2.5f -> R.drawable.ic_rain_heavy
                    precipRate >= 0.2f -> R.drawable.ic_rain_light
                    else -> R.drawable.ic_rain
                }
            }
            if (has("partly") || has("parcial") || has("few clouds") || has("scattered") || has("nubes y sol")) {
                return if (isDay) R.drawable.ic_partly_cloudy else R.drawable.ic_partly_cloudy_night
            }
            if (has("cloud") || has("nub") || has("overcast") || has("cubierto")) return R.drawable.ic_cloudy
            if (has("clear") || has("despej") || has("sunny") || has("sol") || has("fair")) {
                return if (isDay) R.drawable.ic_sunny else R.drawable.ic_moon
            }

            if (precipRate >= 2.5f) return R.drawable.ic_rain_heavy
            if (precipRate >= 0.2f) {
                if (temp <= 1.0f) return R.drawable.ic_snow
                if (temp <= 2.0f && dewPoint <= 0.5f) return R.drawable.ic_sleet
                return R.drawable.ic_rain_light
            }
            if (humidity >= 95f && abs(temp - dewPoint) <= 1.5f) return R.drawable.ic_fog
            if (windSpeed >= 35f) return R.drawable.ic_windy

            return if (humidity <= 55f) {
                if (isDay) R.drawable.ic_sunny else R.drawable.ic_moon
            } else {
                R.drawable.ic_cloudy
            }
        }

        private fun parseIsDay(value: String?): Boolean? {
            if (value == null || value.isEmpty()) return null
            return when (value.lowercase()) {
                "1", "true", "yes" -> true
                "0", "false", "no" -> false
                else -> null
            }
        }

        private fun formatWindDirection(value: String?): String {
            if (value == null) return ""
            val trimmed = value.trim()
            if (trimmed.isEmpty()) return ""
            val deg = trimmed.replace(',', '.').toFloatOrNull() ?: return trimmed
            val labels = arrayOf("N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW")
            val normalized = ((deg % 360f) + 360f) % 360f
            val idx = ((normalized) / 22.5f).roundToInt() % labels.size
            return labels[idx]
        }

        private fun isDaytimeNow(): Boolean {
            val now = java.util.Calendar.getInstance()
            val hour = now.get(java.util.Calendar.HOUR_OF_DAY)
            val month = now.get(java.util.Calendar.MONTH) + 1
            return if (month in 4..9) {
                hour in 7..20
            } else {
                hour in 8..18
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

        private fun safeSetOnClickPendingIntent(views: RemoteViews, viewId: Int, pendingIntent: PendingIntent) {
            try {
                views.setOnClickPendingIntent(viewId, pendingIntent)
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
