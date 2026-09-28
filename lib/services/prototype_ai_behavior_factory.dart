import '../models/ai_behavior_record.dart';
import '../models/health_alert.dart';

class PrototypeAiBehaviorFactory {
  const PrototypeAiBehaviorFactory();

  List<AiBehaviorRecord> fromHealthAlerts(
    Iterable<HealthAlert> alerts, {
    String? pigId,
    DateTime? from,
    DateTime? to,
  }) {
    final records = <AiBehaviorRecord>[];
    for (final alert in alerts) {
      if ((pigId != null && alert.pigId != pigId) ||
          (from != null && alert.createdAt.isBefore(from)) ||
          (to != null && alert.createdAt.isAfter(to))) {
        continue;
      }
      final behaviorType = switch (alert.alertType) {
        HealthAlertType.activityDrop => 'low_activity',
        HealthAlertType.feedDrop => 'feeding_reduction',
        HealthAlertType.weightGainAbnormal => 'abnormal_behavior',
        HealthAlertType.multiFactorRisk => 'abnormal_behavior',
      };
      final deviation = alert.deviationPercent.abs().clamp(0, 100);
      records.add(AiBehaviorRecord(
        id: 'CAM-PROTOTYPE-${alert.id}',
        pigId: alert.pigId,
        pigHouseId: alert.pigHouseId,
        occurredAt: alert.createdAt,
        behaviorType: behaviorType,
        confidence: (0.68 + deviation / 500).clamp(0.68, 0.88),
        durationSeconds: (deviation * 18).round().clamp(60, 1800),
        source: 'camera_prototype',
        cameraId: 'H6c-A01',
      ));
    }
    records.sort((left, right) => right.occurredAt.compareTo(left.occurredAt));
    return List<AiBehaviorRecord>.unmodifiable(records);
  }
}
