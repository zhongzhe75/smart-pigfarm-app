import 'package:flutter/material.dart';

import '../camera/camera_config.dart';
import '../camera/camera_config_loader.dart';
import '../camera/camera_runtime_status.dart';
import '../camera/camera_status.dart';
import '../config/runtime_mode.dart';
import '../models/ai_behavior_record.dart';
import '../models/device_status.dart';
import '../models/health_alert.dart';
import '../models/herd_daily_aggregate.dart';
import '../models/pig_daily_stat.dart';
import '../models/pig_summary.dart';
import '../models/sensor_snapshot.dart';
import '../repositories/pig_repository.dart';
import '../repositories/repository_bundle.dart';
import '../services/app_state.dart';
import '../services/formatters.dart';
import '../widgets/app_state_scope.dart';
import '../widgets/app_surface_card.dart';
import '../widgets/app_theme.dart';
import '../widgets/async_state_panel.dart';
import '../widgets/device_status_tile.dart';
import '../widgets/metric_card.dart';
import '../widgets/page_scaffold.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/repository_scope.dart';
import '../widgets/risk_badge.dart';
import '../widgets/section_header.dart';
import '../widgets/status_badge.dart';
import 'pig_detail_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late final Future<CameraConfig> _cameraConfig;
  RepositoryBundle? _repositories;
  HerdDailyAggregate? _herdSummary;
  List<PigSummary> _priorityPigs = const [];
  Map<String, HealthAlert> _latestAlertByPig = const {};
  Object? _healthError;
  bool _healthLoading = true;
  int _todayBehaviorCount = 0;

  @override
  void initState() {
    super.initState();
    _cameraConfig = const CameraConfigLoader().load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repositories = RepositoryScope.read(context);
    if (!identical(_repositories, repositories)) {
      _repositories = repositories;
      _loadHealthOverview();
    }
  }

  Future<void> _loadHealthOverview() async {
    setState(() {
      _healthLoading = true;
      _healthError = null;
    });
    try {
      final results = await Future.wait<Object?>([
        _repositories!.pigMetrics.getLatestHerdAggregate(),
        _repositories!.pigs.queryPigSummaries(
          sort: PigSummarySort.healthScoreAscending,
          limit: 8,
        ),
        _repositories!.healthAlerts.queryAlerts(
          status: HealthAlertStatus.open,
          limit: 500,
        ),
        _repositories!.aiBehavior.queryBehaviorRecords(),
      ]);
      if (!mounted) return;
      final pigs = (results[1]! as List<PigSummary>)
          .where((pig) => pig.latestStat?.riskLevel != RiskLevel.normal)
          .take(5)
          .toList(growable: false);
      final alerts = results[2]! as List<HealthAlert>;
      final aggregate = results[0] as HerdDailyAggregate?;
      final behaviors = results[3]! as List<AiBehaviorRecord>;
      final latestAlertByPig = <String, HealthAlert>{};
      for (final alert in alerts) {
        latestAlertByPig.putIfAbsent(alert.pigId, () => alert);
      }
      setState(() {
        _herdSummary = results[0] as HerdDailyAggregate?;
        _priorityPigs = pigs;
        _latestAlertByPig = latestAlertByPig;
        _todayBehaviorCount = aggregate == null
            ? 0
            : behaviors.where((item) {
                return item.pigHouseId == AppState.activePigHouseId &&
                    item.occurredAt.year == aggregate.date.year &&
                    item.occurredAt.month == aggregate.date.month &&
                    item.occurredAt.day == aggregate.date.day;
              }).length;
        _healthLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _healthError = error;
        _healthLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = SmartPigfarmScope.watch(context);
    final snapshot = state.sensorSnapshot;
    if (snapshot == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return PageScaffold(
      children: [
        _HeroPanel(
          summary: _herdSummary,
          status: snapshot.environmentStatus,
          updatedAt: snapshot.collectedAt,
          todayAlarmCount: state.todayAlarmCount,
          pigHouseId: AppState.activePigHouseId,
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 700 ? 4 : 2;
            final itemWidth =
                (constraints.maxWidth - (columns - 1) * 16) / columns;
            return GridView.count(
              crossAxisCount: columns,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: itemWidth / 132,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                MetricCard(
                  title: '当前存栏',
                  value: _herdSummary?.pigCount.toString() ?? '--',
                  unit: '头',
                  icon: Icons.agriculture_outlined,
                  accent: AppTheme.primary,
                  caption: '全场 · A01 / A02 / A03',
                ),
                MetricCard(
                  title: '平均健康分',
                  value: _herdSummary?.averageHealthScore.toStringAsFixed(1) ??
                      '--',
                  unit: '分',
                  icon: Icons.favorite_outline,
                  accent: AppTheme.secondary,
                  caption: '基于个体历史数据规则',
                ),
                MetricCard(
                  title: '重点关注',
                  value:
                      '${(_herdSummary?.watchCount ?? 0) + (_herdSummary?.highRiskCount ?? 0)}',
                  unit: '头',
                  icon: Icons.visibility_outlined,
                  accent: AppTheme.warning,
                  caption: '高风险 ${_herdSummary?.highRiskCount ?? 0} 头',
                ),
                MetricCard(
                  title: '今日告警',
                  value: state.todayAlarmCount.toString(),
                  unit: '条',
                  icon: Icons.notifications_active_outlined,
                  accent: state.unhandledAlarmCount > 0
                      ? AppTheme.warning
                      : AppTheme.primary,
                  caption: '未处理 ${state.unhandledAlarmCount} 条',
                ),
              ],
            );
          },
        ),
        _DashboardPair(
          left: _DashboardSection(
            title: 'A01 环境状态',
            subtitle: '环境数据 · 演示采样',
            child: _SensorGrid(snapshot: snapshot),
          ),
          right: _HerdHealthSection(
            summary: _herdSummary,
            priorityPigs: _priorityPigs,
            latestAlertByPig: _latestAlertByPig,
            isLoading: _healthLoading,
            error: _healthError,
            onRetry: _loadHealthOverview,
          ),
        ),
        _DashboardPair(
          left: _VideoMonitorSummary(
            config: _cameraConfig,
            behaviorCount: _todayBehaviorCount,
            attentionCount: (_herdSummary?.watchCount ?? 0) +
                (_herdSummary?.highRiskCount ?? 0),
          ),
          right: _DeviceOverview(statuses: state.deviceStatuses),
        ),
        _QuickEntryGrid(),
      ],
    );
  }
}

class _DashboardPair extends StatelessWidget {
  const _DashboardPair({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < AppBreakpoints.tablet) {
          return Column(
            children: [left, const SizedBox(height: 16), right],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: 16),
            Expanded(child: right),
          ],
        );
      },
    );
  }
}

class _DashboardSection extends StatelessWidget {
  const _DashboardSection({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: title, subtitle: subtitle),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _VideoMonitorSummary extends StatelessWidget {
  const _VideoMonitorSummary({
    required this.config,
    required this.behaviorCount,
    required this.attentionCount,
  });

  final Future<CameraConfig> config;
  final int behaviorCount;
  final int attentionCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('dashboard-camera-summary'),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => Navigator.of(context).pushNamed('/video-ai'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppTheme.secondary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.videocam_outlined,
                  color: AppTheme.secondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '视频监控',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '今日行为异常 $behaviorCount · 重点关注 $attentionCount',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFFA7BDB5),
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FutureBuilder<CameraConfig>(
                future: config,
                builder: (context, snapshot) {
                  return ValueListenableBuilder<CameraStatus?>(
                    valueListenable: CameraRuntimeStatus.current,
                    builder: (context, runtimeStatus, _) {
                      final cameraConfig = snapshot.data;
                      final (label, color) = _summaryStatus(
                        cameraConfig,
                        runtimeStatus,
                      );
                      return StatusBadge(label: label, color: color);
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  (String, Color) _summaryStatus(
    CameraConfig? config,
    CameraStatus? runtimeStatus,
  ) {
    if (RuntimeConfig.current.usesLocalVideo) {
      return ('本地监控视频', AppTheme.secondary);
    }
    if (config == null) return ('检测中', AppTheme.secondary);
    if (!config.platformSupported) return ('本地监控视频', AppTheme.secondary);
    if (!config.configured) return ('待配置', AppTheme.warning);
    if (runtimeStatus == CameraStatus.playing) {
      return ('在线', AppTheme.primary);
    }
    if (runtimeStatus == CameraStatus.offline) {
      return ('离线', AppTheme.danger);
    }
    return ('待连接', AppTheme.secondary);
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.summary,
    required this.status,
    required this.updatedAt,
    required this.todayAlarmCount,
    required this.pigHouseId,
  });

  final HerdDailyAggregate? summary;
  final String status;
  final DateTime updatedAt;
  final int todayAlarmCount;
  final String pigHouseId;

  @override
  Widget build(BuildContext context) {
    final stateColor = status == '正常' ? AppTheme.primary : AppTheme.warning;
    final items = [
      _HeroFact(label: '环境状态', value: status, color: stateColor),
      _HeroFact(
        label: '重点关注',
        value: '${summary?.watchCount ?? 0} 头',
        color: AppTheme.warning,
      ),
      _HeroFact(label: '今日告警', value: '$todayAlarmCount 条'),
      _HeroFact(label: '环境区域', value: pigHouseId),
    ];
    return AppSurfaceCard(
      key: const Key('dashboard-overview-strip'),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child: Text('全场概览',
                      style: Theme.of(context).textTheme.titleLarge)),
              StatusBadge(
                label: '环境 $status',
                color: stateColor,
                icon: Icons.eco_outlined,
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < AppBreakpoints.phone) {
                final width = (constraints.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: items
                      .map((item) => SizedBox(width: width, child: item))
                      .toList(growable: false),
                );
              }
              return Row(
                children: items
                    .map((item) => Expanded(child: item))
                    .toList(growable: false),
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            '设备控制接口待接入 · 更新 ${formatClock(updatedAt)}',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppTheme.textMuted,
                ),
          ),
        ],
      ),
    );
  }
}

class _HeroFact extends StatelessWidget {
  const _HeroFact({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: AppTheme.textMuted)),
        const SizedBox(height: 2),
        Text(value,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }
}

class _HerdHealthSection extends StatelessWidget {
  const _HerdHealthSection({
    required this.summary,
    required this.priorityPigs,
    required this.latestAlertByPig,
    required this.isLoading,
    required this.error,
    required this.onRetry,
  });

  final HerdDailyAggregate? summary;
  final List<PigSummary> priorityPigs;
  final Map<String, HealthAlert> latestAlertByPig;
  final bool isLoading;
  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '猪群健康',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
            IconButton(
              tooltip: '刷新猪群健康',
              onPressed: isLoading ? null : onRetry,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (isLoading)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          )
        else if (error != null)
          AsyncStatePanel(
            key: const Key('dashboard-health-error'),
            title: '猪群健康数据加载失败',
            message: '数据库暂时不可用，请重试。',
            onRetry: onRetry,
          )
        else if (summary == null)
          const AsyncStatePanel(
            key: Key('dashboard-health-empty'),
            title: '暂无猪群健康数据',
            message: '尚未生成可供汇总的个体日统计。',
          )
        else ...[
          LayoutBuilder(
            builder: (context, constraints) {
              final responsive = ResponsiveLayout(constraints.maxWidth);
              return GridView.count(
                crossAxisCount: responsive.compactMetricColumns,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: responsive.gridAspectRatio(
                  phone: 1.08,
                  tablet: 1.45,
                  desktop: 1.7,
                ),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _HealthMetric(
                    key: const Key('dashboard-health-pig-count'),
                    label: '当前存栏',
                    value: '${summary!.pigCount}',
                    color: AppTheme.secondary,
                  ),
                  _HealthMetric(
                    label: '正常',
                    value:
                        '${summary!.pigCount - summary!.watchCount - summary!.highRiskCount}',
                    color: AppTheme.primary,
                  ),
                  _HealthMetric(
                    label: '重点关注',
                    value: '${summary!.watchCount}',
                    color: AppTheme.warning,
                  ),
                  _HealthMetric(
                    label: '高风险',
                    value: '${summary!.highRiskCount}',
                    color: AppTheme.danger,
                  ),
                  _HealthMetric(
                    label: '平均健康分',
                    value: summary!.averageHealthScore.toStringAsFixed(1),
                    color: const Color(0xFFA78BFA),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          Text(
            '重点关注猪只',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 8),
          if (priorityPigs.isEmpty)
            const AsyncStatePanel(
              title: '当前无重点关注猪只',
              message: '今日个体健康评分均处于正常范围。',
            )
          else
            ...priorityPigs.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _PriorityPigTile(
                  summary: item,
                  alert: latestAlertByPig[item.pig.id],
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _HealthMetric extends StatelessWidget {
  const _HealthMetric({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

class _PriorityPigTile extends StatelessWidget {
  const _PriorityPigTile({required this.summary, this.alert});

  final PigSummary summary;
  final HealthAlert? alert;

  @override
  Widget build(BuildContext context) {
    final stat = summary.latestStat!;
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PigDetailPage(pigId: summary.pig.id),
          ),
        ),
        leading: CircleAvatar(
          backgroundColor: riskColor(stat.riskLevel).withValues(alpha: 0.16),
          child: Icon(
            Icons.pets_outlined,
            color: riskColor(stat.riskLevel),
          ),
        ),
        title: Text(
          summary.pig.id,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          alert == null
              ? '${summary.pig.pigHouseId} · 健康评分 ${stat.healthScore} · '
                  '采食 ${stat.feedAmountKg.toStringAsFixed(2)} kg · '
                  '活动 ${(stat.activityDistanceMeters / 1000).toStringAsFixed(2)} km'
              : '${summary.pig.pigHouseId} · ${alert!.alertType.label} '
                  '${alert!.deviationPercent.abs().toStringAsFixed(1)}% · '
                  '健康评分 ${stat.healthScore}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: RiskBadge(level: stat.riskLevel),
      ),
    );
  }
}

class _SensorGrid extends StatelessWidget {
  const _SensorGrid({required this.snapshot});

  final SensorSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final thresholds = SmartPigfarmScope.watch(context).thresholdSettings;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 650 ? 3 : 2;
        final itemWidth = (constraints.maxWidth - (columns - 1) * 12) / columns;
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
              accent: const Color(0xFFFB7185),
              caption: '上限 ${thresholds.temperatureHigh.toStringAsFixed(1)} ℃',
            ),
            MetricCard(
              title: '湿度',
              value: snapshot.humidity.toStringAsFixed(0),
              unit: '%',
              icon: Icons.water_drop_outlined,
              accent: AppTheme.secondary,
              caption:
                  '${thresholds.humidityLow.toStringAsFixed(0)}–${thresholds.humidityHigh.toStringAsFixed(0)} %',
            ),
            MetricCard(
              title: '氨气',
              value: snapshot.ammonia.toStringAsFixed(1),
              unit: 'ppm',
              icon: Icons.science_outlined,
              accent: AppTheme.warning,
              caption: '上限 ${thresholds.ammoniaHigh.toStringAsFixed(1)} ppm',
            ),
            MetricCard(
              title: 'CO₂',
              value: snapshot.co2.toStringAsFixed(0),
              unit: 'ppm',
              icon: Icons.cloud_outlined,
              accent: const Color(0xFFA78BFA),
              caption: '上限 ${thresholds.co2High.toStringAsFixed(0)} ppm',
            ),
            MetricCard(
              title: '光照',
              value: snapshot.illuminance.toStringAsFixed(0),
              unit: 'lx',
              icon: Icons.light_mode_outlined,
              accent: const Color(0xFFFACC15),
              caption: '下限 ${thresholds.illuminanceLow.toStringAsFixed(0)} lx',
            ),
          ],
        );
      },
    );
  }
}

class _QuickEntryGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final entries = const [
      _QuickEntry('实时监控', Icons.monitor_heart_outlined, '/realtime'),
      _QuickEntry('远程控制', Icons.tune_outlined, '/control'),
      _QuickEntry('阈值设置', Icons.rule_outlined, '/thresholds'),
      _QuickEntry('告警记录', Icons.notifications_active_outlined, '/alarms'),
      _QuickEntry('猪群管理', Icons.agriculture_outlined, '/herd'),
      _QuickEntry('数据报表', Icons.show_chart_outlined, '/reports'),
      _QuickEntry('视频监控', Icons.videocam_outlined, '/video-ai'),
      _QuickEntry('权限管理', Icons.manage_accounts_outlined, '/permissions'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '快捷入口',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final responsive = ResponsiveLayout(constraints.maxWidth);
            return GridView.builder(
              itemCount: entries.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: responsive.quickEntryColumns,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: responsive.gridAspectRatio(
                  phone: 0.82,
                  tablet: 1.05,
                  desktop: 1.2,
                ),
              ),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => Navigator.of(context).pushNamed(entry.route),
                  child: Ink(
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceAlt,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.06)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 10),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(entry.icon, color: AppTheme.primary),
                          const SizedBox(height: 8),
                          Text(
                            entry.title,
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _DeviceOverview extends StatelessWidget {
  const _DeviceOverview({required this.statuses});

  final Map<DeviceType, DeviceStatus> statuses;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '设备联动状态',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 10),
        ...statuses.values.map((status) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: DeviceStatusTile(status: status),
          );
        }),
      ],
    );
  }
}

class _QuickEntry {
  const _QuickEntry(this.title, this.icon, this.route);

  final String title;
  final IconData icon;
  final String route;
}
