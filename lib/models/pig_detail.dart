import 'immunization_record.dart';
import 'pig.dart';
import 'pig_daily_stat.dart';

class PigDetail {
  const PigDetail({
    required this.pig,
    required this.immunizations,
    this.latestStat,
  });

  final Pig pig;
  final PigDailyStat? latestStat;
  final List<ImmunizationRecord> immunizations;
}
