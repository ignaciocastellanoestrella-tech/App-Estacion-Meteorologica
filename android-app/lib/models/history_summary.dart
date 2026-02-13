class HistorySummary {
  final double tempAvg;
  final double tempMin;
  final double tempMax;
  final double humidityAvg;
  final double humidityMin;
  final double humidityMax;
  final double precipTotal;
  final double precipRateMax;
  final double windAvg;
  final double windMin;
  final double windMax;
  final double windGustMax;
  final double windGustAvg;
  final double windDirAvg;
  final double pressureAvg;
  final double pressureMin;
  final double pressureMax;
  final double heatIndexAvg;

  HistorySummary({
    required this.tempAvg,
    required this.tempMin,
    required this.tempMax,
    required this.humidityAvg,
    required this.humidityMin,
    required this.humidityMax,
    required this.precipTotal,
    required this.precipRateMax,
    required this.windAvg,
    required this.windMin,
    required this.windMax,
    required this.windGustMax,
    required this.windGustAvg,
    required this.windDirAvg,
    required this.pressureAvg,
    required this.pressureMin,
    required this.pressureMax,
    required this.heatIndexAvg,
  });
}
