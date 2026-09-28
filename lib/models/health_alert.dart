enum HealthAlertType {
  feedDrop,
  activityDrop,
  weightGainAbnormal,
  multiFactorRisk,
}

extension HealthAlertTypeStorage on HealthAlertType {
  String get label {
    switch (this) {
      case HealthAlertType.feedDrop:
        return '采食量异常下降';
      case HealthAlertType.activityDrop:
        return '活动量异常下降';
      case HealthAlertType.weightGainAbnormal:
        return '体重增长异常';
      case HealthAlertType.multiFactorRisk:
        return '多因素行为风险';
    }
  }

  String get storageValue {
    switch (this) {
      case HealthAlertType.feedDrop:
        return 'feed_drop';
      case HealthAlertType.activityDrop:
        return 'activity_drop';
      case HealthAlertType.weightGainAbnormal:
        return 'weight_gain_abnormal';
      case HealthAlertType.multiFactorRisk:
        return 'multi_factor_risk';
    }
  }

  static HealthAlertType fromStorage(String value) {
    return HealthAlertType.values.firstWhere(
      (type) => type.storageValue == value,
      orElse: () => HealthAlertType.multiFactorRisk,
    );
  }
}

enum HealthAlertSeverity {
  warning,
  critical,
}

enum HealthAlertStatus {
  open,
  acknowledged,
  resolved,
}

extension HealthAlertSeverityText on HealthAlertSeverity {
  String get label => this == HealthAlertSeverity.critical ? '高风险' : '重点关注';
}

extension HealthAlertStatusText on HealthAlertStatus {
  String get label {
    switch (this) {
      case HealthAlertStatus.open:
        return '未处理';
      case HealthAlertStatus.acknowledged:
        return '已确认';
      case HealthAlertStatus.resolved:
        return '已解除';
    }
  }
}

class HealthAlert {
  const HealthAlert({
    required this.id,
    required this.pigId,
    required this.pigHouseId,
    required this.createdAt,
    required this.alertType,
    required this.severity,
    required this.title,
    required this.description,
    required this.currentValue,
    required this.baselineValue,
    required this.deviationPercent,
    required this.status,
  });

  final String id;
  final String pigId;
  final String pigHouseId;
  final DateTime createdAt;
  final HealthAlertType alertType;
  final HealthAlertSeverity severity;
  final String title;
  final String description;
  final double currentValue;
  final double baselineValue;
  final double deviationPercent;
  final HealthAlertStatus status;

  HealthAlert copyWith({HealthAlertStatus? status}) {
    return HealthAlert(
      id: id,
      pigId: pigId,
      pigHouseId: pigHouseId,
      createdAt: createdAt,
      alertType: alertType,
      severity: severity,
      title: title,
      description: description,
      currentValue: currentValue,
      baselineValue: baselineValue,
      deviationPercent: deviationPercent,
      status: status ?? this.status,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'pig_id': pigId,
      'pig_house_id': pigHouseId,
      'created_at': createdAt.millisecondsSinceEpoch,
      'alert_type': alertType.storageValue,
      'severity': severity.name,
      'title': title,
      'description': description,
      'current_value': currentValue,
      'baseline_value': baselineValue,
      'deviation_percent': deviationPercent,
      'status': status.name,
    };
  }

  factory HealthAlert.fromMap(Map<String, Object?> map) {
    return HealthAlert(
      id: map['id']! as String,
      pigId: map['pig_id']! as String,
      pigHouseId: map['pig_house_id']! as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']! as int),
      alertType:
          HealthAlertTypeStorage.fromStorage(map['alert_type']! as String),
      severity: HealthAlertSeverity.values.byName(map['severity']! as String),
      title: map['title']! as String,
      description: map['description']! as String,
      currentValue: (map['current_value']! as num).toDouble(),
      baselineValue: (map['baseline_value']! as num).toDouble(),
      deviationPercent: (map['deviation_percent']! as num).toDouble(),
      status: HealthAlertStatus.values.byName(map['status']! as String),
    );
  }
}
