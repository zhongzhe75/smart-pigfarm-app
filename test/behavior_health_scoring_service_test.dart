import 'package:flutter_test/flutter_test.dart';
import 'package:smart_pigfarm_app/models/pig_daily_stat.dart';
import 'package:smart_pigfarm_app/services/behavior_health_scoring_service.dart';

void main() {
  const service = BehaviorHealthScoringService();
  final start = DateTime.utc(2026, 1, 1);

  test('stable behavior remains normal', () {
    final history = List.generate(7, (index) {
      return _stat(
        date: start.add(Duration(days: index)),
        weight: 50 + index * 0.75,
        feed: 3.4 + index * 0.01,
        activity: 1100 + index * 3,
      );
    });
    final result = service.score(
      current: _stat(
        date: start.add(const Duration(days: 7)),
        weight: 55.3,
        feed: 3.45,
        activity: 1110,
      ),
      history: history,
    );

    expect(result.score, greaterThanOrEqualTo(85));
    expect(result.riskLevel, RiskLevel.normal);
  });

  test('combined sustained drops produce high risk', () {
    final history = List.generate(7, (index) {
      return _stat(
        date: start.add(Duration(days: index)),
        weight: 50 + index * 0.8,
        feed: 4,
        activity: 1200,
      );
    });
    final result = service.score(
      current: _stat(
        date: start.add(const Duration(days: 7)),
        weight: 54.9,
        feed: 2.1,
        activity: 560,
      ),
      history: history,
    );

    expect(result.feedDropPercent, greaterThan(30));
    expect(result.activityDropPercent, greaterThan(35));
    expect(result.score, lessThan(70));
    expect(result.riskLevel, RiskLevel.high);
  });
}

PigDailyStat _stat({
  required DateTime date,
  required double weight,
  required double feed,
  required double activity,
}) {
  return PigDailyStat(
    pigId: 'PIG-001',
    date: date,
    weightKg: weight,
    feedAmountKg: feed,
    feedingDurationMinutes: 80,
    activityDistanceMeters: activity,
    activityDurationMinutes: 95,
    restDurationMinutes: 1050,
    healthScore: 100,
    riskLevel: RiskLevel.normal,
  );
}
