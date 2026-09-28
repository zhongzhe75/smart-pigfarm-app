enum RiskLevel {
  normal,
  watch,
  high,
}

extension RiskLevelText on RiskLevel {
  String get label {
    switch (this) {
      case RiskLevel.normal:
        return '正常';
      case RiskLevel.watch:
        return '重点关注';
      case RiskLevel.high:
        return '高风险';
    }
  }
}

class PigDailyStat {
  const PigDailyStat({
    required this.pigId,
    required this.date,
    required this.weightKg,
    required this.feedAmountKg,
    required this.feedingDurationMinutes,
    required this.activityDistanceMeters,
    required this.activityDurationMinutes,
    required this.restDurationMinutes,
    required this.healthScore,
    required this.riskLevel,
  });

  final String pigId;
  final DateTime date;
  final double weightKg;
  final double feedAmountKg;
  final int feedingDurationMinutes;
  final double activityDistanceMeters;
  final int activityDurationMinutes;
  final int restDurationMinutes;
  final int healthScore;
  final RiskLevel riskLevel;

  PigDailyStat copyWith({
    int? healthScore,
    RiskLevel? riskLevel,
  }) {
    return PigDailyStat(
      pigId: pigId,
      date: date,
      weightKg: weightKg,
      feedAmountKg: feedAmountKg,
      feedingDurationMinutes: feedingDurationMinutes,
      activityDistanceMeters: activityDistanceMeters,
      activityDurationMinutes: activityDurationMinutes,
      restDurationMinutes: restDurationMinutes,
      healthScore: healthScore ?? this.healthScore,
      riskLevel: riskLevel ?? this.riskLevel,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'pig_id': pigId,
      'date': date.millisecondsSinceEpoch,
      'weight_kg': weightKg,
      'feed_amount_kg': feedAmountKg,
      'feeding_duration_minutes': feedingDurationMinutes,
      'activity_distance_meters': activityDistanceMeters,
      'activity_duration_minutes': activityDurationMinutes,
      'rest_duration_minutes': restDurationMinutes,
      'health_score': healthScore,
      'risk_level': riskLevel.name,
    };
  }

  factory PigDailyStat.fromMap(Map<String, Object?> map) {
    return PigDailyStat(
      pigId: map['pig_id']! as String,
      date: DateTime.fromMillisecondsSinceEpoch(map['date']! as int),
      weightKg: (map['weight_kg']! as num).toDouble(),
      feedAmountKg: (map['feed_amount_kg']! as num).toDouble(),
      feedingDurationMinutes: map['feeding_duration_minutes']! as int,
      activityDistanceMeters:
          (map['activity_distance_meters']! as num).toDouble(),
      activityDurationMinutes: map['activity_duration_minutes']! as int,
      restDurationMinutes: map['rest_duration_minutes']! as int,
      healthScore: map['health_score']! as int,
      riskLevel: RiskLevel.values.byName(map['risk_level']! as String),
    );
  }
}
