import 'package:flutter/material.dart';

import '../models/device_status.dart';
import '../models/sensor_snapshot.dart';
import '../services/formatters.dart';
import '../widgets/app_state_scope.dart';
import '../widgets/app_surface_card.dart';
import '../widgets/app_theme.dart';
import '../widgets/device_status_tile.dart';
import '../widgets/line_chart_card.dart';
import '../widgets/metric_card.dart';
import '../widgets/page_scaffold.dart';
import '../widgets/responsive_grid.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/section_header.dart';
import '../widgets/status_badge.dart';

class RealtimeMonitorPage extends StatelessWidget {
  const RealtimeMonitorPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = SmartPigfarmScope.watch(context);
    final snapshot = state.sensorSnapshot;
    if (snapshot == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final report = state.reportData;
    return PageScaffold(
      children: [
        AppSurfaceCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.hub_outlined,
                    color: AppTheme.primary, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('环境数据 · 演示采样',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 3),
                    Text(
                      '本地数据刷新 · 2秒 · ${formatDateTime(snapshot.collectedAt)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              StatusBadge(
                label: snapshot.environmentStatus,
                color: snapshot.environmentScore >= 80
                    ? AppTheme.primary
                    : AppTheme.warning,
                icon: Icons.eco_outlined,
              ),
            ],
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final metrics = _EnvironmentMetrics(snapshot: snapshot);
            final trends = report == null
                ? const AppSurfaceCard(
                    child: Center(child: CircularProgressIndicator()),
                  )
                : Column(
                    children: [
                      LineChartCard(
                        title: '温度趋势',
                        unit: '℃',
                        points: report.temperatureCurve,
                        color: AppTheme.warning,
                      ),
                      const SizedBox(height: 16),
                      LineChartCard(
                        title: '湿度趋势',
                        unit: '%',
                        points: report.humidityCurve,
                        color: AppTheme.secondary,
                      ),
                    ],
                  );
            if (constraints.maxWidth < AppBreakpoints.tablet) {
              return Column(
                children: [metrics, const SizedBox(height: 20), trends],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 4, child: metrics),
                const SizedBox(width: 20),
                Expanded(flex: 6, child: trends),
              ],
            );
          },
        ),
        const SectionHeader(
          title: '设备实时状态',
          subtitle: '状态优先展示，设备控制请前往设备控制终端',
        ),
        ResponsiveGrid(
          minItemWidth: 340,
          childAspectRatio: 3.6,
          maxColumns: 2,
          children: DeviceType.values.map((type) {
            final status = state.deviceStatuses[type];
            return status == null
                ? const SizedBox.shrink()
                : DeviceStatusTile(status: status);
          }).toList(growable: false),
        ),
      ],
    );
  }
}

class _EnvironmentMetrics extends StatelessWidget {
  const _EnvironmentMetrics({required this.snapshot});

  final SensorSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final state = SmartPigfarmScope.watch(context);
    final thresholds = state.thresholdSettings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: '当前环境指标',
          subtitle: '正常状态使用中性色，异常时强化提示',
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 650 ? 3 : 2;
            final itemWidth =
                (constraints.maxWidth - (columns - 1) * 12) / columns;
            return GridView.count(
              crossAxisCount: columns,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: itemWidth / 132,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                MetricCard(
                  title: '温度',
                  value: snapshot.temperature.toStringAsFixed(1),
                  unit: '℃',
                  icon: Icons.thermostat_outlined,
                  caption:
                      '上限 ${thresholds.temperatureHigh.toStringAsFixed(1)} ℃',
                ),
                MetricCard(
                  title: '湿度',
                  value: snapshot.humidity.toStringAsFixed(0),
                  unit: '%',
                  icon: Icons.water_drop_outlined,
                  caption:
                      '${thresholds.humidityLow.toStringAsFixed(0)}–${thresholds.humidityHigh.toStringAsFixed(0)} %',
                ),
                MetricCard(
                  title: '氨气',
                  value: snapshot.ammonia.toStringAsFixed(1),
                  unit: 'ppm',
                  icon: Icons.science_outlined,
                  caption:
                      '上限 ${thresholds.ammoniaHigh.toStringAsFixed(1)} ppm',
                ),
                MetricCard(
                  title: 'CO₂',
                  value: snapshot.co2.toStringAsFixed(0),
                  unit: 'ppm',
                  icon: Icons.cloud_outlined,
                  caption: '上限 ${thresholds.co2High.toStringAsFixed(0)} ppm',
                ),
                MetricCard(
                  title: '光照',
                  value: snapshot.illuminance.toStringAsFixed(0),
                  unit: 'lx',
                  icon: Icons.light_mode_outlined,
                  caption:
                      '下限 ${thresholds.illuminanceLow.toStringAsFixed(0)} lx',
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
