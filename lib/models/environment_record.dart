class EnvironmentRecord {
  const EnvironmentRecord({
    required this.id,
    required this.pigHouseId,
    required this.recordedAt,
    required this.temperature,
    required this.humidity,
    required this.light,
  });

  final String id;
  final String pigHouseId;
  final DateTime recordedAt;
  final double temperature;
  final double humidity;
  final double light;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'pig_house_id': pigHouseId,
      'recorded_at': recordedAt.millisecondsSinceEpoch,
      'temperature': temperature,
      'humidity': humidity,
      'light': light,
    };
  }

  factory EnvironmentRecord.fromMap(Map<String, Object?> map) {
    return EnvironmentRecord(
      id: map['id']! as String,
      pigHouseId: map['pig_house_id']! as String,
      recordedAt:
          DateTime.fromMillisecondsSinceEpoch(map['recorded_at']! as int),
      temperature: (map['temperature']! as num).toDouble(),
      humidity: (map['humidity']! as num).toDouble(),
      light: (map['light']! as num).toDouble(),
    );
  }
}
