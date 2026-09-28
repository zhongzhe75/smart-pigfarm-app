import 'package:flutter_test/flutter_test.dart';
import 'package:smart_pigfarm_app/models/health_alert.dart';
import 'package:smart_pigfarm_app/repositories/in_memory_repository_store.dart';
import 'package:smart_pigfarm_app/services/pig_farm_seed_data_generator.dart';

void main() {
  final endDate = DateTime.utc(2026, 9, 17);
  late InMemoryRepositoryStore repository;

  setUp(() {
    final data = PigFarmSeedDataGenerator().generate(endDate: endDate);
    repository = InMemoryRepositoryStore(data);
  });

  test('supports pig list, search, house filter and detail queries', () async {
    final all = await repository.queryPigs(limit: 200);
    final search = await repository.searchByNumber('PIG-037');
    final house = await repository.filterByPigHouse('A01');
    final detail = await repository.getPigDetail('PIG-037');

    expect(all, hasLength(180));
    expect(search.single.id, 'PIG-037');
    expect(house, hasLength(60));
    expect(detail?.pig.id, 'PIG-037');
    expect(detail?.latestStat, isNotNull);
    expect(detail?.immunizations, isNotEmpty);
  });

  test('returns exactly 90 daily records for one pig', () async {
    final stats = await repository.queryDailyStats(
      pigId: 'PIG-037',
      from: endDate.subtract(const Duration(days: 89)),
      to: endDate,
    );
    expect(stats, hasLength(90));
  });

  test('duplicate health alerts are ignored', () async {
    final alerts = await repository.queryAlerts(limit: 5000);
    expect(alerts, isNotEmpty);
    final originalCount = alerts.length;
    final alert = alerts.first;

    await repository.saveAlerts([alert, alert]);
    final after = await repository.queryAlerts(limit: 5000);
    expect(after, hasLength(originalCount));

    await repository.updateAlertStatus(
        alert.id, HealthAlertStatus.acknowledged);
    final updated = await repository.queryAlerts(
      status: HealthAlertStatus.acknowledged,
      limit: 5000,
    );
    expect(updated.any((item) => item.id == alert.id), isTrue);
  });

  test('supports herd aggregation and environment queries', () async {
    final aggregates = await repository.queryHerdDailyAggregates(
      from: endDate.subtract(const Duration(days: 89)),
      to: endDate,
      pigHouseId: 'A01',
    );
    final environment = await repository.queryHistory(
      pigHouseId: 'A01',
      from: endDate.subtract(const Duration(days: 89)),
      to: endDate.add(const Duration(hours: 23)),
    );

    expect(aggregates, hasLength(90));
    expect(aggregates.last.pigCount, 60);
    expect(environment, hasLength(360));
  });

  test('prototype AI behavior is deterministic and linked to health alerts',
      () async {
    final records = await repository.queryBehaviorRecords();
    final alerts = await repository.queryAlerts(limit: 5000);

    expect(records, isNotEmpty);
    expect(records.every((item) => item.source == 'camera_prototype'), isTrue);
    expect(
      records.every(
        (record) => alerts.any(
          (alert) =>
              record.id == 'CAM-PROTOTYPE-${alert.id}' &&
              record.pigId == alert.pigId &&
              record.occurredAt == alert.createdAt,
        ),
      ),
      isTrue,
    );
  });
}
