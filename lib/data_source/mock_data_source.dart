import '../models/ai_insight.dart';
import '../models/alarm_record.dart';
import '../models/device_status.dart';
import '../models/pig_house_profile.dart';
import '../models/report_data.dart';
import '../models/sensor_snapshot.dart';
import '../models/threshold_settings.dart';
import '../services/simulation_service.dart';
import 'data_source.dart';

class MockDataSource implements DataSource {
  MockDataSource() : _simulation = SimulationService() {
    _deviceStatuses = _simulation.initialDeviceStatuses();
    _thresholdSettings = ThresholdSettings.defaults();
    _pigHouses = _simulation.pigHouseProfiles();
    _reportData = _simulation.reportData();
    _aiInsight = _simulation.normalAiInsight();
  }

  final SimulationService _simulation;
  late Map<DeviceType, DeviceStatus> _deviceStatuses;
  late ThresholdSettings _thresholdSettings;
  late List<PigHouseProfile> _pigHouses;
  late ReportData _reportData;
  late AiInsight _aiInsight;
  List<AlarmRecord> _alarmRecords = const [];

  @override
  String get gatewayLabel => 'PLC 网关：在线';

  @override
  Future<SensorSnapshot> fetchLatestSensorSnapshot({
    required String pigHouseId,
    required ThresholdSettings thresholds,
  }) async {
    await _tinyDelay();
    return _simulation.nextSensorSnapshot(
      pigHouseId: pigHouseId,
      thresholds: thresholds,
    );
  }

  @override
  Future<Map<DeviceType, DeviceStatus>> fetchDeviceStatuses() async {
    await _tinyDelay();
    return Map<DeviceType, DeviceStatus>.from(_deviceStatuses);
  }

  @override
  Future<void> saveDeviceStatus(DeviceStatus status) async {
    await _tinyDelay();
    _deviceStatuses[status.type] = status;
  }

  @override
  Future<ThresholdSettings> fetchThresholdSettings() async {
    await _tinyDelay();
    return _thresholdSettings;
  }

  @override
  Future<void> saveThresholdSettings(ThresholdSettings settings) async {
    await _tinyDelay();
    _thresholdSettings = settings;
  }

  @override
  Future<List<AlarmRecord>> fetchAlarmRecords() async {
    await _tinyDelay();
    return List<AlarmRecord>.from(_alarmRecords);
  }

  @override
  Future<void> saveAlarmRecords(List<AlarmRecord> records) async {
    await _tinyDelay();
    _alarmRecords = List<AlarmRecord>.from(records);
  }

  @override
  Future<List<PigHouseProfile>> fetchPigHouses() async {
    await _tinyDelay();
    return List<PigHouseProfile>.from(_pigHouses);
  }

  @override
  Future<ReportData> fetchReportData() async {
    await _tinyDelay();
    _reportData = _simulation.reportData();
    return _reportData;
  }

  @override
  Future<AiInsight> fetchAiInsight() async {
    await _tinyDelay();
    return _aiInsight;
  }

  @override
  Future<void> saveAiInsight(AiInsight insight) async {
    await _tinyDelay();
    _aiInsight = insight;
  }

  @override
  Future<AiInsight> simulateAiAnomaly() async {
    await _tinyDelay();
    _aiInsight = _simulation.abnormalAiInsight();
    return _aiInsight;
  }

  AiInsight abnormalAiInsight() {
    return _simulation.abnormalAiInsight();
  }

  Future<void> _tinyDelay() {
    return Future<void>.delayed(const Duration(milliseconds: 120));
  }
}
