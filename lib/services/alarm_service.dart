import 'dart:math';

import '../models/alarm_record.dart';
import '../models/sensor_snapshot.dart';
import '../models/threshold_settings.dart';

class AlarmService {
  AlarmService() : _random = Random();

  final Random _random;

  List<AlarmRecord> evaluateEnvironment({
    required SensorSnapshot snapshot,
    required ThresholdSettings thresholds,
  }) {
    final records = <AlarmRecord>[];
    if (snapshot.temperature > thresholds.temperatureHigh) {
      records.add(_environmentAlarm(
        snapshot: snapshot,
        currentValue: '${snapshot.temperature.toStringAsFixed(1)} ℃',
        threshold: '≤ ${thresholds.temperatureHigh.toStringAsFixed(1)} ℃',
        level: AlarmLevel.warning,
        message: '温度高于上限，建议开启风机或喷雾',
      ));
    }
    if (snapshot.temperature < thresholds.temperatureLow) {
      records.add(_environmentAlarm(
        snapshot: snapshot,
        currentValue: '${snapshot.temperature.toStringAsFixed(1)} ℃',
        threshold: '≥ ${thresholds.temperatureLow.toStringAsFixed(1)} ℃',
        level: AlarmLevel.warning,
        message: '温度低于下限，建议检查加热风扇',
      ));
    }
    if (snapshot.humidity > thresholds.humidityHigh) {
      records.add(_environmentAlarm(
        snapshot: snapshot,
        currentValue: '${snapshot.humidity.toStringAsFixed(0)} %',
        threshold: '≤ ${thresholds.humidityHigh.toStringAsFixed(0)} %',
        level: AlarmLevel.warning,
        message: '湿度偏高，建议增强通风',
      ));
    }
    if (snapshot.humidity < thresholds.humidityLow) {
      records.add(_environmentAlarm(
        snapshot: snapshot,
        currentValue: '${snapshot.humidity.toStringAsFixed(0)} %',
        threshold: '≥ ${thresholds.humidityLow.toStringAsFixed(0)} %',
        level: AlarmLevel.info,
        message: '湿度偏低，建议短时开启喷雾',
      ));
    }
    if (snapshot.ammonia > thresholds.ammoniaHigh) {
      records.add(_environmentAlarm(
        snapshot: snapshot,
        currentValue: '${snapshot.ammonia.toStringAsFixed(1)} ppm',
        threshold: '≤ ${thresholds.ammoniaHigh.toStringAsFixed(1)} ppm',
        level: AlarmLevel.critical,
        message: '氨气浓度超限，请立即通风',
      ));
    }
    if (snapshot.co2 > thresholds.co2High) {
      records.add(_environmentAlarm(
        snapshot: snapshot,
        currentValue: '${snapshot.co2.toStringAsFixed(0)} ppm',
        threshold: '≤ ${thresholds.co2High.toStringAsFixed(0)} ppm',
        level: AlarmLevel.warning,
        message: 'CO₂ 浓度偏高，建议检查风机',
      ));
    }
    if (snapshot.illuminance < thresholds.illuminanceLow) {
      records.add(_environmentAlarm(
        snapshot: snapshot,
        currentValue: '${snapshot.illuminance.toStringAsFixed(0)} lx',
        threshold: '≥ ${thresholds.illuminanceLow.toStringAsFixed(0)} lx',
        level: AlarmLevel.info,
        message: '光照不足，建议开启 LED 补光',
      ));
    }
    return records;
  }

  AlarmRecord createAlarmTestRecord(String pigHouseId) {
    final options = [
      AlarmRecord(
        id: _id('alarm'),
        time: DateTime.now(),
        pigHouseId: pigHouseId,
        type: AlarmType.deviceFault,
        currentValue: '风机 2# 无反馈',
        threshold: '启动后 5s 内应反馈',
        level: AlarmLevel.critical,
        status: AlarmStatus.unhandled,
        message: '设备故障：风机接触器反馈异常',
      ),
      AlarmRecord(
        id: _id('alarm'),
        time: DateTime.now(),
        pigHouseId: pigHouseId,
        type: AlarmType.feedShortage,
        currentValue: '料塔余量 14%',
        threshold: '≥ 20%',
        level: AlarmLevel.warning,
        status: AlarmStatus.unhandled,
        message: '料位不足：建议安排补料',
      ),
      AlarmRecord(
        id: _id('alarm'),
        time: DateTime.now(),
        pigHouseId: pigHouseId,
        type: AlarmType.environment,
        currentValue: '氨气 31.6 ppm',
        threshold: '≤ 25.0 ppm',
        level: AlarmLevel.critical,
        status: AlarmStatus.unhandled,
        message: '环境超限：氨气浓度升高',
      ),
    ];
    return options[_random.nextInt(options.length)];
  }

  AlarmRecord simulateAiAlarm(String pigHouseId) {
    return AlarmRecord(
      id: _id('ai'),
      time: DateTime.now(),
      pigHouseId: pigHouseId,
      type: AlarmType.aiException,
      currentValue: '咳嗽 8.6 次/分钟',
      threshold: '≤ 3.0 次/分钟',
      level: AlarmLevel.warning,
      status: AlarmStatus.unhandled,
      message: '视频 AI 识别到疑似呼吸道异常',
    );
  }

  AlarmRecord _environmentAlarm({
    required SensorSnapshot snapshot,
    required String currentValue,
    required String threshold,
    required AlarmLevel level,
    required String message,
  }) {
    return AlarmRecord(
      id: _id('env'),
      time: snapshot.collectedAt,
      pigHouseId: snapshot.pigHouseId,
      type: AlarmType.environment,
      currentValue: currentValue,
      threshold: threshold,
      level: level,
      status: AlarmStatus.unhandled,
      message: message,
    );
  }

  String _id(String prefix) {
    return '$prefix-${DateTime.now().millisecondsSinceEpoch}-${_random.nextInt(9999)}';
  }
}
