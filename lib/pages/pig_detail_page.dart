import 'package:flutter/material.dart';

import '../models/health_alert.dart';
import '../models/immunization_record.dart';
import '../models/pig.dart';
import '../models/pig_daily_stat.dart';
import '../models/pig_detail.dart';
import '../models/report_data.dart';
import '../repositories/repository_bundle.dart';
import '../services/formatters.dart';
import '../widgets/app_theme.dart';
import '../widgets/async_state_panel.dart';
import '../widgets/line_chart_card.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/repository_scope.dart';
import '../widgets/risk_badge.dart';
import '../widgets/status_badge.dart';

class PigDetailPage extends StatefulWidget {
  const PigDetailPage({
    super.key,
    required this.pigId,
  });

  final String pigId;

  @override
  State<PigDetailPage> createState() => _PigDetailPageState();
}

class _PigDetailPageState extends State<PigDetailPage> {
  RepositoryBundle? _repositories;
  PigDetail? _detail;
  List<PigDailyStat> _overviewStats = const [];
  List<PigDailyStat> _trendStats = const [];
  List<HealthAlert> _alerts = const [];
  int _rangeDays = 7;
  bool _loading = true;
  bool _trendLoading = false;
  Object? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repositories = RepositoryScope.read(context);
    if (!identical(_repositories, repositories)) {
      _repositories = repositories;
      _loadAll();
    }
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await _repositories!.pigs.getPigDetail(widget.pigId);
      if (detail == null) {
        if (!mounted) return;
        setState(() {
          _detail = null;
          _loading = false;
        });
        return;
      }
      final endDate = detail.latestStat?.date ?? _todayUtc();
      final overviewFuture = _repositories!.pigMetrics.queryDailyStats(
        pigId: widget.pigId,
        from: endDate.subtract(const Duration(days: 7)),
        to: endDate,
      );
      final trendFuture = _repositories!.pigMetrics.queryDailyStats(
        pigId: widget.pigId,
        from: endDate.subtract(Duration(days: _rangeDays - 1)),
        to: endDate,
      );
      final alertsFuture = _repositories!.healthAlerts.queryAlerts(
        pigId: widget.pigId,
        limit: 200,
      );
      final results = await Future.wait<Object>([
        overviewFuture,
        trendFuture,
        alertsFuture,
      ]);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _overviewStats = results[0] as List<PigDailyStat>;
        _trendStats = results[1] as List<PigDailyStat>;
        _alerts = results[2] as List<HealthAlert>;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _loadTrend(int days) async {
    final detail = _detail;
    if (detail == null) return;
    setState(() {
      _rangeDays = days;
      _trendLoading = true;
      _error = null;
    });
    try {
      final endDate = detail.latestStat?.date ?? _todayUtc();
      final trends = await _repositories!.pigMetrics.queryDailyStats(
        pigId: widget.pigId,
        from: endDate.subtract(Duration(days: days - 1)),
        to: endDate,
      );
      if (!mounted) return;
      setState(() {
        _trendStats = trends;
        _trendLoading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _trendLoading = false;
      });
    }
  }

  DateTime _todayUtc() {
    final now = DateTime.now();
    return DateTime.utc(now.year, now.month, now.day);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('单猪数字档案 · ${widget.pigId}')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _detail == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: AsyncStatePanel(
            key: const Key('pig-detail-error-state'),
            title: '数字档案加载失败',
            message: '无法读取该猪的档案与历史数据。',
            icon: Icons.cloud_off_outlined,
            onRetry: _loadAll,
          ),
        ),
      );
    }
    final detail = _detail;
    if (detail == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: AsyncStatePanel(
            key: Key('pig-detail-empty-state'),
            title: '未找到猪只档案',
            message: '该猪只编号可能已删除或未完成初始化。',
            icon: Icons.search_off_outlined,
          ),
        ),
      );
    }

    final latest = detail.latestStat;
    return LayoutBuilder(
      builder: (context, constraints) {
        final responsive = ResponsiveLayout(constraints.maxWidth);
        return RefreshIndicator(
          onRefresh: _loadAll,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppBreakpoints.maxContentWidth,
              ),
              child: ListView(
                key: const Key('pig-detail-scroll'),
                padding: EdgeInsets.fromLTRB(
                  responsive.horizontalPadding,
                  16,
                  responsive.horizontalPadding,
                  24,
                ),
                children: [
                  _ProfileHeader(detail: detail),
                  const SizedBox(height: 12),
                  if (latest != null &&
                      latest.riskLevel != RiskLevel.normal) ...[
                    _RiskAttentionBanner(stat: latest),
                    const SizedBox(height: 12),
                  ],
                  if (latest == null)
                    const AsyncStatePanel(
                      title: '暂无今日指标',
                      message: '档案已存在，但还没有可用的每日行为数据。',
                      icon: Icons.event_busy_outlined,
                    )
                  else
                    _TodayBaselineGrid(
                      latest: latest,
                      overviewStats: _overviewStats,
                    ),
                  const SizedBox(height: 16),
                  _buildTrendSection(),
                  const SizedBox(height: 16),
                  _HealthAlertsSection(alerts: _alerts),
                  const SizedBox(height: 16),
                  _ImmunizationSection(records: detail.immunizations),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTrendSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '行为与健康趋势',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
            Text(
              '已加载 ${_trendStats.length} 天记录',
              key: const Key('pig-history-loaded-count'),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: const Color(0xFF8EA39B),
                  ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SegmentedButton<int>(
          key: const Key('pig-range-selector'),
          selected: {_rangeDays},
          onSelectionChanged: (selection) => _loadTrend(selection.first),
          segments: const [
            ButtonSegment(value: 7, label: Text('7天')),
            ButtonSegment(value: 30, label: Text('30天')),
            ButtonSegment(value: 90, label: Text('90天')),
          ],
        ),
        const SizedBox(height: 10),
        if (_trendLoading)
          const LinearProgressIndicator(minHeight: 2)
        else if (_trendStats.isEmpty)
          const AsyncStatePanel(
            title: '暂无趋势数据',
            message: '当前时间范围没有个体统计记录。',
            icon: Icons.show_chart_outlined,
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final columns =
                  constraints.maxWidth < AppBreakpoints.phone ? 1 : 2;
              final aspectRatio = switch (constraints.maxWidth) {
                < AppBreakpoints.phone => 1.3,
                < 700 => 0.98,
                < AppBreakpoints.tablet => 1.35,
                < AppBreakpoints.largeTablet => 1.7,
                _ => 2.2,
              };
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: columns,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: aspectRatio,
                children: _TrendMetric.values.map((metric) {
                  return LineChartCard(
                    key: metric == _TrendMetric.weight
                        ? const Key('pig-trend-chart')
                        : null,
                    title: metric.title,
                    unit: metric.unit,
                    color: metric.color,
                    nonNegative: true,
                    axisDecimals: metric.axisDecimals,
                    chartHeight: 190,
                    points: _trendStats.map((stat) {
                      return ChartPoint(
                        label: formatShortDate(stat.date),
                        value: metric.valueOf(stat),
                      );
                    }).toList(growable: false),
                  );
                }).toList(growable: false),
              );
            },
          ),
        if (_error != null && _detail != null) ...[
          const SizedBox(height: 10),
          AsyncStatePanel(
            title: '趋势刷新失败',
            message: '已保留上次成功数据。',
            icon: Icons.sync_problem_outlined,
            onRetry: () => _loadTrend(_rangeDays),
          ),
        ],
      ],
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.detail});

  final PigDetail detail;

  @override
  Widget build(BuildContext context) {
    final pig = detail.pig;
    final stat = detail.latestStat;
    final level = stat?.riskLevel ?? RiskLevel.normal;
    final referenceDate = stat?.date ?? DateTime.now();
    return Container(
      key: const Key('pig-digital-profile'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: riskColor(level).withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: riskColor(level).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.pets, color: riskColor(level), size: 30),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pig.id,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                    ),
                    Text(
                      '耳标 ${pig.earTag} · ${pig.currentStatus.label}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFFA7BDB5),
                          ),
                    ),
                  ],
                ),
              ),
              RiskBadge(level: level),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 18,
            runSpacing: 12,
            children: [
              _ProfileField(label: '猪舍', value: pig.pigHouseId),
              _ProfileField(label: '批次', value: pig.batchNo),
              _ProfileField(label: '性别', value: pig.sex.label),
              _ProfileField(
                label: '日龄',
                value: '${pig.ageDaysAt(referenceDate)} 天',
              ),
              _ProfileField(
                label: '当前体重',
                value: stat == null
                    ? '--'
                    : '${stat.weightKg.toStringAsFixed(1)} kg',
              ),
              _ProfileField(
                label: '健康评分',
                value: stat?.healthScore.toString() ?? '--',
                valueColor: riskColor(level),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 142,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: const Color(0xFF708A82),
                ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: valueColor ?? Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _RiskAttentionBanner extends StatelessWidget {
  const _RiskAttentionBanner({required this.stat});

  final PigDailyStat stat;

  @override
  Widget build(BuildContext context) {
    final color = riskColor(stat.riskLevel);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${stat.riskLevel.label}：行为指标偏离自身基线，建议结合巡栏结果复核。',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayBaselineGrid extends StatelessWidget {
  const _TodayBaselineGrid({
    required this.latest,
    required this.overviewStats,
  });

  final PigDailyStat latest;
  final List<PigDailyStat> overviewStats;

  @override
  Widget build(BuildContext context) {
    final history = overviewStats
        .where((item) => item.date.isBefore(latest.date))
        .toList(growable: false);
    final baselineFeed = _average(history.map((item) => item.feedAmountKg));
    final baselineActivity =
        _average(history.map((item) => item.activityDistanceMeters));
    final feedChange = _percentChange(latest.feedAmountKg, baselineFeed);
    final activityChange =
        _percentChange(latest.activityDistanceMeters, baselineActivity);
    final weightGain =
        history.isEmpty ? 0.0 : latest.weightKg - history.first.weightKg;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '今日与近 7 日基线',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 700 ? 4 : 2;
            final itemWidth =
                (constraints.maxWidth - (columns - 1) * 10) / columns;
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: columns,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: itemWidth / 124,
              children: [
                _ComparisonCard(
                  title: '今日采食量',
                  value: '${latest.feedAmountKg.toStringAsFixed(2)} kg',
                  comparison: _changeText(feedChange),
                  color:
                      feedChange <= -20 ? AppTheme.warning : AppTheme.primary,
                  icon: Icons.restaurant_outlined,
                ),
                _ComparisonCard(
                  title: '今日活动距离',
                  value:
                      '${(latest.activityDistanceMeters / 1000).toStringAsFixed(2)} km',
                  comparison: _changeText(activityChange),
                  color: activityChange <= -25
                      ? AppTheme.warning
                      : AppTheme.secondary,
                  icon: Icons.directions_walk_outlined,
                ),
                _ComparisonCard(
                  title: '近7日增重',
                  value: '+${weightGain.toStringAsFixed(1)} kg',
                  comparison: '以首日体重为基准',
                  color: const Color(0xFFA78BFA),
                  icon: Icons.monitor_weight_outlined,
                ),
                _ComparisonCard(
                  title: '今日休息时长',
                  value:
                      '${(latest.restDurationMinutes / 60).toStringAsFixed(1)} h',
                  comparison: '日行为统计',
                  color: AppTheme.secondary,
                  icon: Icons.bedtime_outlined,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  double _average(Iterable<double> values) {
    final list = values.toList();
    return list.isEmpty ? 0 : list.reduce((a, b) => a + b) / list.length;
  }

  double _percentChange(double current, double baseline) {
    if (baseline == 0) return 0;
    return (current - baseline) / baseline * 100;
  }

  String _changeText(double value) {
    if (value.abs() < 0.05) return '与7日均值持平';
    return '较7日均值 ${value > 0 ? '↑' : '↓'}${value.abs().toStringAsFixed(1)}%';
  }
}

class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard({
    required this.title,
    required this.value,
    required this.comparison,
    required this.color,
    required this.icon,
  });

  final String title;
  final String value;
  final String comparison;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: const Color(0xFFA7BDB5),
                  ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
            Text(
              comparison,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HealthAlertsSection extends StatelessWidget {
  const _HealthAlertsSection({required this.alerts});

  final List<HealthAlert> alerts;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '健康预警',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 10),
        if (alerts.isEmpty)
          const AsyncStatePanel(
            key: Key('pig-alerts-empty'),
            title: '暂无个体健康预警',
            message: '近期采食、活动和增重未触发规则。',
            icon: Icons.health_and_safety_outlined,
          )
        else
          ...alerts.map((alert) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _HealthAlertCard(alert: alert),
              )),
      ],
    );
  }
}

class _HealthAlertCard extends StatelessWidget {
  const _HealthAlertCard({required this.alert});

  final HealthAlert alert;

  @override
  Widget build(BuildContext context) {
    final color = alert.severity == HealthAlertSeverity.critical
        ? AppTheme.danger
        : AppTheme.warning;
    final unit = switch (alert.alertType) {
      HealthAlertType.feedDrop => 'kg',
      HealthAlertType.activityDrop => 'm',
      HealthAlertType.weightGainAbnormal => 'kg',
      HealthAlertType.multiFactorRisk => '分',
    };
    return Card(
      key: Key('health-alert-${alert.id}'),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    alert.alertType.label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                StatusBadge(label: alert.severity.label, color: color),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              formatDateTime(alert.createdAt),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: const Color(0xFF8EA39B),
                  ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _AlertValue(
                  label: '当前',
                  value: '${alert.currentValue.toStringAsFixed(2)} $unit',
                ),
                _AlertValue(
                  label: '历史基线',
                  value: '${alert.baselineValue.toStringAsFixed(2)} $unit',
                ),
                _AlertValue(
                  label: '偏离',
                  value: '${alert.deviationPercent.toStringAsFixed(1)}%',
                  color: color,
                ),
                _AlertValue(label: '状态', value: alert.status.label),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertValue extends StatelessWidget {
  const _AlertValue({
    required this.label,
    required this.value,
    this.color,
  });

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 134,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: const Color(0xFF708A82),
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: color ?? Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _ImmunizationSection extends StatelessWidget {
  const _ImmunizationSection({required this.records});

  final List<ImmunizationRecord> records;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '免疫记录',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 10),
        if (records.isEmpty)
          const AsyncStatePanel(
            title: '暂无免疫记录',
            message: '该猪只还没有可用的免疫档案。',
            icon: Icons.vaccines_outlined,
          )
        else
          ...records.map((record) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ImmunizationCard(record: record),
              )),
      ],
    );
  }
}

class _ImmunizationCard extends StatelessWidget {
  const _ImmunizationCard({required this.record});

  final ImmunizationRecord record;

  @override
  Widget build(BuildContext context) {
    final valid =
        record.nextDueAt == null || record.nextDueAt!.isAfter(DateTime.now());
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.vaccines_outlined, color: AppTheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.vaccineName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${formatDate(record.immunizedAt)} · ${record.batchNo}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF8EA39B),
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${record.operatorName} · ${record.note}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFFA7BDB5),
                        ),
                  ),
                ],
              ),
            ),
            StatusBadge(
              label: valid ? '有效' : '待补种',
              color: valid ? AppTheme.primary : AppTheme.warning,
            ),
          ],
        ),
      ),
    );
  }
}

enum _TrendMetric {
  weight,
  feed,
  activity,
  health;

  String get title {
    switch (this) {
      case _TrendMetric.weight:
        return '体重趋势';
      case _TrendMetric.feed:
        return '采食趋势';
      case _TrendMetric.activity:
        return '活动趋势';
      case _TrendMetric.health:
        return '健康评分趋势';
    }
  }

  String get unit {
    switch (this) {
      case _TrendMetric.weight:
      case _TrendMetric.feed:
        return 'kg';
      case _TrendMetric.activity:
        return 'km';
      case _TrendMetric.health:
        return '分';
    }
  }

  Color get color {
    switch (this) {
      case _TrendMetric.weight:
        return const Color(0xFFA78BFA);
      case _TrendMetric.feed:
        return const Color(0xFFF59E0B);
      case _TrendMetric.activity:
        return AppTheme.secondary;
      case _TrendMetric.health:
        return AppTheme.primary;
    }
  }

  int get axisDecimals => switch (this) {
        _TrendMetric.weight => 1,
        _TrendMetric.feed => 1,
        _TrendMetric.activity => 1,
        _TrendMetric.health => 0,
      };

  double valueOf(PigDailyStat stat) {
    switch (this) {
      case _TrendMetric.weight:
        return stat.weightKg;
      case _TrendMetric.feed:
        return stat.feedAmountKg;
      case _TrendMetric.activity:
        return stat.activityDistanceMeters / 1000;
      case _TrendMetric.health:
        return stat.healthScore.toDouble();
    }
  }
}
