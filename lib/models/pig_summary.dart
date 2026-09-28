import 'pig.dart';
import 'pig_daily_stat.dart';

class PigSummary {
  const PigSummary({
    required this.pig,
    this.latestStat,
  });

  final Pig pig;
  final PigDailyStat? latestStat;
}
