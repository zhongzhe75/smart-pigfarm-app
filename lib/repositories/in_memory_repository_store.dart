import '../models/ai_behavior_record.dart';
import '../models/environment_record.dart';
import '../models/health_alert.dart';
import '../models/herd_daily_aggregate.dart';
import '../models/immunization_record.dart';
import '../models/pig.dart';
import '../models/pig_daily_stat.dart';
import '../models/pig_detail.dart';
import '../models/pig_summary.dart';
import '../services/pig_farm_seed_data_generator.dart';
import '../services/prototype_ai_behavior_factory.dart';
import 'ai_behavior_repository.dart';
import 'environment_repository.dart';
import 'health_alert_repository.dart';
import 'pig_metrics_repository.dart';
import 'pig_repository.dart';

class InMemoryRepositoryStore
    implements
        PigRepository,
        PigMetricsRepository,
        HealthAlertRepository,
        EnvironmentRepository,
        AiBehaviorRepository {
  InMemoryRepositoryStore(PigFarmSeedData data)
      : _pigs = List<Pig>.from(data.pigs),
        _dailyStats = List<PigDailyStat>.from(data.dailyStats),
        _alertsById = {for (final alert in data.healthAlerts) alert.id: alert},
        _immunizations = List<ImmunizationRecord>.from(data.immunizations),
        _environmentRecords =
            List<EnvironmentRecord>.from(data.environmentRecords);

  final List<Pig> _pigs;
  final List<PigDailyStat> _dailyStats;
  final Map<String, HealthAlert> _alertsById;
  final List<ImmunizationRecord> _immunizations;
  final List<EnvironmentRecord> _environmentRecords;

  @override
  Future<List<Pig>> queryPigs({
    String? numberQuery,
    String? pigHouseId,
    RiskLevel? healthStatus,
    int limit = 50,
    int offset = 0,
  }) async {
    final normalizedQuery = numberQuery?.trim().toUpperCase();
    final latestByPig = _latestStatsByPig();
    final filtered = _pigs.where((pig) {
      final matchesQuery = normalizedQuery == null ||
          normalizedQuery.isEmpty ||
          pig.id.toUpperCase().contains(normalizedQuery) ||
          pig.earTag.toUpperCase().contains(normalizedQuery);
      final matchesHouse = pigHouseId == null || pig.pigHouseId == pigHouseId;
      final matchesHealth = healthStatus == null ||
          latestByPig[pig.id]?.riskLevel == healthStatus;
      return matchesQuery && matchesHouse && matchesHealth;
    }).toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    if (offset >= filtered.length) return const [];
    final end = (offset + limit).clamp(offset, filtered.length).toInt();
    return List<Pig>.unmodifiable(filtered.sublist(offset, end));
  }

  @override
  Future<List<Pig>> searchByNumber(String query, {int limit = 50}) {
    return queryPigs(numberQuery: query, limit: limit);
  }

  @override
  Future<List<Pig>> filterByPigHouse(String pigHouseId, {int limit = 100}) {
    return queryPigs(pigHouseId: pigHouseId, limit: limit);
  }

  @override
  Future<List<Pig>> filterByHealthStatus(RiskLevel healthStatus,
      {int limit = 100}) {
    return queryPigs(healthStatus: healthStatus, limit: limit);
  }

  @override
  Future<PigDetail?> getPigDetail(String pigId) async {
    final pig = _pigs.where((item) => item.id == pigId).firstOrNull;
    if (pig == null) return null;
    final immunizations = _immunizations
        .where((item) => item.pigId == pigId)
        .toList()
      ..sort((a, b) => b.immunizedAt.compareTo(a.immunizedAt));
    return PigDetail(
      pig: pig,
      latestStat: _latestStatsByPig()[pigId],
      immunizations: List<ImmunizationRecord>.unmodifiable(immunizations),
    );
  }

  @override
  Future<List<PigSummary>> queryPigSummaries({
    String? numberQuery,
    String? pigHouseId,
    RiskLevel? healthStatus,
    PigSummarySort sort = PigSummarySort.id,
    int limit = 50,
    int offset = 0,
  }) async {
    final normalizedQuery = numberQuery?.trim().toUpperCase();
    final latestByPig = _latestStatsByPig();
    final filtered = _pigs.where((pig) {
      final matchesQuery = normalizedQuery == null ||
          normalizedQuery.isEmpty ||
          pig.id.toUpperCase().contains(normalizedQuery) ||
          pig.earTag.toUpperCase().contains(normalizedQuery);
      final matchesHouse = pigHouseId == null || pig.pigHouseId == pigHouseId;
      final matchesHealth = healthStatus == null ||
          latestByPig[pig.id]?.riskLevel == healthStatus;
      return matchesQuery && matchesHouse && matchesHealth;
    }).map((pig) {
      return PigSummary(pig: pig, latestStat: latestByPig[pig.id]);
    }).toList();
    filtered.sort((left, right) => _compareSummaries(left, right, sort));
    if (offset >= filtered.length) return const [];
    final end = (offset + limit).clamp(offset, filtered.length).toInt();
    return List<PigSummary>.unmodifiable(filtered.sublist(offset, end));
  }

  @override
  Future<List<PigDailyStat>> queryDailyStats({
    required String pigId,
    required DateTime from,
    required DateTime to,
  }) async {
    final result = _dailyStats.where((item) {
      return item.pigId == pigId &&
          !item.date.isBefore(from) &&
          !item.date.isAfter(to);
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return List<PigDailyStat>.unmodifiable(result);
  }

  @override
  Future<PigDailyStat?> getLatestStat(String pigId) async {
    return _latestStatsByPig()[pigId];
  }

  @override
  Future<HerdDailyAggregate?> getLatestHerdAggregate({
    String? pigHouseId,
  }) async {
    if (_dailyStats.isEmpty) return null;
    final latestDate = _dailyStats
        .map((item) => item.date)
        .reduce((left, right) => left.isAfter(right) ? left : right);
    final aggregates = await queryHerdDailyAggregates(
      from: latestDate,
      to: latestDate,
      pigHouseId: pigHouseId,
    );
    return aggregates.isEmpty ? null : aggregates.last;
  }

  @override
  Future<List<HerdDailyAggregate>> queryHerdDailyAggregates({
    required DateTime from,
    required DateTime to,
    String? pigHouseId,
  }) async {
    final pigsById = {for (final pig in _pigs) pig.id: pig};
    final grouped = <int, List<PigDailyStat>>{};
    for (final stat in _dailyStats) {
      final pig = pigsById[stat.pigId];
      if (pig == null ||
          (pigHouseId != null && pig.pigHouseId != pigHouseId) ||
          stat.date.isBefore(from) ||
          stat.date.isAfter(to)) {
        continue;
      }
      grouped.putIfAbsent(stat.date.millisecondsSinceEpoch, () => []).add(stat);
    }
    final aggregates = grouped.entries.map((entry) {
      final items = entry.value;
      return HerdDailyAggregate(
        date: DateTime.fromMillisecondsSinceEpoch(entry.key),
        pigCount: items.length,
        averageWeightKg: _average(items.map((item) => item.weightKg)),
        totalFeedAmountKg:
            items.fold(0, (sum, item) => sum + item.feedAmountKg),
        averageActivityDistanceMeters: _average(
          items.map((item) => item.activityDistanceMeters),
        ),
        averageHealthScore:
            _average(items.map((item) => item.healthScore.toDouble())),
        watchCount:
            items.where((item) => item.riskLevel == RiskLevel.watch).length,
        highRiskCount:
            items.where((item) => item.riskLevel == RiskLevel.high).length,
      );
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return List<HerdDailyAggregate>.unmodifiable(aggregates);
  }

  @override
  Future<List<HealthAlert>> queryAlerts({
    String? pigId,
    HealthAlertSeverity? severity,
    HealthAlertStatus? status,
    DateTime? from,
    DateTime? to,
    int limit = 100,
    int offset = 0,
  }) async {
    final filtered = _alertsById.values.where((alert) {
      return (pigId == null || alert.pigId == pigId) &&
          (severity == null || alert.severity == severity) &&
          (status == null || alert.status == status) &&
          (from == null || !alert.createdAt.isBefore(from)) &&
          (to == null || !alert.createdAt.isAfter(to));
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (offset >= filtered.length) return const [];
    final end = (offset + limit).clamp(offset, filtered.length).toInt();
    return List<HealthAlert>.unmodifiable(filtered.sublist(offset, end));
  }

  @override
  Future<void> saveAlerts(Iterable<HealthAlert> alerts) async {
    for (final alert in alerts) {
      _alertsById.putIfAbsent(alert.id, () => alert);
    }
  }

  @override
  Future<void> updateAlertStatus(
      String alertId, HealthAlertStatus status) async {
    final existing = _alertsById[alertId];
    if (existing != null) {
      _alertsById[alertId] = existing.copyWith(status: status);
    }
  }

  @override
  Future<List<EnvironmentRecord>> queryHistory({
    required String pigHouseId,
    required DateTime from,
    required DateTime to,
  }) async {
    final result = _environmentRecords.where((item) {
      return item.pigHouseId == pigHouseId &&
          !item.recordedAt.isBefore(from) &&
          !item.recordedAt.isAfter(to);
    }).toList()
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    return List<EnvironmentRecord>.unmodifiable(result);
  }

  @override
  Future<List<AiBehaviorRecord>> queryBehaviorRecords({
    String? pigId,
    DateTime? from,
    DateTime? to,
  }) async {
    return const PrototypeAiBehaviorFactory().fromHealthAlerts(
      _alertsById.values,
      pigId: pigId,
      from: from,
      to: to,
    );
  }

  Future<void> close() async {}

  Map<String, PigDailyStat> _latestStatsByPig() {
    final latest = <String, PigDailyStat>{};
    for (final stat in _dailyStats) {
      final existing = latest[stat.pigId];
      if (existing == null || stat.date.isAfter(existing.date)) {
        latest[stat.pigId] = stat;
      }
    }
    return latest;
  }

  double _average(Iterable<double> values) {
    final list = values.toList();
    return list.isEmpty ? 0 : list.reduce((a, b) => a + b) / list.length;
  }

  int _compareSummaries(
    PigSummary left,
    PigSummary right,
    PigSummarySort sort,
  ) {
    final leftStat = left.latestStat;
    final rightStat = right.latestStat;
    final comparison = switch (sort) {
      PigSummarySort.id => left.pig.id.compareTo(right.pig.id),
      PigSummarySort.healthScoreAscending =>
        (leftStat?.healthScore ?? 101).compareTo(rightStat?.healthScore ?? 101),
      PigSummarySort.weightDescending =>
        (rightStat?.weightKg ?? -1).compareTo(leftStat?.weightKg ?? -1),
      PigSummarySort.feedDescending =>
        (rightStat?.feedAmountKg ?? -1).compareTo(leftStat?.feedAmountKg ?? -1),
      PigSummarySort.activityDescending =>
        (rightStat?.activityDistanceMeters ?? -1)
            .compareTo(leftStat?.activityDistanceMeters ?? -1),
    };
    return comparison != 0 ? comparison : left.pig.id.compareTo(right.pig.id);
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
