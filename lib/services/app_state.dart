import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data_source/data_source.dart';
import '../models/ai_insight.dart';
import '../models/alarm_record.dart';
import '../models/device_status.dart';
import '../models/operation_record.dart';
import '../models/pig_house_profile.dart';
import '../models/report_data.dart';
import '../models/sensor_snapshot.dart';
import '../models/threshold_settings.dart';
import '../models/user_role.dart';
import 'alarm_service.dart';
import 'control_service.dart';

class AppState extends ChangeNotifier {
  AppState({
    required this.dataSource,
    this.enableRealtimeLoop = true,
    AlarmService? alarmService,
    ControlService? controlService,
  })  : _alarmService = alarmService ?? AlarmService(),
        _controlService = controlService ?? ControlService();

  final DataSource dataSource;
  final bool enableRealtimeLoop;
  final AlarmService _alarmService;
  final ControlService _controlService;

  static const String activePigHouseId = 'A01';

  Timer? _timer;
  bool _refreshing = false;
  bool _initialized = false;
  UserRole? _currentRole;
  SensorSnapshot? _sensorSnapshot;
  ThresholdSettings _thresholdSettings = ThresholdSettings.defaults();
  Map<DeviceType, DeviceStatus> _deviceStatuses = {};
  List<AlarmRecord> _alarmRecords = [];
  List<PigHouseProfile> _pigHouses = [];
  ReportData? _reportData;
  AiInsight? _aiInsight;
  final List<OperationRecord> _operationRecords = [];

  bool get initialized => _initialized;

  UserRole? get currentRole => _currentRole;

  SensorSnapshot? get sensorSnapshot => _sensorSnapshot;

  ThresholdSettings get thresholdSettings => _thresholdSettings;

  Map<DeviceType, DeviceStatus> get deviceStatuses {
    return Map<DeviceType, DeviceStatus>.unmodifiable(_deviceStatuses);
  }

  List<AlarmRecord> get alarmRecords =>
      List<AlarmRecord>.unmodifiable(_alarmRecords);

  List<PigHouseProfile> get pigHouses =>
      List<PigHouseProfile>.unmodifiable(_pigHouses);

  ReportData? get reportData => _reportData;

  AiInsight? get aiInsight => _aiInsight;

  List<OperationRecord> get operationRecords {
    return List<OperationRecord>.unmodifiable(_operationRecords);
  }

  String get gatewayLabel => dataSource.gatewayLabel;

  DeviceMode get controlMode {
    if (_deviceStatuses.isEmpty) {
      return DeviceMode.automatic;
    }
    return _deviceStatuses.values
            .every((status) => status.mode == DeviceMode.manual)
        ? DeviceMode.manual
        : DeviceMode.automatic;
  }

  int get todayAlarmCount {
    final now = DateTime.now();
    return _alarmRecords.where((record) {
      return record.time.year == now.year &&
          record.time.month == now.month &&
          record.time.day == now.day;
    }).length;
  }

  int get unhandledAlarmCount {
    return _alarmRecords
        .where((record) => record.status == AlarmStatus.unhandled)
        .length;
  }

  int get totalPigCount {
    return _pigHouses.fold<int>(0, (sum, item) => sum + item.pigCount);
  }

  double get todayFeedKg {
    return _pigHouses.fold<double>(0, (sum, item) => sum + item.todayFeedKg);
  }

  Future<void> initialize() async {
    _thresholdSettings = await dataSource.fetchThresholdSettings();
    _deviceStatuses = await dataSource.fetchDeviceStatuses();
    _alarmRecords = await dataSource.fetchAlarmRecords();
    _pigHouses = await dataSource.fetchPigHouses();
    _reportData = await dataSource.fetchReportData();
    _aiInsight = await dataSource.fetchAiInsight();
    await _refreshSensorSnapshot();
    _operationRecords.add(OperationRecord(
      id: 'op-init-${DateTime.now().millisecondsSinceEpoch}',
      time: DateTime.now(),
      roleName: '系统',
      deviceName: 'PLC 网关',
      action: '网关在线，数据链路正常',
    ));
    _initialized = true;
    if (enableRealtimeLoop) {
      _startRealtimeLoop();
    }
    notifyListeners();
  }

  void login(UserRole role) {
    _currentRole = role;
    notifyListeners();
  }

  void logout() {
    _currentRole = null;
    notifyListeners();
  }

  bool can(Permission permission) => hasPermission(_currentRole, permission);

  Future<String> setGlobalControlMode(DeviceMode mode) async {
    if (!can(Permission.remoteControl)) {
      return '当前角色没有远程控制权限';
    }
    final nextMap = <DeviceType, DeviceStatus>{};
    for (final entry in _deviceStatuses.entries) {
      final next = entry.value.copyWith(
        mode: mode,
        updatedAt: DateTime.now(),
      );
      nextMap[entry.key] = next;
      await dataSource.saveDeviceStatus(next);
    }
    _deviceStatuses = nextMap;
    _addOperation(
      deviceName: '全场设备',
      action: '切换为 ${mode.label}',
    );
    notifyListeners();
    return '已切换为 ${mode.label}';
  }

  Future<String> toggleDevice(DeviceType type, bool turnOn) async {
    final status = _deviceStatuses[type];
    if (status == null) {
      return '设备状态不存在';
    }
    final result = _controlService.toggleDevice(
      role: _currentRole,
      status: status,
      turnOn: turnOn,
    );
    if (!result.allowed || result.status == null) {
      return result.message;
    }
    _deviceStatuses[type] = result.status!;
    await dataSource.saveDeviceStatus(result.status!);
    if (result.record != null) {
      _operationRecords.insert(0, result.record!);
    }
    _trimOperationRecords();
    notifyListeners();
    return result.message;
  }

  Future<String> updateThresholds(ThresholdSettings settings) async {
    if (!can(Permission.thresholdEdit)) {
      return '仅场长管理员可以修改阈值';
    }
    _thresholdSettings = settings;
    await dataSource.saveThresholdSettings(settings);
    _addOperation(
      deviceName: '阈值配置',
      action: '更新环境阈值',
    );
    await _refreshSensorSnapshot();
    notifyListeners();
    return '阈值已保存';
  }

  Future<String> markAlarmHandled(String alarmId) async {
    if (!can(Permission.alarmHandle)) {
      return '当前角色没有告警处理权限';
    }
    _alarmRecords = _alarmRecords.map((record) {
      if (record.id == alarmId) {
        return record.copyWith(status: AlarmStatus.handled);
      }
      return record;
    }).toList();
    await dataSource.saveAlarmRecords(_alarmRecords);
    _addOperation(
      deviceName: '告警中心',
      action: '确认告警 $alarmId',
    );
    notifyListeners();
    return '告警已标记为已处理';
  }

  Future<String> simulateAlarm() async {
    if (!can(Permission.alarmSimulate)) {
      return '当前角色不能生成告警事件';
    }
    final record = _alarmService.createAlarmTestRecord(activePigHouseId);
    _alarmRecords.insert(0, record);
    await dataSource.saveAlarmRecords(_alarmRecords);
    _addOperation(
      deviceName: '告警中心',
      action: '生成告警联动事件',
    );
    notifyListeners();
    return '已生成告警事件';
  }

  Future<String> simulateAiException() async {
    if (!can(Permission.alarmSimulate)) {
      return '当前角色不能触发 AI 异常识别';
    }
    _aiInsight = await dataSource.simulateAiAnomaly();
    final record = _alarmService.simulateAiAlarm(activePigHouseId);
    _alarmRecords.insert(0, record);
    await dataSource.saveAlarmRecords(_alarmRecords);
    await dataSource.saveAiInsight(_aiInsight!);
    _addOperation(
      deviceName: '视频 AI',
      action: '触发 AI 异常识别',
    );
    notifyListeners();
    return 'AI 异常已写入告警记录';
  }

  Future<void> refreshReportData() async {
    _reportData = await dataSource.fetchReportData();
    notifyListeners();
  }

  void _startRealtimeLoop() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      _refreshSensorSnapshot();
    });
  }

  Future<void> _refreshSensorSnapshot() async {
    if (_refreshing) {
      return;
    }
    _refreshing = true;
    try {
      _sensorSnapshot = await dataSource.fetchLatestSensorSnapshot(
        pigHouseId: activePigHouseId,
        thresholds: _thresholdSettings,
      );
      final generated = _alarmService.evaluateEnvironment(
        snapshot: _sensorSnapshot!,
        thresholds: _thresholdSettings,
      );
      final accepted = generated.where(_shouldStoreEnvironmentAlarm).toList();
      if (accepted.isNotEmpty) {
        _alarmRecords.insertAll(0, accepted);
        await dataSource.saveAlarmRecords(_alarmRecords);
      }
      notifyListeners();
    } finally {
      _refreshing = false;
    }
  }

  bool _shouldStoreEnvironmentAlarm(AlarmRecord candidate) {
    return !_alarmRecords.any((record) {
      final isSameKind = record.type == candidate.type &&
          record.message == candidate.message &&
          record.status == AlarmStatus.unhandled;
      final deltaSeconds =
          candidate.time.difference(record.time).inSeconds.abs();
      final isRecent = deltaSeconds < const Duration(minutes: 2).inSeconds;
      return isSameKind && isRecent;
    });
  }

  void _addOperation({
    required String deviceName,
    required String action,
  }) {
    final now = DateTime.now();
    _operationRecords.insert(
        0,
        OperationRecord(
          id: 'op-${now.millisecondsSinceEpoch}',
          time: now,
          roleName: _currentRole?.title ?? '系统',
          deviceName: deviceName,
          action: action,
        ));
    _trimOperationRecords();
  }

  void _trimOperationRecords() {
    if (_operationRecords.length > 60) {
      _operationRecords.removeRange(60, _operationRecords.length);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
