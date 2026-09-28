import 'dart:math';

import '../models/ai_insight.dart';
import '../models/device_status.dart';
import '../models/pig_house_profile.dart';
import '../models/report_data.dart';
import '../models/sensor_snapshot.dart';
import '../models/threshold_settings.dart';

class SimulationService {
  SimulationService() : _random = Random();

  final Random _random;
  double _temperatureBase = 25.0;
  double _humidityBase = 66;
  double _ammoniaBase = 10;
  double _co2Base = 1050;
  double _lightBase = 220;

  SensorSnapshot nextSensorSnapshot({
    required String pigHouseId,
    required ThresholdSettings thresholds,
  }) {
    _temperatureBase = _meanRevertingDrift(
      _temperatureBase,
      target: 25.0,
      min: 24.6,
      max: 25.8,
      step: 0.18,
      pull: 0.16,
    );
    _humidityBase = _drift(_humidityBase, min: 42, max: 88, step: 3.4);
    _ammoniaBase = _drift(_ammoniaBase, min: 4, max: 29, step: 2.0);
    _co2Base = _drift(_co2Base, min: 620, max: 2150, step: 120);
    _lightBase = _drift(_lightBase, min: 70, max: 520, step: 48);

    final hasSensorSpike = _random.nextDouble() < 0.08;
    final ammonia =
        hasSensorSpike ? _ammoniaBase + _random.nextDouble() * 8 : _ammoniaBase;
    final co2 =
        hasSensorSpike ? _co2Base + _random.nextDouble() * 380 : _co2Base;
    final score = _scoreEnvironment(
      thresholds: thresholds,
      temperature: _temperatureBase,
      humidity: _humidityBase,
      ammonia: ammonia,
      co2: co2,
      light: _lightBase,
    );

    return SensorSnapshot(
      pigHouseId: pigHouseId,
      collectedAt: DateTime.now(),
      temperature: _temperatureBase,
      humidity: _humidityBase,
      ammonia: ammonia,
      co2: co2,
      illuminance: _lightBase,
      environmentScore: score,
      environmentStatus: _statusFromScore(score),
    );
  }

  Map<DeviceType, DeviceStatus> initialDeviceStatuses() {
    final now = DateTime.now();
    return {
      DeviceType.fan: DeviceStatus(
        type: DeviceType.fan,
        isOn: true,
        mode: DeviceMode.automatic,
        runningMinutesToday: 188,
        updatedAt: now,
      ),
      DeviceType.sprayPump: DeviceStatus(
        type: DeviceType.sprayPump,
        isOn: false,
        mode: DeviceMode.automatic,
        runningMinutesToday: 42,
        updatedAt: now,
      ),
      DeviceType.heater: DeviceStatus(
        type: DeviceType.heater,
        isOn: false,
        mode: DeviceMode.automatic,
        runningMinutesToday: 26,
        updatedAt: now,
      ),
      DeviceType.ledLight: DeviceStatus(
        type: DeviceType.ledLight,
        isOn: true,
        mode: DeviceMode.automatic,
        runningMinutesToday: 312,
        updatedAt: now,
      ),
      DeviceType.feederLine: DeviceStatus(
        type: DeviceType.feederLine,
        isOn: false,
        mode: DeviceMode.automatic,
        runningMinutesToday: 58,
        updatedAt: now,
      ),
    };
  }

  List<PigHouseProfile> pigHouseProfiles() {
    final now = DateTime.now();
    return [
      PigHouseProfile(
        pigHouseId: 'A01',
        pigCount: 486,
        averageWeightKg: 73.8,
        todayFeedKg: 1280,
        feedMeatRatio: 2.42,
        estimatedMarketDate: now.add(const Duration(days: 36)),
        soldToday: 0,
        soldThisMonth: 128,
        immunityRecords: [
          ImmunityRecord(
            vaccine: '猪瘟疫苗',
            date: now.subtract(const Duration(days: 18)),
            operatorName: '李师傅',
            note: '全栏完成，抽检状态正常',
          ),
          ImmunityRecord(
            vaccine: '口蹄疫疫苗',
            date: now.subtract(const Duration(days: 35)),
            operatorName: '王工',
            note: '留观 24 小时无异常',
          ),
          ImmunityRecord(
            vaccine: '圆环病毒疫苗',
            date: now.subtract(const Duration(days: 57)),
            operatorName: '赵工',
            note: '批次 P2026-A01',
          ),
        ],
      ),
    ];
  }

  ReportData reportData() {
    return ReportData(
      temperatureCurve: _temperatureCurve(),
      humidityCurve: _curve(64, 9, 45, 86, unitStep: 1),
      lightCurve: _curve(220, 115, 80, 520, unitStep: 10),
      feedCurve: _curve(178, 38, 110, 245, unitStep: 5),
      ventilationHours: 7.8 + _random.nextDouble(),
      sprayHours: 1.9 + _random.nextDouble() * 0.6,
      feedCost: (4360 + _random.nextInt(260)).toDouble(),
      electricityCost: (386 + _random.nextInt(90)).toDouble(),
      medicineCost: (128 + _random.nextInt(40)).toDouble(),
    );
  }

  AiInsight normalAiInsight() {
    return AiInsight(
      updatedAt: DateTime.now(),
      findings: const [
        AiFinding(
          title: 'AI 看猪结果',
          value: '486 头在线识别',
          status: '活动水平正常',
          isAbnormal: false,
        ),
        AiFinding(
          title: '咳嗽异常识别',
          value: '0.8 次/分钟',
          status: '低风险',
          isAbnormal: false,
        ),
        AiFinding(
          title: '仔猪防压风险',
          value: '2 个观察点',
          status: '可控',
          isAbnormal: false,
        ),
        AiFinding(
          title: '异常聚集识别',
          value: '未发现',
          status: '正常分布',
          isAbnormal: false,
        ),
        AiFinding(
          title: '采食行为分析',
          value: '92% 正常采食',
          status: '趋势稳定',
          isAbnormal: false,
        ),
      ],
    );
  }

  AiInsight abnormalAiInsight() {
    return AiInsight(
      updatedAt: DateTime.now(),
      findings: const [
        AiFinding(
          title: 'AI 看猪结果',
          value: '486 头在线识别',
          status: '识别稳定',
          isAbnormal: false,
        ),
        AiFinding(
          title: '咳嗽异常识别',
          value: '8.6 次/分钟',
          status: '疑似呼吸道异常',
          isAbnormal: true,
        ),
        AiFinding(
          title: '仔猪防压风险',
          value: '5 个高风险点',
          status: '需要巡检',
          isAbnormal: true,
        ),
        AiFinding(
          title: '异常聚集识别',
          value: '东侧饮水区聚集',
          status: '疑似水嘴堵塞',
          isAbnormal: true,
        ),
        AiFinding(
          title: '采食行为分析',
          value: '采食下降 12%',
          status: '建议核查料线',
          isAbnormal: true,
        ),
      ],
    );
  }

  List<ChartPoint> _curve(
    double base,
    double amplitude,
    double min,
    double max, {
    required int unitStep,
  }) {
    const labels = ['00', '04', '08', '12', '16', '20', '24'];
    return List.generate(labels.length, (index) {
      final wave = sin(index / (labels.length - 1) * pi);
      final jitter = (_random.nextDouble() - 0.5) * amplitude * 0.3;
      final value =
          (base + wave * amplitude + jitter).clamp(min, max).toDouble();
      return ChartPoint(
        label: labels[index],
        value: ((value / unitStep).round() * unitStep).toDouble(),
      );
    });
  }

  List<ChartPoint> _temperatureCurve() {
    const labels = ['00', '04', '08', '12', '16', '20', '24'];
    return List.generate(labels.length, (index) {
      final wave = sin(index / (labels.length - 1) * 2 * pi - pi / 2);
      final jitter = (_random.nextDouble() - 0.5) * 0.16;
      final value = (25.0 + wave * 0.35 + jitter).clamp(24.6, 25.8);
      return ChartPoint(
        label: labels[index],
        value: (value * 10).round() / 10,
      );
    });
  }

  double _meanRevertingDrift(
    double value, {
    required double target,
    required double min,
    required double max,
    required double step,
    required double pull,
  }) {
    final randomStep = (_random.nextDouble() - 0.5) * step;
    final next = value + (target - value) * pull + randomStep;
    return next.clamp(min, max).toDouble();
  }

  double _drift(
    double value, {
    required double min,
    required double max,
    required double step,
  }) {
    final next = value + (_random.nextDouble() - 0.5) * step;
    return next.clamp(min, max).toDouble();
  }

  int _scoreEnvironment({
    required ThresholdSettings thresholds,
    required double temperature,
    required double humidity,
    required double ammonia,
    required double co2,
    required double light,
  }) {
    var score = 100;
    if (temperature > thresholds.temperatureHigh) {
      score -= ((temperature - thresholds.temperatureHigh) * 8).round();
    }
    if (temperature < thresholds.temperatureLow) {
      score -= ((thresholds.temperatureLow - temperature) * 8).round();
    }
    if (humidity > thresholds.humidityHigh) {
      score -= ((humidity - thresholds.humidityHigh) * 2).round();
    }
    if (humidity < thresholds.humidityLow) {
      score -= ((thresholds.humidityLow - humidity) * 2).round();
    }
    if (ammonia > thresholds.ammoniaHigh) {
      score -= ((ammonia - thresholds.ammoniaHigh) * 4).round();
    }
    if (co2 > thresholds.co2High) {
      score -= ((co2 - thresholds.co2High) / 40).round();
    }
    if (light < thresholds.illuminanceLow) {
      score -= ((thresholds.illuminanceLow - light) / 8).round();
    }
    return score.clamp(48, 96).toInt();
  }

  String _statusFromScore(int score) {
    if (score >= 90) {
      return '优';
    }
    if (score >= 80) {
      return '良好';
    }
    if (score >= 70) {
      return '需关注';
    }
    return '异常';
  }
}
