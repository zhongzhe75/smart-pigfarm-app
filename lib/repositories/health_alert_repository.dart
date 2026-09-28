import '../models/health_alert.dart';

abstract interface class HealthAlertRepository {
  Future<List<HealthAlert>> queryAlerts({
    String? pigId,
    HealthAlertSeverity? severity,
    HealthAlertStatus? status,
    DateTime? from,
    DateTime? to,
    int limit = 100,
    int offset = 0,
  });

  Future<void> saveAlerts(Iterable<HealthAlert> alerts);

  Future<void> updateAlertStatus(String alertId, HealthAlertStatus status);
}
