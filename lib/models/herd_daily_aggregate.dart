class HerdDailyAggregate {
  const HerdDailyAggregate({
    required this.date,
    required this.pigCount,
    required this.averageWeightKg,
    required this.totalFeedAmountKg,
    required this.averageActivityDistanceMeters,
    required this.averageHealthScore,
    required this.watchCount,
    required this.highRiskCount,
  });

  final DateTime date;
  final int pigCount;
  final double averageWeightKg;
  final double totalFeedAmountKg;
  final double averageActivityDistanceMeters;
  final double averageHealthScore;
  final int watchCount;
  final int highRiskCount;
}
