import 'dart:math';

import '../models/pig_daily_stat.dart';

class HealthScoreResult {
  const HealthScoreResult({
    required this.score,
    required this.riskLevel,
    required this.feedBaselineKg,
    required this.activityBaselineMeters,
    required this.weightGainBaselineKg,
    required this.feedDropPercent,
    required this.activityDropPercent,
    required this.weightGainDeficitPercent,
    required this.consecutiveAbnormalDays,
  });

  final int score;
  final RiskLevel riskLevel;
  final double feedBaselineKg;
  final double activityBaselineMeters;
  final double weightGainBaselineKg;
  final double feedDropPercent;
  final double activityDropPercent;
  final double weightGainDeficitPercent;
  final int consecutiveAbnormalDays;
}

/// Scores behavioral risk against the pig's own recent history.
///
/// This is an explainable risk indicator for husbandry review. It is not a
/// disease diagnosis model.
class BehaviorHealthScoringService {
  const BehaviorHealthScoringService();

  HealthScoreResult score({
    required PigDailyStat current,
    required List<PigDailyStat> history,
  }) {
    final ordered = history
        .where((item) => item.date.isBefore(current.date))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final baselineWindow =
        ordered.length <= 7 ? ordered : ordered.sublist(ordered.length - 7);

    if (baselineWindow.length < 3) {
      return const HealthScoreResult(
        score: 100,
        riskLevel: RiskLevel.normal,
        feedBaselineKg: 0,
        activityBaselineMeters: 0,
        weightGainBaselineKg: 0,
        feedDropPercent: 0,
        activityDropPercent: 0,
        weightGainDeficitPercent: 0,
        consecutiveAbnormalDays: 0,
      );
    }

    final feedBaseline =
        _average(baselineWindow.map((item) => item.feedAmountKg));
    final activityBaseline = _average(
      baselineWindow.map((item) => item.activityDistanceMeters),
    );
    final feedDrop = _dropPercent(feedBaseline, current.feedAmountKg);
    final activityDrop =
        _dropPercent(activityBaseline, current.activityDistanceMeters);

    final gainSource =
        ordered.length <= 8 ? ordered : ordered.sublist(ordered.length - 8);
    final historicalGains = <double>[];
    for (var index = 1; index < gainSource.length; index++) {
      historicalGains.add(
        max(0, gainSource[index].weightKg - gainSource[index - 1].weightKg),
      );
    }
    final weightGainBaseline =
        historicalGains.isEmpty ? 0.0 : _average(historicalGains);
    final latestWeight = ordered.last.weightKg;
    final currentGain = current.weightKg - latestWeight;
    final weightGainDeficit = weightGainBaseline <= 0
        ? 0.0
        : max(
            0.0,
            (weightGainBaseline - currentGain) / weightGainBaseline * 100,
          );

    var consecutiveAbnormalDays = 0;
    for (final item in ordered.reversed) {
      if (item.riskLevel == RiskLevel.normal) {
        break;
      }
      consecutiveAbnormalDays++;
      if (consecutiveAbnormalDays == 4) {
        break;
      }
    }

    var deduction = 0;
    deduction += _feedDeduction(feedDrop);
    deduction += _activityDeduction(activityDrop);
    deduction += _weightDeduction(weightGainDeficit, currentGain);
    deduction += min(12, consecutiveAbnormalDays * 4);

    if (feedDrop >= 20 && activityDrop >= 25) {
      deduction += 8;
    }

    final score = (100 - deduction).clamp(0, 100).toInt();
    return HealthScoreResult(
      score: score,
      riskLevel: _riskLevel(score),
      feedBaselineKg: feedBaseline,
      activityBaselineMeters: activityBaseline,
      weightGainBaselineKg: weightGainBaseline,
      feedDropPercent: feedDrop,
      activityDropPercent: activityDrop,
      weightGainDeficitPercent: weightGainDeficit,
      consecutiveAbnormalDays: consecutiveAbnormalDays,
    );
  }

  double _average(Iterable<double> values) {
    final list = values.toList();
    return list.reduce((left, right) => left + right) / list.length;
  }

  double _dropPercent(double baseline, double current) {
    if (baseline <= 0 || current >= baseline) {
      return 0;
    }
    return (baseline - current) / baseline * 100;
  }

  int _feedDeduction(double drop) {
    if (drop >= 40) return 32;
    if (drop >= 30) return 24;
    if (drop >= 20) return 14;
    if (drop >= 10) return 6;
    return 0;
  }

  int _activityDeduction(double drop) {
    if (drop >= 50) return 30;
    if (drop >= 35) return 24;
    if (drop >= 25) return 15;
    if (drop >= 12) return 6;
    return 0;
  }

  int _weightDeduction(double deficit, double currentGain) {
    if (currentGain < 0) return 25;
    if (deficit >= 65) return 20;
    if (deficit >= 45) return 13;
    if (deficit >= 20) return 6;
    return 0;
  }

  RiskLevel _riskLevel(int score) {
    if (score >= 85) return RiskLevel.normal;
    if (score >= 70) return RiskLevel.watch;
    return RiskLevel.high;
  }
}
