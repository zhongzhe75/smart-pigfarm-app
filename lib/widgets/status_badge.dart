import 'package:flutter/material.dart';

import '../models/alarm_record.dart';
import 'app_theme.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    this.color = AppTheme.primary,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  factory StatusBadge.alarmLevel(AlarmLevel level) {
    switch (level) {
      case AlarmLevel.info:
        return StatusBadge(
          label: level.label,
          color: AppTheme.secondary,
          icon: Icons.info_outline,
        );
      case AlarmLevel.warning:
        return StatusBadge(
          label: level.label,
          color: AppTheme.warning,
          icon: Icons.warning_amber_rounded,
        );
      case AlarmLevel.critical:
        return StatusBadge(
          label: level.label,
          color: AppTheme.danger,
          icon: Icons.report_problem_outlined,
        );
    }
  }

  factory StatusBadge.alarmStatus(AlarmStatus status) {
    return StatusBadge(
      label: status.label,
      color:
          status == AlarmStatus.handled ? AppTheme.primary : AppTheme.warning,
      icon: status == AlarmStatus.handled
          ? Icons.task_alt
          : Icons.pending_actions,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        border: Border.all(color: color.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
