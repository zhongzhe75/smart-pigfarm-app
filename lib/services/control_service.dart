import '../models/device_status.dart';
import '../models/operation_record.dart';
import '../models/user_role.dart';

class ControlResult {
  const ControlResult({
    required this.allowed,
    required this.message,
    this.status,
    this.record,
  });

  final bool allowed;
  final String message;
  final DeviceStatus? status;
  final OperationRecord? record;
}

class ControlService {
  ControlResult switchMode({
    required UserRole? role,
    required DeviceStatus status,
    required DeviceMode mode,
  }) {
    if (!hasPermission(role, Permission.remoteControl)) {
      return const ControlResult(
        allowed: false,
        message: '当前角色没有远程控制权限',
      );
    }
    final next = status.copyWith(
      mode: mode,
      updatedAt: DateTime.now(),
    );
    return ControlResult(
      allowed: true,
      message: '${status.type.label} 已切换为 ${mode.label}',
      status: next,
      record: _record(
        role: role!,
        deviceName: status.type.label,
        action: '切换为 ${mode.label}',
      ),
    );
  }

  ControlResult toggleDevice({
    required UserRole? role,
    required DeviceStatus status,
    required bool turnOn,
  }) {
    if (!hasPermission(role, Permission.remoteControl)) {
      return const ControlResult(
        allowed: false,
        message: '游客角色不能下发控制指令',
      );
    }
    if (status.mode != DeviceMode.manual) {
      return const ControlResult(
        allowed: false,
        message: '请先切换到手动模式',
      );
    }
    final next = status.copyWith(
      isOn: turnOn,
      updatedAt: DateTime.now(),
      runningMinutesToday:
          turnOn ? status.runningMinutesToday + 1 : status.runningMinutesToday,
    );
    return ControlResult(
      allowed: true,
      message: '${status.type.label} 已${turnOn ? '开启' : '关闭'}',
      status: next,
      record: _record(
        role: role!,
        deviceName: status.type.label,
        action: turnOn ? '远程开启' : '远程关闭',
      ),
    );
  }

  OperationRecord _record({
    required UserRole role,
    required String deviceName,
    required String action,
  }) {
    final now = DateTime.now();
    return OperationRecord(
      id: 'op-${now.millisecondsSinceEpoch}',
      time: now,
      roleName: role.title,
      deviceName: deviceName,
      action: action,
    );
  }
}
