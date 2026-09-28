import '../models/ai_insight.dart';
import '../models/alarm_record.dart';
import '../models/device_status.dart';
import '../models/pig_house_profile.dart';
import '../models/report_data.dart';
import '../models/sensor_snapshot.dart';
import '../models/threshold_settings.dart';
import 'data_source.dart';

class ApiDataSource implements DataSource {
  ApiDataSource({
    required this.baseUrl,
    this.token,
  });

  final String baseUrl;
  final String? token;

  @override
  String get gatewayLabel => 'PLC 网关：API 预留';

  @override
  Future<SensorSnapshot> fetchLatestSensorSnapshot({
    required String pigHouseId,
    required ThresholdSettings thresholds,
  }) {
    throw UnimplementedError('TODO: 接入 PLC 网关传感器接口 $baseUrl');
  }

  @override
  Future<Map<DeviceType, DeviceStatus>> fetchDeviceStatuses() {
    throw UnimplementedError('TODO: 接入 PLC 网关设备状态接口 $baseUrl');
  }

  @override
  Future<void> saveDeviceStatus(DeviceStatus status) {
    throw UnimplementedError('TODO: 下发 PLC 控制指令 $baseUrl');
  }

  @override
  Future<ThresholdSettings> fetchThresholdSettings() {
    throw UnimplementedError('TODO: 获取 PLC 网关阈值配置 $baseUrl');
  }

  @override
  Future<void> saveThresholdSettings(ThresholdSettings settings) {
    throw UnimplementedError('TODO: 保存阈值到 PLC 网关 $baseUrl');
  }

  @override
  Future<List<AlarmRecord>> fetchAlarmRecords() {
    throw UnimplementedError('TODO: 获取网关或平台告警记录 $baseUrl');
  }

  @override
  Future<void> saveAlarmRecords(List<AlarmRecord> records) {
    throw UnimplementedError('TODO: 同步告警处理状态 $baseUrl');
  }

  @override
  Future<List<PigHouseProfile>> fetchPigHouses() {
    throw UnimplementedError('TODO: 获取猪群档案 $baseUrl');
  }

  @override
  Future<ReportData> fetchReportData() {
    throw UnimplementedError('TODO: 获取历史报表数据 $baseUrl');
  }

  @override
  Future<AiInsight> fetchAiInsight() {
    throw UnimplementedError('TODO: 获取视频 AI 分析结果 $baseUrl');
  }

  @override
  Future<void> saveAiInsight(AiInsight insight) {
    throw UnimplementedError('TODO: 同步 AI 分析结果 $baseUrl');
  }

  @override
  Future<AiInsight> simulateAiAnomaly() {
    throw UnimplementedError('TODO: 触发或读取 AI 异常事件 $baseUrl');
  }
}
