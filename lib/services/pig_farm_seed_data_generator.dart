import 'dart:math';

import '../models/environment_record.dart';
import '../models/health_alert.dart';
import '../models/immunization_record.dart';
import '../models/pig.dart';
import '../models/pig_daily_stat.dart';
import 'behavior_health_scoring_service.dart';
import 'health_alert_service.dart';

class PigFarmSeedData {
  const PigFarmSeedData({
    required this.pigs,
    required this.dailyStats,
    required this.healthAlerts,
    required this.immunizations,
    required this.environmentRecords,
  });

  final List<Pig> pigs;
  final List<PigDailyStat> dailyStats;
  final List<HealthAlert> healthAlerts;
  final List<ImmunizationRecord> immunizations;
  final List<EnvironmentRecord> environmentRecords;
}

class PigFarmSeedDataGenerator {
  PigFarmSeedDataGenerator({
    this.seed = 20260917,
    this.pigCount = 180,
    this.historyDays = 90,
    this.scoringService = const BehaviorHealthScoringService(),
    HealthAlertService? alertService,
  }) : alertService =
            alertService ?? HealthAlertService(scoringService: scoringService);

  final int seed;
  final int pigCount;
  final int historyDays;
  final BehaviorHealthScoringService scoringService;
  final HealthAlertService alertService;

  static const pigHouseIds = ['A01', 'A02', 'A03'];
  static const _anomalyPigNumbers = {
    8,
    19,
    37,
    44,
    58,
    73,
    91,
    104,
    118,
    129,
    143,
    157,
    169,
    178,
  };

  PigFarmSeedData generate({DateTime? endDate}) {
    final lastDay = _dateOnly(endDate ?? DateTime.now());
    final firstDay = lastDay.subtract(Duration(days: historyDays - 1));
    final basePigs = _generatePigs(lastDay);
    final statsByPig = <String, List<PigDailyStat>>{};
    final alerts = <HealthAlert>[];

    for (var pigIndex = 0; pigIndex < basePigs.length; pigIndex++) {
      final pig = basePigs[pigIndex];
      final history = <PigDailyStat>[];
      var weight = 23.5 + _noise(pigIndex + 1, firstDay, 1) * 5.5;

      for (var dayIndex = 0; dayIndex < historyDays; dayIndex++) {
        final date = firstDay.add(Duration(days: dayIndex));
        final envelope = _anomalyEnvelope(pigIndex + 1, dayIndex);
        final profile = _anomalyProfile(pigIndex + 1);
        final individualFactor = 0.9 + _noise(pigIndex + 1, lastDay, 2) * 0.2;
        final normalGain =
            (0.62 + _noise(pigIndex + 1, date, 3) * 0.24) * individualFactor;
        final gain =
            max(0.02, normalGain * (1 - profile.weightImpact * envelope));
        if (dayIndex > 0) {
          weight += gain;
        }

        final normalFeed = (1.05 + weight * 0.029) * individualFactor;
        final feed = normalFeed *
            (0.975 + _noise(pigIndex + 1, date, 4) * 0.05) *
            (1 - profile.feedImpact * envelope);
        final normalActivity =
            (1550 - weight * 4.2 + (individualFactor - 1) * 500)
                .clamp(760, 1680)
                .toDouble();
        final activity = normalActivity *
            (0.955 + _noise(pigIndex + 1, date, 5) * 0.09) *
            (1 - profile.activityImpact * envelope);
        final feedingMinutes =
            (22 + feed * 18 + _noise(pigIndex + 1, date, 6) * 8).round();
        final activityMinutes =
            (activity / 12.5 + _noise(pigIndex + 1, date, 7) * 10).round();
        final restMinutes = (1030 +
                weight * 0.7 -
                activityMinutes * 0.18 +
                _noise(pigIndex + 1, date, 8) * 35)
            .round()
            .clamp(900, 1210)
            .toInt();

        final draft = PigDailyStat(
          pigId: pig.id,
          date: date,
          weightKg: _round(weight, 2),
          feedAmountKg: _round(feed, 3),
          feedingDurationMinutes: feedingMinutes,
          activityDistanceMeters: _round(activity, 1),
          activityDurationMinutes: activityMinutes,
          restDurationMinutes: restMinutes,
          healthScore: 100,
          riskLevel: RiskLevel.normal,
        );
        final scoreResult =
            scoringService.score(current: draft, history: history);
        final stat = draft.copyWith(
          healthScore: scoreResult.score,
          riskLevel: scoreResult.riskLevel,
        );
        alerts.addAll(
            alertService.evaluate(pig: pig, current: stat, history: history));
        history.add(stat);
      }
      statsByPig[pig.id] = history;
    }

    final pigs = basePigs.map((pig) {
      final risk = statsByPig[pig.id]!.last.riskLevel;
      final status = switch (risk) {
        RiskLevel.normal => PigStatus.active,
        RiskLevel.watch => PigStatus.observation,
        RiskLevel.high => PigStatus.treatment,
      };
      return pig.copyWith(currentStatus: status);
    }).toList(growable: false);

    return PigFarmSeedData(
      pigs: pigs,
      dailyStats:
          statsByPig.values.expand((items) => items).toList(growable: false),
      healthAlerts: _deduplicateAlerts(alerts),
      immunizations: _generateImmunizations(pigs, lastDay),
      environmentRecords: generateEnvironmentRecords(endDate: lastDay),
    );
  }

  List<EnvironmentRecord> generateEnvironmentRecords({DateTime? endDate}) {
    final lastDay = _dateOnly(endDate ?? DateTime.now());
    final firstDay = lastDay.subtract(Duration(days: historyDays - 1));
    return _generateEnvironment(firstDay);
  }

  List<Pig> _generatePigs(DateTime lastDay) {
    return List.generate(pigCount, (index) {
      final number = index + 1;
      final houseIndex =
          (index * pigHouseIds.length ~/ pigCount).clamp(0, 2).toInt();
      final house = pigHouseIds[houseIndex];
      final withinHouse =
          index - houseIndex * (pigCount ~/ pigHouseIds.length) + 1;
      final id = 'PIG-${number.toString().padLeft(3, '0')}';
      return Pig(
        id: id,
        earTag: '$house-${withinHouse.toString().padLeft(3, '0')}',
        pigHouseId: house,
        batchNo: 'B-${lastDay.year}-${house.substring(1)}',
        sex: number.isEven ? PigSex.female : PigSex.male,
        birthDate: lastDay.subtract(Duration(days: 150 + number % 36)),
        currentStatus: PigStatus.active,
        createdAt: lastDay.subtract(Duration(days: historyDays + 7)),
      );
    }, growable: false);
  }

  List<ImmunizationRecord> _generateImmunizations(
      List<Pig> pigs, DateTime lastDay) {
    final records = <ImmunizationRecord>[];
    for (var index = 0; index < pigs.length; index++) {
      final pig = pigs[index];
      records.add(ImmunizationRecord(
        id: 'IMM-${pig.id}-CSF',
        pigId: pig.id,
        batchNo: pig.batchNo,
        vaccineName: '猪瘟活疫苗',
        immunizedAt: lastDay.subtract(Duration(days: 62 + index % 6)),
        nextDueAt: lastDay.add(Duration(days: 118 - index % 6)),
        operatorName: index.isEven ? '李师傅' : '王工',
        note: '批次免疫，观察无异常',
      ));
      if (index.isEven) {
        records.add(ImmunizationRecord(
          id: 'IMM-${pig.id}-FMD',
          pigId: pig.id,
          batchNo: pig.batchNo,
          vaccineName: '口蹄疫 O 型灭活疫苗',
          immunizedAt: lastDay.subtract(Duration(days: 28 + index % 5)),
          nextDueAt: lastDay.add(Duration(days: 152 - index % 5)),
          operatorName: index % 4 == 0 ? '赵工' : '王工',
          note: '二次免疫记录',
        ));
      }
    }
    return records;
  }

  List<EnvironmentRecord> _generateEnvironment(DateTime firstDay) {
    const sampleHours = [0, 6, 12, 18];
    final records = <EnvironmentRecord>[];
    for (var dayIndex = 0; dayIndex < historyDays; dayIndex++) {
      final date = firstDay.add(Duration(days: dayIndex));
      for (var houseIndex = 0; houseIndex < pigHouseIds.length; houseIndex++) {
        final house = pigHouseIds[houseIndex];
        for (final hour in sampleHours) {
          final timestamp = DateTime.utc(date.year, date.month, date.day, hour);
          final dailyWave = sin((hour - 6) / 24 * 2 * pi);
          final slowWave = sin(dayIndex / 18 * pi);
          final noise = _noise(houseIndex + 1, timestamp, 30);
          final temperature = (25.1 +
                  dailyWave * 0.28 +
                  slowWave * 0.12 +
                  (houseIndex - 1) * 0.07 +
                  (noise - 0.5) * 0.08)
              .clamp(24.6, 25.8)
              .toDouble();
          final humidity = 67 -
              dailyWave * 7 +
              houseIndex * 1.4 +
              (_noise(houseIndex + 1, timestamp, 31) - 0.5) * 4;
          final lightBase = switch (hour) {
            0 => 8.0,
            6 => 95.0,
            12 => 430.0,
            _ => 150.0,
          };
          final light = lightBase +
              houseIndex * 12 +
              (_noise(houseIndex + 1, timestamp, 32) - 0.5) * 24;
          final dateKey = '${date.year.toString().padLeft(4, '0')}'
              '${date.month.toString().padLeft(2, '0')}'
              '${date.day.toString().padLeft(2, '0')}';
          records.add(EnvironmentRecord(
            id: 'ENV-$house-$dateKey-${hour.toString().padLeft(2, '0')}',
            pigHouseId: house,
            recordedAt: timestamp,
            temperature: _round(temperature, 2),
            humidity: _round(humidity, 2),
            light: _round(max(0, light), 1),
          ));
        }
      }
    }
    return records;
  }

  _AnomalyProfile _anomalyProfile(int pigNumber) {
    if (!_anomalyPigNumbers.contains(pigNumber)) {
      return const _AnomalyProfile();
    }
    switch (pigNumber % 5) {
      case 0:
        return const _AnomalyProfile(
            feedImpact: 0.42, activityImpact: 0.08, weightImpact: 0.35);
      case 1:
        return const _AnomalyProfile(
            feedImpact: 0.08, activityImpact: 0.48, weightImpact: 0.3);
      case 2:
        return const _AnomalyProfile(
            feedImpact: 0.2, activityImpact: 0.16, weightImpact: 0.82);
      case 3:
        return const _AnomalyProfile(
            feedImpact: 0.4, activityImpact: 0.47, weightImpact: 0.68);
      default:
        return const _AnomalyProfile(
            feedImpact: 0.34, activityImpact: 0.38, weightImpact: 0.55);
    }
  }

  double _anomalyEnvelope(int pigNumber, int dayIndex) {
    if (!_anomalyPigNumbers.contains(pigNumber)) return 0;
    final profileIndex = _anomalyPigNumbers.toList()..sort();
    final index = profileIndex.indexOf(pigNumber);
    final hasRecovery = index % 3 == 0;
    final daysFromEnd = hasRecovery ? 10 + index % 3 : 6 + index % 3;
    final start = historyDays - daysFromEnd;
    final relative = dayIndex - start;
    if (relative < 0) return 0;
    if (relative == 0) return 0.35;
    if (relative == 1) return 0.72;
    if (!hasRecovery || relative <= 4) return 1;
    final recovery = 1 - (relative - 4) / 5;
    return recovery.clamp(0, 1).toDouble();
  }

  List<HealthAlert> _deduplicateAlerts(List<HealthAlert> alerts) {
    final byId = <String, HealthAlert>{};
    for (final alert in alerts) {
      byId.putIfAbsent(alert.id, () => alert);
    }
    final result = byId.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  double _noise(int entity, DateTime date, int channel) {
    final dayKey = date.year * 10000 + date.month * 100 + date.day;
    return Random(seed + entity * 100003 + dayKey * 37 + channel * 997)
        .nextDouble();
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day);

  double _round(double value, int digits) {
    final factor = pow(10, digits).toDouble();
    return (value * factor).round() / factor;
  }
}

class _AnomalyProfile {
  const _AnomalyProfile({
    this.feedImpact = 0,
    this.activityImpact = 0,
    this.weightImpact = 0,
  });

  final double feedImpact;
  final double activityImpact;
  final double weightImpact;
}
