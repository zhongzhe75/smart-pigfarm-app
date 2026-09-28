import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import '../models/ai_behavior_record.dart';
import '../models/environment_record.dart';
import '../models/health_alert.dart';
import '../models/herd_daily_aggregate.dart';
import '../models/immunization_record.dart';
import '../models/pig.dart';
import '../models/pig_daily_stat.dart';
import '../models/pig_detail.dart';
import '../models/pig_summary.dart';
import '../services/prototype_ai_behavior_factory.dart';
import 'ai_behavior_repository.dart';
import 'environment_repository.dart';
import 'health_alert_repository.dart';
import 'pig_metrics_repository.dart';
import 'pig_repository.dart';

class SqliteRepositoryStore
    implements
        PigRepository,
        PigMetricsRepository,
        HealthAlertRepository,
        EnvironmentRepository,
        AiBehaviorRepository {
  const SqliteRepositoryStore(this.appDatabase);

  final AppDatabase appDatabase;

  Database get _database => appDatabase.database;

  @override
  Future<List<Pig>> queryPigs({
    String? numberQuery,
    String? pigHouseId,
    RiskLevel? healthStatus,
    int limit = 50,
    int offset = 0,
  }) async {
    final conditions = <String>[];
    final arguments = <Object?>[];
    final query = numberQuery?.trim();
    if (query != null && query.isNotEmpty) {
      conditions.add('(UPPER(p.id) LIKE ? OR UPPER(p.ear_tag) LIKE ?)');
      final pattern = '%${query.toUpperCase()}%';
      arguments.addAll([pattern, pattern]);
    }
    if (pigHouseId != null) {
      conditions.add('p.pig_house_id = ?');
      arguments.add(pigHouseId);
    }
    if (healthStatus != null) {
      conditions.add('latest.risk_level = ?');
      arguments.add(healthStatus.name);
    }
    final join = healthStatus == null
        ? ''
        : '''
          JOIN pig_daily_stats latest
            ON latest.pig_id = p.id
           AND latest.date = (
             SELECT MAX(previous.date)
             FROM pig_daily_stats previous
             WHERE previous.pig_id = p.id
           )
        ''';
    final where = conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';
    arguments.addAll([limit, offset]);
    final rows = await _database.rawQuery(
      'SELECT p.* FROM pigs p $join $where ORDER BY p.id LIMIT ? OFFSET ?',
      arguments,
    );
    return rows.map(Pig.fromMap).toList(growable: false);
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
    final pigRows = await _database.query(
      'pigs',
      where: 'id = ?',
      whereArgs: [pigId],
      limit: 1,
    );
    if (pigRows.isEmpty) return null;
    final immunizationRows = await _database.query(
      'immunization_records',
      where: 'pig_id = ?',
      whereArgs: [pigId],
      orderBy: 'immunized_at DESC',
    );
    return PigDetail(
      pig: Pig.fromMap(pigRows.first),
      latestStat: await getLatestStat(pigId),
      immunizations: immunizationRows
          .map(ImmunizationRecord.fromMap)
          .toList(growable: false),
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
    final conditions = <String>[];
    final arguments = <Object?>[];
    final query = numberQuery?.trim();
    if (query != null && query.isNotEmpty) {
      conditions.add('(UPPER(p.id) LIKE ? OR UPPER(p.ear_tag) LIKE ?)');
      final pattern = '%${query.toUpperCase()}%';
      arguments.addAll([pattern, pattern]);
    }
    if (pigHouseId != null) {
      conditions.add('p.pig_house_id = ?');
      arguments.add(pigHouseId);
    }
    if (healthStatus != null) {
      conditions.add('latest.risk_level = ?');
      arguments.add(healthStatus.name);
    }
    final where = conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';
    final orderBy = switch (sort) {
      PigSummarySort.id => 'p.id ASC',
      PigSummarySort.healthScoreAscending =>
        'CASE WHEN latest.health_score IS NULL THEN 1 ELSE 0 END, '
            'latest.health_score ASC, p.id ASC',
      PigSummarySort.weightDescending => 'latest.weight_kg DESC, p.id ASC',
      PigSummarySort.feedDescending => 'latest.feed_amount_kg DESC, p.id ASC',
      PigSummarySort.activityDescending =>
        'latest.activity_distance_meters DESC, p.id ASC',
    };
    arguments.addAll([limit, offset]);
    final rows = await _database.rawQuery('''
      SELECT
        p.*,
        latest.date AS stat_date,
        latest.weight_kg AS stat_weight_kg,
        latest.feed_amount_kg AS stat_feed_amount_kg,
        latest.feeding_duration_minutes AS stat_feeding_duration_minutes,
        latest.activity_distance_meters AS stat_activity_distance_meters,
        latest.activity_duration_minutes AS stat_activity_duration_minutes,
        latest.rest_duration_minutes AS stat_rest_duration_minutes,
        latest.health_score AS stat_health_score,
        latest.risk_level AS stat_risk_level
      FROM pigs p
      LEFT JOIN pig_daily_stats latest
        ON latest.pig_id = p.id
       AND latest.date = (
         SELECT MAX(previous.date)
         FROM pig_daily_stats previous
         WHERE previous.pig_id = p.id
       )
      $where
      ORDER BY $orderBy
      LIMIT ? OFFSET ?
    ''', arguments);
    return rows.map(_pigSummaryFromRow).toList(growable: false);
  }

  @override
  Future<List<PigDailyStat>> queryDailyStats({
    required String pigId,
    required DateTime from,
    required DateTime to,
  }) async {
    final rows = await _database.query(
      'pig_daily_stats',
      where: 'pig_id = ? AND date >= ? AND date <= ?',
      whereArgs: [
        pigId,
        from.millisecondsSinceEpoch,
        to.millisecondsSinceEpoch
      ],
      orderBy: 'date ASC',
    );
    return rows.map(PigDailyStat.fromMap).toList(growable: false);
  }

  @override
  Future<PigDailyStat?> getLatestStat(String pigId) async {
    final rows = await _database.query(
      'pig_daily_stats',
      where: 'pig_id = ?',
      whereArgs: [pigId],
      orderBy: 'date DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : PigDailyStat.fromMap(rows.first);
  }

  @override
  Future<HerdDailyAggregate?> getLatestHerdAggregate({
    String? pigHouseId,
  }) async {
    final rows = await _database.rawQuery('''
      SELECT MAX(s.date) AS latest_date
      FROM pig_daily_stats s
      JOIN pigs p ON p.id = s.pig_id
      ${pigHouseId == null ? '' : 'WHERE p.pig_house_id = ?'}
    ''', [if (pigHouseId != null) pigHouseId]);
    final latestDate = rows.firstOrNull?['latest_date'] as int?;
    if (latestDate == null) return null;
    final aggregates = await queryHerdDailyAggregates(
      from: DateTime.fromMillisecondsSinceEpoch(latestDate),
      to: DateTime.fromMillisecondsSinceEpoch(latestDate),
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
    final houseClause = pigHouseId == null ? '' : 'AND p.pig_house_id = ?';
    final arguments = <Object?>[
      from.millisecondsSinceEpoch,
      to.millisecondsSinceEpoch,
      if (pigHouseId != null) pigHouseId,
    ];
    final rows = await _database.rawQuery('''
      SELECT
        s.date AS date,
        COUNT(DISTINCT s.pig_id) AS pig_count,
        AVG(s.weight_kg) AS average_weight_kg,
        SUM(s.feed_amount_kg) AS total_feed_amount_kg,
        AVG(s.activity_distance_meters) AS average_activity_distance_meters,
        AVG(s.health_score) AS average_health_score,
        SUM(CASE WHEN s.risk_level = 'watch' THEN 1 ELSE 0 END) AS watch_count,
        SUM(CASE WHEN s.risk_level = 'high' THEN 1 ELSE 0 END) AS high_risk_count
      FROM pig_daily_stats s
      JOIN pigs p ON p.id = s.pig_id
      WHERE s.date >= ? AND s.date <= ? $houseClause
      GROUP BY s.date
      ORDER BY s.date ASC
    ''', arguments);
    return rows.map((row) {
      return HerdDailyAggregate(
        date: DateTime.fromMillisecondsSinceEpoch(row['date']! as int),
        pigCount: row['pig_count']! as int,
        averageWeightKg: (row['average_weight_kg']! as num).toDouble(),
        totalFeedAmountKg: (row['total_feed_amount_kg']! as num).toDouble(),
        averageActivityDistanceMeters:
            (row['average_activity_distance_meters']! as num).toDouble(),
        averageHealthScore: (row['average_health_score']! as num).toDouble(),
        watchCount: row['watch_count']! as int,
        highRiskCount: row['high_risk_count']! as int,
      );
    }).toList(growable: false);
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
    final conditions = <String>[];
    final arguments = <Object?>[];
    if (pigId != null) {
      conditions.add('pig_id = ?');
      arguments.add(pigId);
    }
    if (severity != null) {
      conditions.add('severity = ?');
      arguments.add(severity.name);
    }
    if (status != null) {
      conditions.add('status = ?');
      arguments.add(status.name);
    }
    if (from != null) {
      conditions.add('created_at >= ?');
      arguments.add(from.millisecondsSinceEpoch);
    }
    if (to != null) {
      conditions.add('created_at <= ?');
      arguments.add(to.millisecondsSinceEpoch);
    }
    final rows = await _database.query(
      'health_alerts',
      where: conditions.isEmpty ? null : conditions.join(' AND '),
      whereArgs: conditions.isEmpty ? null : arguments,
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(HealthAlert.fromMap).toList(growable: false);
  }

  @override
  Future<void> saveAlerts(Iterable<HealthAlert> alerts) async {
    final batch = _database.batch();
    for (final alert in alerts) {
      batch.insert(
        'health_alerts',
        alert.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<void> updateAlertStatus(
      String alertId, HealthAlertStatus status) async {
    await _database.update(
      'health_alerts',
      {'status': status.name},
      where: 'id = ?',
      whereArgs: [alertId],
    );
  }

  @override
  Future<List<EnvironmentRecord>> queryHistory({
    required String pigHouseId,
    required DateTime from,
    required DateTime to,
  }) async {
    final rows = await _database.query(
      'environment_records',
      where: 'pig_house_id = ? AND recorded_at >= ? AND recorded_at <= ?',
      whereArgs: [
        pigHouseId,
        from.millisecondsSinceEpoch,
        to.millisecondsSinceEpoch
      ],
      orderBy: 'recorded_at ASC',
    );
    return rows.map(EnvironmentRecord.fromMap).toList(growable: false);
  }

  @override
  Future<List<AiBehaviorRecord>> queryBehaviorRecords({
    String? pigId,
    DateTime? from,
    DateTime? to,
  }) async {
    final alerts = await queryAlerts(
      pigId: pigId,
      from: from,
      to: to,
      limit: 1000,
    );
    return const PrototypeAiBehaviorFactory().fromHealthAlerts(
      alerts,
      pigId: pigId,
      from: from,
      to: to,
    );
  }

  Future<void> close() => appDatabase.close();

  PigSummary _pigSummaryFromRow(Map<String, Object?> row) {
    final statDate = row['stat_date'] as int?;
    return PigSummary(
      pig: Pig.fromMap(row),
      latestStat: statDate == null
          ? null
          : PigDailyStat(
              pigId: row['id']! as String,
              date: DateTime.fromMillisecondsSinceEpoch(statDate),
              weightKg: (row['stat_weight_kg']! as num).toDouble(),
              feedAmountKg: (row['stat_feed_amount_kg']! as num).toDouble(),
              feedingDurationMinutes:
                  row['stat_feeding_duration_minutes']! as int,
              activityDistanceMeters:
                  (row['stat_activity_distance_meters']! as num).toDouble(),
              activityDurationMinutes:
                  row['stat_activity_duration_minutes']! as int,
              restDurationMinutes: row['stat_rest_duration_minutes']! as int,
              healthScore: row['stat_health_score']! as int,
              riskLevel:
                  RiskLevel.values.byName(row['stat_risk_level']! as String),
            ),
    );
  }
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
