package com.example.app_estacion_meteorologica

import android.content.Context
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import androidx.work.Worker
import androidx.work.WorkerParameters
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.Locale

class WidgetUpdateWorker(
    context: Context,
    workerParams: WorkerParameters
) : Worker(context, workerParams) {

    override fun doWork(): Result {
        try {
            val forceFetch = inputData.getBoolean("forceFetch", false)
            if (forceFetch || shouldFetchOnSchedule()) {
                fetchAndStoreCurrentWeather()
            }
            val appWidgetManager = AppWidgetManager.getInstance(applicationContext)
            val singleWidgetId = inputData.getInt("appWidgetId", AppWidgetManager.INVALID_APPWIDGET_ID)
            
            if (singleWidgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
                WeatherWidgetProvider.updateAllWidgets(applicationContext, appWidgetManager, intArrayOf(singleWidgetId))
            } else {
                // Actualizar widget pequeño
                val smallWidgetIds = appWidgetManager.getAppWidgetIds(
                    ComponentName(applicationContext, WeatherWidgetProvider::class.java)
                )
                if (smallWidgetIds.isNotEmpty()) {
                    WeatherWidgetProvider.updateAllWidgets(applicationContext, appWidgetManager, smallWidgetIds)
                }

                // Actualizar widget mediano
                val mediumWidgetIds = appWidgetManager.getAppWidgetIds(
                    ComponentName(applicationContext, WeatherWidgetProviderMedium::class.java)
                )
                if (mediumWidgetIds.isNotEmpty()) {
                    WeatherWidgetProvider.updateAllWidgets(applicationContext, appWidgetManager, mediumWidgetIds)
                }

                // Actualizar widget grande
                val largeWidgetIds = appWidgetManager.getAppWidgetIds(
                    ComponentName(applicationContext, WeatherWidgetProviderLarge::class.java)
                )
                if (largeWidgetIds.isNotEmpty()) {
                    WeatherWidgetProvider.updateAllWidgets(applicationContext, appWidgetManager, largeWidgetIds)
                }

                // Actualizar widgets transparentes
                val smallTransparentIds = appWidgetManager.getAppWidgetIds(
                    ComponentName(applicationContext, WeatherWidgetProviderTransparentSmall::class.java)
                )
                if (smallTransparentIds.isNotEmpty()) {
                    WeatherWidgetProvider.updateAllWidgets(applicationContext, appWidgetManager, smallTransparentIds)
                }

                val mediumTransparentIds = appWidgetManager.getAppWidgetIds(
                    ComponentName(applicationContext, WeatherWidgetProviderTransparentMedium::class.java)
                )
                if (mediumTransparentIds.isNotEmpty()) {
                    WeatherWidgetProvider.updateAllWidgets(applicationContext, appWidgetManager, mediumTransparentIds)
                }

                val largeTransparentIds = appWidgetManager.getAppWidgetIds(
                    ComponentName(applicationContext, WeatherWidgetProviderTransparentLarge::class.java)
                )
                if (largeTransparentIds.isNotEmpty()) {
                    WeatherWidgetProvider.updateAllWidgets(applicationContext, appWidgetManager, largeTransparentIds)
                }
            }
            
            return Result.success()
        } catch (e: Exception) {
            e.printStackTrace()
            return Result.retry()
        }
    }

    private fun shouldFetchOnSchedule(): Boolean {
        return true
    }

    private fun fetchAndStoreCurrentWeather() {
        val widgetPrefs = applicationContext.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val flutterPrefs = applicationContext.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

        fun getPref(key: String): String? {
            return widgetPrefs.getString(key, null)
                ?: flutterPrefs.getString("flutter.$key", null)
                ?: flutterPrefs.getString(key, null)
        }

        val apiKey = getPref("apiKey") ?: return
        val stationId = getPref("stationId") ?: return

        val url = "https://api.weather.com/v2/pws/observations/current" +
            "?apiKey=$apiKey&stationId=$stationId&format=json&units=m&numericPrecision=decimal"

        val connection = (URL(url).openConnection() as HttpURLConnection).apply {
            connectTimeout = 8000
            readTimeout = 8000
            requestMethod = "GET"
        }

        connection.inputStream.use { stream ->
            val body = stream.bufferedReader().readText()
            val json = JSONObject(body)
            val obs = json.optJSONArray("observations")?.optJSONObject(0) ?: return
            val metric = obs.optJSONObject("metric") ?: JSONObject()

            val condition = obs.optString("wxPhraseLong", obs.optString("wxPhraseShort", ""))
            val conditionCode = obs.optInt("iconCode", -1)
            val humidity = obs.optDouble("humidity", Double.NaN)
            val windDir = obs.optDouble("winddir", obs.optDouble("windDir", Double.NaN))
            val temp = metric.optDouble("temp", Double.NaN)
            val windSpeed = metric.optDouble("windSpeed", Double.NaN)
            val pressure = metric.optDouble("pressure", Double.NaN)
            var precipTotal = metric.optDouble("precipTotal", Double.NaN)
            var precipRate = metric.optDouble("precipRate", Double.NaN)
            val dewPoint = metric.optDouble("dewpt", Double.NaN)

            // Adjust precipitation using today's hourly data
            try {
                val hourlyPrecip = fetchTodayHourlyPrecip(apiKey, stationId)
                val hourlyPrecipTotal = hourlyPrecip.optDouble("precipTotal", 0.0)
                val hourlyPrecipRate = hourlyPrecip.optDouble("precipRate", 0.0)
                
                // Use hourly value if greater than current
                if (hourlyPrecipTotal > (precipTotal.takeIf { !it.isNaN() } ?: 0.0)) {
                    precipTotal = hourlyPrecipTotal
                }
                if (hourlyPrecipRate > (precipRate.takeIf { !it.isNaN() } ?: 0.0)) {
                    precipRate = hourlyPrecipRate
                }
            } catch (e: Exception) {
                // Keep current values if hourly fetch fails
                e.printStackTrace()
            }

            val now = java.util.Calendar.getInstance()
            val updatedTime = String.format(Locale.US, "%02d:%02d", now.get(java.util.Calendar.HOUR_OF_DAY), now.get(java.util.Calendar.MINUTE))
            val updatedDate = String.format(Locale.US, "%02d/%02d", now.get(java.util.Calendar.DAY_OF_MONTH), now.get(java.util.Calendar.MONTH) + 1)

            val editor = widgetPrefs.edit()
            editor.putString("updatedAtTime", updatedTime)
            editor.putString("updatedAtDate", updatedDate)
            if (condition.isNotEmpty()) editor.putString("condition", condition)
            if (conditionCode >= 0) editor.putString("conditionCode", conditionCode.toString())
            if (!temp.isNaN()) editor.putString("temp", formatOneDecimal(temp))
            if (!windSpeed.isNaN()) editor.putString("wind", formatOneDecimal(windSpeed))
            if (!pressure.isNaN()) editor.putString("pressure", formatTwoDecimals(pressure))
            if (!precipTotal.isNaN()) editor.putString("precip", formatOneDecimal(precipTotal))
            if (!precipRate.isNaN()) editor.putString("precipRate", formatOneDecimal(precipRate))
            if (!dewPoint.isNaN()) editor.putString("dewPoint", formatOneDecimal(dewPoint))
            if (!humidity.isNaN()) editor.putString("humidity", formatOneDecimal(humidity))
            if (!windDir.isNaN()) editor.putString("windDir", formatOneDecimal(windDir))
            editor.apply()
        }
    }

    private fun fetchTodayHourlyPrecip(apiKey: String, stationId: String): JSONObject {
        val now = java.util.Calendar.getInstance()
        val year = now.get(java.util.Calendar.YEAR)
        val month = now.get(java.util.Calendar.MONTH) + 1
        val day = now.get(java.util.Calendar.DAY_OF_MONTH)
        val dateStr = String.format(Locale.US, "%04d%02d%02d", year, month, day)

        val url = "https://api.weather.com/v2/pws/history/hourly" +
            "?apiKey=$apiKey&stationId=$stationId&format=json&units=m&date=$dateStr&numericPrecision=decimal"

        val connection = (URL(url).openConnection() as HttpURLConnection).apply {
            connectTimeout = 8000
            readTimeout = 8000
            requestMethod = "GET"
        }

        return connection.inputStream.use { stream ->
            val body = stream.bufferedReader().readText()
            val json = JSONObject(body)
            val observations = json.optJSONArray("observations") ?: return@use JSONObject()

            var maxPrecip = 0.0
            var maxPrecipRate = 0.0

            for (i in 0 until observations.length()) {
                val obs = observations.optJSONObject(i) ?: continue
                val metric = obs.optJSONObject("metric") ?: continue
                val precip = metric.optDouble("precipTotal", 0.0)
                val precipRate = metric.optDouble("precipRate", 0.0)
                
                if (precip > maxPrecip) maxPrecip = precip
                if (precipRate > maxPrecipRate) maxPrecipRate = precipRate
            }

            JSONObject().apply {
                put("precipTotal", maxPrecip)
                put("precipRate", maxPrecipRate)
            }
        }
    }

    private fun formatOneDecimal(value: Double): String {
        return String.format(Locale.US, "%.1f", value)
    }

    private fun formatTwoDecimals(value: Double): String {
        return String.format(Locale.US, "%.2f", value)
    }
}
