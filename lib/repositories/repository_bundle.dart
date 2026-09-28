import 'ai_behavior_repository.dart';
import 'environment_repository.dart';
import 'health_alert_repository.dart';
import 'pig_metrics_repository.dart';
import 'pig_repository.dart';

class RepositoryBundle {
  const RepositoryBundle({
    required this.pigs,
    required this.pigMetrics,
    required this.healthAlerts,
    required this.environment,
    required this.aiBehavior,
    required Future<void> Function() dispose,
  }) : _dispose = dispose;

  final PigRepository pigs;
  final PigMetricsRepository pigMetrics;
  final HealthAlertRepository healthAlerts;
  final EnvironmentRepository environment;
  final AiBehaviorRepository aiBehavior;
  final Future<void> Function() _dispose;

  Future<void> dispose() => _dispose();
}
