import 'package:flutter/material.dart';

import '../models/pig_daily_stat.dart';
import 'app_theme.dart';
import 'status_badge.dart';

Color riskColor(RiskLevel level) {
  switch (level) {
    case RiskLevel.normal:
      return AppTheme.primary;
    case RiskLevel.watch:
      return AppTheme.warning;
    case RiskLevel.high:
      return AppTheme.danger;
  }
}

class RiskBadge extends StatelessWidget {
  const RiskBadge({
    super.key,
    required this.level,
  });

  final RiskLevel level;

  @override
  Widget build(BuildContext context) {
    return StatusBadge(
      label: level.label,
      color: riskColor(level),
      icon: switch (level) {
        RiskLevel.normal => Icons.check_circle_outline,
        RiskLevel.watch => Icons.visibility_outlined,
        RiskLevel.high => Icons.warning_amber_rounded,
      },
    );
  }
}
