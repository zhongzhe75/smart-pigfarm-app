enum DeviceType {
  fan,
  sprayPump,
  heater,
  ledLight,
  feederLine,
}

extension DeviceTypeText on DeviceType {
  String get label {
    switch (this) {
      case DeviceType.fan:
        return '风机';
      case DeviceType.sprayPump:
        return '喷雾泵';
      case DeviceType.heater:
        return '加热风扇';
      case DeviceType.ledLight:
        return 'LED 补光';
      case DeviceType.feederLine:
        return '喂料输送线';
    }
  }

  String get description {
    switch (this) {
      case DeviceType.fan:
        return '通风换气，降低氨气和 CO₂';
      case DeviceType.sprayPump:
        return '喷雾降温与湿度调节';
      case DeviceType.heater:
        return '低温环境升温保育';
      case DeviceType.ledLight:
        return '稳定光照周期';
      case DeviceType.feederLine:
        return '定时输送饲料';
    }
  }
}

enum DeviceMode {
  automatic,
  manual,
}

extension DeviceModeText on DeviceMode {
  String get label {
    switch (this) {
      case DeviceMode.automatic:
        return '自动模式';
      case DeviceMode.manual:
        return '手动模式';
    }
  }
}

class DeviceStatus {
  const DeviceStatus({
    required this.type,
    required this.isOn,
    required this.mode,
    required this.runningMinutesToday,
    required this.updatedAt,
  });

  final DeviceType type;
  final bool isOn;
  final DeviceMode mode;
  final int runningMinutesToday;
  final DateTime updatedAt;

  DeviceStatus copyWith({
    bool? isOn,
    DeviceMode? mode,
    int? runningMinutesToday,
    DateTime? updatedAt,
  }) {
    return DeviceStatus(
      type: type,
      isOn: isOn ?? this.isOn,
      mode: mode ?? this.mode,
      runningMinutesToday: runningMinutesToday ?? this.runningMinutesToday,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
