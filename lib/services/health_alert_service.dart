import '../models/health_alert.dart';
import '../models/pig.dart';
import '../models/pig_daily_stat.dart';
import 'behavior_health_scoring_service.dart';

class HealthAlertService {
  const HealthAlertService({
    this.scoringService = const BehaviorHealthScoringService(),
  });

  final BehaviorHealthScoringService scoringService;

  List<HealthAlert> evaluate({
    required Pig pig,
    required PigDailyStat current,
    required List<PigDailyStat> history,
  }) {
    final result = scoringService.score(current: current, history: history);
    final alerts = <HealthAlert>[];

    if (result.feedDropPercent > 30) {
      alerts.add(_alert(
        pig: pig,
        current: current,
        type: HealthAlertType.feedDrop,
        severity: result.feedDropPercent >= 45
            ? HealthAlertSeverity.critical
            : HealthAlertSeverity.warning,
        title: '个体采食量下降',
        description: '今日采食量明显低于该猪过去 7 日基线，建议现场复核。',
        currentValue: current.feedAmountKg,
        baselineValue: result.feedBaselineKg,
        deviationPercent: result.feedDropPercent,
      ));
    }

    if (result.activityDropPercent > 35) {
      alerts.add(_alert(
        pig: pig,
        current: current,
        type: HealthAlertType.activityDrop,
        severity: result.activityDropPercent >= 50
            ? HealthAlertSeverity.critical
            : HealthAlertSeverity.warning,
        title: '个体活动量下降',
        description: '今日活动距离明显低于该猪过去 7 日基线。',
        currentValue: current.activityDistanceMeters,
        baselineValue: result.activityBaselineMeters,
        deviationPercent: result.activityDropPercent,
      ));
    }

    if (result.weightGainDeficitPercent > 50) {
      alerts.add(_alert(
        pig: pig,
        current: current,
        type: HealthAlertType.weightGainAbnormal,
        severity: result.weightGainDeficitPercent >= 75
            ? HealthAlertSeverity.critical
            : HealthAlertSeverity.warning,
        title: '体重增长异常',
        description: '近期日增重明显低于该猪自身基线。',
        currentValue: current.weightKg,
        baselineValue: result.weightGainBaselineKg,
        deviationPercent: result.weightGainDeficitPercent,
      ));
    }

    if (result.feedDropPercent > 20 && result.activityDropPercent > 25) {
      alerts.add(_alert(
        pig: pig,
        current: current,
        type: HealthAlertType.multiFactorRisk,
        severity: result.riskLevel == RiskLevel.high
            ? HealthAlertSeverity.critical
            : HealthAlertSeverity.warning,
        title: '多因素行为风险',
        description: '采食和活动指标同时下降，建议优先巡检。',
        currentValue: result.score.toDouble(),
        baselineValue: 85,
        deviationPercent: 100 - result.score.toDouble(),
      ));
    }

    return alerts;
  }

  HealthAlert _alert({
    required Pig pig,
    required PigDailyStat current,
    required HealthAlertType type,
    required HealthAlertSeverity severity,
    required String title,
    required String description,
    required double currentValue,
    required double baselineValue,
    required double deviationPercent,
  }) {
    final dateKey = '${current.date.year.toString().padLeft(4, '0')}'
        '${current.date.month.toString().padLeft(2, '0')}'
        '${current.date.day.toString().padLeft(2, '0')}';
    return HealthAlert(
      id: 'HA-${pig.id}-$dateKey-${type.storageValue}',
      pigId: pig.id,
      pigHouseId: pig.pigHouseId,
      createdAt: current.date.add(const Duration(hours: 20)),
      alertType: type,
      severity: severity,
      title: title,
      description: description,
      currentValue: currentValue,
      baselineValue: baselineValue,
      deviationPercent: deviationPercent,
      status: HealthAlertStatus.open,
    );
  }
}
