import 'package:flutter/material.dart';

import '../models/device_status.dart';
import '../models/user_role.dart';
import '../services/formatters.dart';
import '../widgets/app_state_scope.dart';
import '../widgets/app_theme.dart';
import '../widgets/device_status_tile.dart';
import '../widgets/page_scaffold.dart';
import '../widgets/responsive_grid.dart';
import '../widgets/section_header.dart';
import '../widgets/status_badge.dart';

class RemoteControlPage extends StatelessWidget {
  const RemoteControlPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = SmartPigfarmScope.watch(context);
    final canControl = state.can(Permission.remoteControl);
    final mode = state.controlMode;
    return PageScaffold(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            border: Border.all(
              color: canControl
                  ? AppTheme.primary.withValues(alpha: 0.18)
                  : AppTheme.warning.withValues(alpha: 0.24),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.settings_remote_outlined,
                      color: AppTheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '控制演示模式',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                  StatusBadge(
                    label: canControl ? '可演示操作' : '只读演示',
                    color: canControl ? AppTheme.primary : AppTheme.warning,
                    icon: canControl
                        ? Icons.lock_open_outlined
                        : Icons.lock_outline,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '当前操作用于软件控制流程演示，现场 PLC 通信接口待接入。',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              SegmentedButton<DeviceMode>(
                selected: {mode},
                onSelectionChanged: (selected) =>
                    _setMode(context, selected.first),
                segments: const [
                  ButtonSegment(
                    value: DeviceMode.automatic,
                    label: Text('自动'),
                    icon: Icon(Icons.sync_outlined),
                  ),
                  ButtonSegment(
                    value: DeviceMode.manual,
                    label: Text('手动'),
                    icon: Icon(Icons.touch_app_outlined),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                mode == DeviceMode.manual
                    ? '手动模式可演示风机、喷雾泵、加热风扇、补光和喂料线的软件状态切换。'
                    : '自动模式用于演示设备联动流程，手动开关暂不可用。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF9CB5AD),
                      height: 1.45,
                    ),
              ),
            ],
          ),
        ),
        const SectionHeader(
          title: '设备状态与控制',
          subtitle: '软件状态演示 · 现场通信接口待接入',
        ),
        ResponsiveGrid(
          minItemWidth: 360,
          maxColumns: 2,
          childAspectRatio: 3.25,
          children: DeviceType.values.map((type) {
            final status = state.deviceStatuses[type];
            if (status == null) return const SizedBox.shrink();
            return DeviceStatusTile(
              status: status,
              trailing: Switch(
                value: status.isOn,
                onChanged: (value) => _toggle(context, type, value),
              ),
            );
          }).toList(growable: false),
        ),
        _OperationLog(),
      ],
    );
  }

  Future<void> _setMode(BuildContext context, DeviceMode mode) async {
    final messenger = ScaffoldMessenger.of(context);
    final message =
        await SmartPigfarmScope.read(context).setGlobalControlMode(mode);
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggle(
      BuildContext context, DeviceType type, bool value) async {
    final messenger = ScaffoldMessenger.of(context);
    final message =
        await SmartPigfarmScope.read(context).toggleDevice(type, value);
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}

class _OperationLog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = SmartPigfarmScope.watch(context);
    final records = state.operationRecords.take(8).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '操作记录',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 10),
        if (records.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text('暂无操作记录'),
            ),
          )
        else
          ...records.map((record) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.history,
                          color: AppTheme.secondary, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _recordTitle(record.deviceName, record.action),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${record.roleName} · ${formatDateTime(record.time)}',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: const Color(0xFF8EA39B),
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  String _recordTitle(String deviceName, String action) {
    if (deviceName == 'PLC 网关') {
      return '控制接口 · 现场通信待接入';
    }
    return '$deviceName · $action';
  }
}
