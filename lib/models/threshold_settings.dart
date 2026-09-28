class ThresholdSettings {
  const ThresholdSettings({
    required this.temperatureHigh,
    required this.temperatureLow,
    required this.humidityHigh,
    required this.humidityLow,
    required this.ammoniaHigh,
    required this.co2High,
    required this.illuminanceLow,
  });

  factory ThresholdSettings.defaults() {
    return const ThresholdSettings(
      temperatureHigh: 30,
      temperatureLow: 18,
      humidityHigh: 82,
      humidityLow: 45,
      ammoniaHigh: 25,
      co2High: 1800,
      illuminanceLow: 120,
    );
  }

  final double temperatureHigh;
  final double temperatureLow;
  final double humidityHigh;
  final double humidityLow;
  final double ammoniaHigh;
  final double co2High;
  final double illuminanceLow;

  ThresholdSettings copyWith({
    double? temperatureHigh,
    double? temperatureLow,
    double? humidityHigh,
    double? humidityLow,
    double? ammoniaHigh,
    double? co2High,
    double? illuminanceLow,
  }) {
    return ThresholdSettings(
      temperatureHigh: temperatureHigh ?? this.temperatureHigh,
      temperatureLow: temperatureLow ?? this.temperatureLow,
      humidityHigh: humidityHigh ?? this.humidityHigh,
      humidityLow: humidityLow ?? this.humidityLow,
      ammoniaHigh: ammoniaHigh ?? this.ammoniaHigh,
      co2High: co2High ?? this.co2High,
      illuminanceLow: illuminanceLow ?? this.illuminanceLow,
    );
  }
}
