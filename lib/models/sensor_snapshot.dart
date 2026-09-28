class SensorSnapshot {
  const SensorSnapshot({
    required this.pigHouseId,
    required this.collectedAt,
    required this.temperature,
    required this.humidity,
    required this.ammonia,
    required this.co2,
    required this.illuminance,
    required this.environmentScore,
    required this.environmentStatus,
  });

  final String pigHouseId;
  final DateTime collectedAt;
  final double temperature;
  final double humidity;
  final double ammonia;
  final double co2;
  final double illuminance;
  final int environmentScore;
  final String environmentStatus;
}
