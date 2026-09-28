import '../models/herd_daily_aggregate.dart';
import '../models/pig_daily_stat.dart';

abstract interface class PigMetricsRepository {
  Future<List<PigDailyStat>> queryDailyStats({
    required String pigId,
    required DateTime from,
    required DateTime to,
  });

  Future<PigDailyStat?> getLatestStat(String pigId);

  Future<HerdDailyAggregate?> getLatestHerdAggregate({String? pigHouseId});

  Future<List<HerdDailyAggregate>> queryHerdDailyAggregates({
    required DateTime from,
    required DateTime to,
    String? pigHouseId,
  });
}
