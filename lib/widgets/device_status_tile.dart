import 'package:flutter/material.dart';

import '../models/device_status.dart';
import '../services/formatters.dart';
import 'app_theme.dart';
import 'status_badge.dart';

IconData deviceIcon(DeviceType type) {
  switch (type) {
    case DeviceType.fan:
      return Icons.air;
    case DeviceType.sprayPump:
      return Icons.water_drop_outlined;
    case DeviceType.heater:
      return Icons.local_fire_department_outlined;
    case DeviceType.ledLight:
      return Icons.light_mode_outlined;
    case DeviceType.feederLine:
      return Icons.inventory_2_outlined;
  }
}

class DeviceStatusTile extends StatelessWidget {
  const DeviceStatusTile({
    super.key,
    required this.status,
    this.trailing,
  });

  final DeviceStatus status;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final accent = status.isOn ? AppTheme.primary : AppTheme.textMuted;
    final hours = status.runningMinutesToday ~/ 60;
    final minutes = status.runningMinutesToday % 60;
    final runTime =
        '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:00';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(deviceIcon(status.type), color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          status.type.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                      ),
                      StatusBadge(
                        label: status.isOn ? '运行中' : '已停止',
                        color: status.isOn
                            ? AppTheme.primary
                            : const Color(0xFF8EA39B),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${status.mode.label} · 运行时长 $runTime',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '更新 ${formatClock(status.updatedAt)}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: const Color(0xFF647D75),
                        ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
