import 'package:flutter/material.dart';

import '../models/threshold_settings.dart';
import '../models/user_role.dart';
import '../widgets/app_state_scope.dart';
import '../widgets/app_theme.dart';
import '../widgets/page_scaffold.dart';
import '../widgets/responsive_grid.dart';
import '../widgets/status_badge.dart';

class ThresholdSettingsPage extends StatelessWidget {
  const ThresholdSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = SmartPigfarmScope.watch(context);
    final settings = state.thresholdSettings;
    final canEdit = state.can(Permission.thresholdEdit);
    return PageScaffold(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.16)),
          ),
          child: Row(
            children: [
              const Icon(Icons.rule_outlined, color: AppTheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '猪舍 A01 环境阈值',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              StatusBadge(
                label: canEdit ? '可修改' : '只读',
                color: canEdit ? AppTheme.primary : AppTheme.warning,
                icon: canEdit ? Icons.edit_outlined : Icons.visibility_outlined,
              ),
            ],
          ),
        ),
        ResponsiveGrid(
          minItemWidth: 360,
          maxColumns: 2,
          childAspectRatio: 3.2,
          children: [
            _ThresholdSlider(
              title: '温度上限',
              value: settings.temperatureHigh,
              min: 24,
              max: 38,
              unit: '℃',
              enabled: canEdit,
              onChanged: (value) =>
                  _save(context, settings.copyWith(temperatureHigh: value)),
            ),
            _ThresholdSlider(
              title: '温度下限',
              value: settings.temperatureLow,
              min: 10,
              max: 24,
              unit: '℃',
              enabled: canEdit,
              onChanged: (value) =>
                  _save(context, settings.copyWith(temperatureLow: value)),
            ),
            _ThresholdSlider(
              title: '湿度上限',
              value: settings.humidityHigh,
              min: 65,
              max: 95,
              unit: '%',
              enabled: canEdit,
              onChanged: (value) =>
                  _save(context, settings.copyWith(humidityHigh: value)),
            ),
            _ThresholdSlider(
              title: '湿度下限',
              value: settings.humidityLow,
              min: 30,
              max: 65,
              unit: '%',
              enabled: canEdit,
              onChanged: (value) =>
                  _save(context, settings.copyWith(humidityLow: value)),
            ),
            _ThresholdSlider(
              title: '氨气上限',
              value: settings.ammoniaHigh,
              min: 10,
              max: 50,
              unit: 'ppm',
              enabled: canEdit,
              onChanged: (value) =>
                  _save(context, settings.copyWith(ammoniaHigh: value)),
            ),
            _ThresholdSlider(
              title: 'CO₂ 上限',
              value: settings.co2High,
              min: 900,
              max: 4200,
              unit: 'ppm',
              enabled: canEdit,
              onChanged: (value) =>
                  _save(context, settings.copyWith(co2High: value)),
            ),
            _ThresholdSlider(
              title: '光照下限',
              value: settings.illuminanceLow,
              min: 20,
              max: 360,
              unit: 'lx',
              enabled: canEdit,
              onChanged: (value) =>
                  _save(context, settings.copyWith(illuminanceLow: value)),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _save(BuildContext context, ThresholdSettings settings) async {
    final messenger = ScaffoldMessenger.of(context);
    final message =
        await SmartPigfarmScope.read(context).updateThresholds(settings);
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ThresholdSlider extends StatelessWidget {
  const _ThresholdSlider({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    required this.enabled,
    required this.onChanged,
  });

  final String title;
  final double value;
  final double min;
  final double max;
  final String unit;
  final bool enabled;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled
          ? null
          : () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('当前角色仅可查看阈值配置')),
              );
            },
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  Text(
                    '${value.toStringAsFixed(value >= 100 ? 0 : 1)} $unit',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ],
              ),
              Slider(
                value: value.clamp(min, max).toDouble(),
                min: min,
                max: max,
                divisions: 20,
                label: '${value.toStringAsFixed(1)} $unit',
                onChanged: enabled ? onChanged : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
