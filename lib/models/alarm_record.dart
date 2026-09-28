enum AlarmType {
  environment,
  deviceFault,
  feedShortage,
  aiException,
}

extension AlarmTypeText on AlarmType {
  String get label {
    switch (this) {
      case AlarmType.environment:
        return '环境超限';
      case AlarmType.deviceFault:
        return '设备故障';
      case AlarmType.feedShortage:
        return '料位不足';
      case AlarmType.aiException:
        return 'AI 异常事件';
    }
  }
}

enum AlarmLevel {
  info,
  warning,
  critical,
}

extension AlarmLevelText on AlarmLevel {
  String get label {
    switch (this) {
      case AlarmLevel.info:
        return '提示';
      case AlarmLevel.warning:
        return '预警';
      case AlarmLevel.critical:
        return '严重';
    }
  }
}

enum AlarmStatus {
  unhandled,
  handled,
}

extension AlarmStatusText on AlarmStatus {
  String get label {
    switch (this) {
      case AlarmStatus.unhandled:
        return '未处理';
      case AlarmStatus.handled:
        return '已处理';
    }
  }
}

class AlarmRecord {
  const AlarmRecord({
    required this.id,
    required this.time,
    required this.pigHouseId,
    required this.type,
    required this.currentValue,
    required this.threshold,
    required this.level,
    required this.status,
    required this.message,
  });

  final String id;
  final DateTime time;
  final String pigHouseId;
  final AlarmType type;
  final String currentValue;
  final String threshold;
  final AlarmLevel level;
  final AlarmStatus status;
  final String message;

  AlarmRecord copyWith({
    AlarmStatus? status,
  }) {
    return AlarmRecord(
      id: id,
      time: time,
      pigHouseId: pigHouseId,
      type: type,
      currentValue: currentValue,
      threshold: threshold,
      level: level,
      status: status ?? this.status,
      message: message,
    );
  }
}
