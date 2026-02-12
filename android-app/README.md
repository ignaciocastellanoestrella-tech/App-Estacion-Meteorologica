# App Estación Meteorológica (Android - Flutter)

Scaffolding inicial de la app Android en Flutter para mostrar datos de la estación meteorológica.

Requisitos (en macOS):
- Instalar Flutter SDK: https://flutter.dev/docs/get-started/install
- Instalar Android Studio y crear un emulador Android

Pasos rápidos:

1. Copia tu API key al fichero `.env` en `android-app/` (no la subas al repo):

```bash
cp .env.example .env
# editar .env y colocar WUNDERGROUND_API_KEY
```

2. Abrir la carpeta `android-app` y obtener dependencias:

```bash
cd "App-Estacion-Meteorologica/android-app"
flutter pub get
```

3. Ejecutar en emulador:

```bash
flutter run
```

Notas:
- Este es un scaffolding inicial con ejemplos de servicio para Wunderground, modelo de datos, y pantalla principal.
- Asegúrate de introducir tu API key en `.env` antes de ejecutar.

Widgets Android
----------------
Este proyecto incluye soporte para widgets de Android usando el plugin `home_widget`. Para que los widgets funcionen correctamente debes añadir soporte nativo en la carpeta `android/` (los pasos siguientes son los mínimos y pueden variar según la versión de Android):

1. Añade `HomeWidget` y configura un `AppWidgetProvider` en Android. Ver la guía oficial: https://pub.dev/packages/home_widget

2. Añade en `android/app/src/main/AndroidManifest.xml` los permisos/receivers necesarios y registra el `AppWidgetProvider`.

3. Crea layout XMLs para los widgets (por ejemplo `widget_small.xml`, `widget_medium.xml`, `widget_large.xml`) en `android/app/src/main/res/layout/` y el `appwidget_provider.xml` en `res/xml/`.

4. El helper Flutter `lib/widgets/widget_helper.dart` guarda datos y pide actualización al widget nativo. Después de que la app obtenga una observación y la guarde, llama a `WidgetHelper.updateWeatherWidget(...)` para enviar los valores al widget.

Notas:
- Los emuladores a veces no muestran widgets de forma fiable; probar en un dispositivo físico es lo recomendado.
- El plugin `home_widget` puede necesitar pasos extra en `android/` (gradle config, proguard, etc). Sigue su README para la integración nativa.

Archivos nativos ya generados (ejemplo básico)
-------------------------------------------
He incluido ejemplos mínimos ya listos en `android/app/src/main/` para que el widget funcione como base:

- `res/layout/widget_small.xml`, `widget_medium.xml`, `widget_large.xml` — layouts del widget.
- `res/xml/weather_widget_info.xml` — descriptor `AppWidgetProvider`.
- `kotlin/com/example/app_estacion_meteorologica/WeatherWidgetProvider.kt` — `AppWidgetProvider` que lee valores desde SharedPreferences (donde `home_widget` escribe) y actualiza el widget.
- `AndroidManifest.xml` en el módulo `android/app` registra el receiver.

Pruebas y notas:
- Es recomendable probar el widget en un dispositivo físico porque algunos emuladores no gestionan bien widgets.
- El plugin `home_widget` gestiona la comunicación desde Flutter; estos archivos nativos son ejemplos básicos que puedes ajustar visualmente y agregar estilos (fondos transparentes, themes, iconos).
- Si necesitas que implemente WorkManager o actualizaciones nativas en background, dímelo y lo añado.

