package com.example.app_estacion_meteorologica

import android.content.Context
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import androidx.work.Worker
import androidx.work.WorkerParameters

class WidgetUpdateWorker(
    context: Context,
    workerParams: WorkerParameters
) : Worker(context, workerParams) {

    override fun doWork(): Result {
        try {
            val appWidgetManager = AppWidgetManager.getInstance(applicationContext)
            
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
            
            return Result.success()
        } catch (e: Exception) {
            e.printStackTrace()
            return Result.retry()
        }
    }
}
