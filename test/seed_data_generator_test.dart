import 'package:flutter_test/flutter_test.dart';
import 'package:smart_pigfarm_app/models/pig_daily_stat.dart';
import 'package:smart_pigfarm_app/services/pig_farm_seed_data_generator.dart';

void main() {
  final endDate = DateTime.utc(2026, 9, 17);
  final generator = PigFarmSeedDataGenerator();
  late PigFarmSeedData data;

  setUpAll(() {
    data = generator.generate(endDate: endDate);
  });

  test('creates 180 pigs and 90 daily stats per pig', () {
    expect(data.pigs, hasLength(180));
    expect(data.dailyStats, hasLength(16200));
    expect(data.dailyStats.where((item) => item.pigId == 'PIG-037'),
        hasLength(90));
    expect(data.pigs.map((pig) => pig.id).toSet(), hasLength(180));
    expect(data.pigs.first.id, 'PIG-001');
    expect(data.pigs.last.id, 'PIG-180');
  });

  test('time series is deterministic and weight grows over the window', () {
    final second = generator.generate(endDate: endDate);
    final firstSeries =
        data.dailyStats.where((item) => item.pigId == 'PIG-037').toList();
    final secondSeries =
        second.dailyStats.where((item) => item.pigId == 'PIG-037').toList();

    expect(secondSeries.first.feedAmountKg, firstSeries.first.feedAmountKg);
    expect(secondSeries.last.activityDistanceMeters,
        firstSeries.last.activityDistanceMeters);
    expect(firstSeries.last.weightKg, greaterThan(firstSeries.first.weightKg));
  });

  test('recent anomalies affect between five and ten percent of pigs', () {
    final recentStart = endDate.subtract(const Duration(days: 6));
    final affected = data.dailyStats
        .where((item) =>
            !item.date.isBefore(recentStart) &&
            item.riskLevel != RiskLevel.normal)
        .map((item) => item.pigId)
        .toSet();

    expect(affected.length, inInclusiveRange(9, 18));
  });

  test('creates sparse immunization and 90-day environment history', () {
    expect(data.immunizations, hasLength(270));
    expect(data.environmentRecords, hasLength(1080));
    expect(
      data.environmentRecords.where((item) => item.pigHouseId == 'A01'),
      hasLength(360),
    );
    final temperatures =
        data.environmentRecords.map((item) => item.temperature).toList();
    expect(temperatures, everyElement(inInclusiveRange(24.6, 25.8)));
    expect(temperatures.toSet().length, greaterThan(20));
  });
}
