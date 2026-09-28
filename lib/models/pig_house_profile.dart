class ImmunityRecord {
  const ImmunityRecord({
    required this.vaccine,
    required this.date,
    required this.operatorName,
    required this.note,
  });

  final String vaccine;
  final DateTime date;
  final String operatorName;
  final String note;
}

class PigHouseProfile {
  const PigHouseProfile({
    required this.pigHouseId,
    required this.pigCount,
    required this.averageWeightKg,
    required this.todayFeedKg,
    required this.feedMeatRatio,
    required this.estimatedMarketDate,
    required this.soldToday,
    required this.soldThisMonth,
    required this.immunityRecords,
  });

  final String pigHouseId;
  final int pigCount;
  final double averageWeightKg;
  final double todayFeedKg;
  final double feedMeatRatio;
  final DateTime estimatedMarketDate;
  final int soldToday;
  final int soldThisMonth;
  final List<ImmunityRecord> immunityRecords;
}
