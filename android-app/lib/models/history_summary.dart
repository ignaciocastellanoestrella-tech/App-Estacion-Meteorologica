class HistorySummary {
  final double tempAvg;
  final double tempMin;
  final double tempMax;
  final double humidityAvg;
  final double precipTotal;
  final double precipRateMax;
  final double windAvg;
  final double windGustMax;
  final double pressureAvg;
  final double heatIndexAvg;

  HistorySummary({
    required this.tempAvg,
    required this.tempMin,
    required this.tempMax,
    required this.humidityAvg,
    required this.precipTotal,
    required this.precipRateMax,
    required this.windAvg,
    required this.windGustMax,
    required this.pressureAvg,
    required this.heatIndexAvg,
  });
}
