import '../models/ai_insight.dart';
import '../models/alarm_record.dart';
import '../models/device_status.dart';
import '../models/pig_house_profile.dart';
import '../models/report_data.dart';
import '../models/sensor_snapshot.dart';
import '../models/threshold_settings.dart';

abstract class DataSource {
  String get gatewayLabel;

  Future<SensorSnapshot> fetchLatestSensorSnapshot({
    required String pigHouseId,
    required ThresholdSettings thresholds,
  });

  Future<Map<DeviceType, DeviceStatus>> fetchDeviceStatuses();

  Future<void> saveDeviceStatus(DeviceStatus status);

  Future<ThresholdSettings> fetchThresholdSettings();

  Future<void> saveThresholdSettings(ThresholdSettings settings);

  Future<List<AlarmRecord>> fetchAlarmRecords();

  Future<void> saveAlarmRecords(List<AlarmRecord> records);

  Future<List<PigHouseProfile>> fetchPigHouses();

  Future<ReportData> fetchReportData();

  Future<AiInsight> fetchAiInsight();

  Future<void> saveAiInsight(AiInsight insight);

  Future<AiInsight> simulateAiAnomaly();
}
