import '../models/pig.dart';
import '../models/pig_daily_stat.dart';
import '../models/pig_detail.dart';
import '../models/pig_summary.dart';

enum PigSummarySort {
  id,
  healthScoreAscending,
  weightDescending,
  feedDescending,
  activityDescending,
}

abstract interface class PigRepository {
  Future<List<Pig>> queryPigs({
    String? numberQuery,
    String? pigHouseId,
    RiskLevel? healthStatus,
    int limit = 50,
    int offset = 0,
  });

  Future<List<Pig>> searchByNumber(String query, {int limit = 50});

  Future<List<Pig>> filterByPigHouse(String pigHouseId, {int limit = 100});

  Future<List<Pig>> filterByHealthStatus(RiskLevel healthStatus,
      {int limit = 100});

  Future<PigDetail?> getPigDetail(String pigId);

  Future<List<PigSummary>> queryPigSummaries({
    String? numberQuery,
    String? pigHouseId,
    RiskLevel? healthStatus,
    PigSummarySort sort = PigSummarySort.id,
    int limit = 50,
    int offset = 0,
  });
}
