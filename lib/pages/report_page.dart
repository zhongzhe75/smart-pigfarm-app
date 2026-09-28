import 'package:flutter/material.dart';

import '../models/health_alert.dart';
import '../models/herd_daily_aggregate.dart';
import '../models/report_data.dart';
import '../repositories/repository_bundle.dart';
import '../widgets/app_state_scope.dart';
import '../widgets/app_theme.dart';
import '../widgets/async_state_panel.dart';
import '../widgets/line_chart_card.dart';
import '../widgets/metric_card.dart';
import '../widgets/page_scaffold.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/repository_scope.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  RepositoryBundle? _repositories;
  int _days = 7;
  List<HerdDailyAggregate> _aggregates = const [];
  List<HealthAlert> _alerts = const [];
  Object? _error;
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repositories = RepositoryScope.read(context);
    if (!identical(repositories, _repositories)) {
      _repositories = repositories;
      _loadHerdReport();
    }
  }

  Future<void> _loadHerdReport() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final now = DateTime.now();
    final to = DateTime.utc(now.year, now.month, now.day, 23, 59, 59, 999);
    final from = DateTime.utc(now.year, now.month, now.day)
        .subtract(Duration(days: _days - 1));
    try {
      final results = await Future.wait<Object>([
        _repositories!.pigMetrics.queryHerdDailyAggregates(
          from: from,
          to: to,
        ),
        _repositories!.healthAlerts.queryAlerts(
          from: from,
          to: to,
          limit: 10000,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _aggregates = results[0] as List<HerdDailyAggregate>;
        _alerts = results[1] as List<HealthAlert>;
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

  @override
  Widget build(BuildContext context) {
    final state = SmartPigfarmScope.watch(context);
    final report = state.reportData;
    if (report == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return PageScaffold(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '猪场数据报表',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
            IconButton.filledTonal(
              tooltip: '刷新报表',
              onPressed: () async {
                await Future.wait([
                  SmartPigfarmScope.read(context).refreshReportData(),
                  _loadHerdReport(),
                ]);
              },
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        _HerdReportSection(
          days: _days,
          aggregates: _aggregates,
          alerts: _alerts,
          isLoading: _loading,
          error: _error,
          onDaysChanged: (days) {
            if (days == _days) return;
            setState(() => _days = days);
            _loadHerdReport();
          },
          onRetry: _loadHerdReport,
        ),
        Text(
          '猪舍环境与运营报表',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        _ReportChartGrid(
          children: [
            LineChartCard(
              title: '温度趋势',
              unit: '℃',
              points: report.temperatureCurve,
              color: AppTheme.warning,
            ),
            LineChartCard(
              title: '湿度趋势',
              unit: '%',
              points: report.humidityCurve,
              color: AppTheme.secondary,
              nonNegative: true,
            ),
            LineChartCard(
              title: '光照趋势',
              unit: 'lx',
              points: report.lightCurve,
              color: AppTheme.warning,
              nonNegative: true,
            ),
            LineChartCard(
              title: '耗料趋势',
              unit: 'kg/时段',
              points: report.feedCurve,
              color: AppTheme.primary,
              nonNegative: true,
              axisDecimals: 1,
            ),
          ],
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final responsive = ResponsiveLayout(constraints.maxWidth);
            return GridView.count(
              crossAxisCount: responsive.metricColumns,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: responsive.gridAspectRatio(
                phone: 1.16,
                tablet: 1.4,
                desktop: 1.55,
              ),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                MetricCard(
                  title: '通风时长',
                  value: report.ventilationHours.toStringAsFixed(1),
                  unit: 'h',
                  icon: Icons.air,
                  accent: AppTheme.secondary,
                ),
                MetricCard(
                  title: '喷雾时长',
                  value: report.sprayHours.toStringAsFixed(1),
                  unit: 'h',
                  icon: Icons.water_drop_outlined,
                  accent: AppTheme.primary,
                ),
                MetricCard(
                  title: '饲料成本',
                  value: report.feedCost.toStringAsFixed(0),
                  unit: '元',
                  icon: Icons.payments_outlined,
                  accent: const Color(0xFFF59E0B),
                ),
                MetricCard(
                  title: '总成本',
                  value: report.totalCost.toStringAsFixed(0),
                  unit: '元',
                  icon: Icons.calculate_outlined,
                  accent: const Color(0xFFA78BFA),
                  caption:
                      '含电费 ${report.electricityCost.toStringAsFixed(0)} / 防疫 ${report.medicineCost.toStringAsFixed(0)}',
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _HerdReportSection extends StatelessWidget {
  const _HerdReportSection({
    required this.days,
    required this.aggregates,
    required this.alerts,
    required this.isLoading,
    required this.error,
    required this.onDaysChanged,
    required this.onRetry,
  });

  final int days;
  final List<HerdDailyAggregate> aggregates;
  final List<HealthAlert> alerts;
  final bool isLoading;
  final Object? error;
  final ValueChanged<int> onDaysChanged;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '猪群经营 / 健康统计',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            SegmentedButton<int>(
              selected: {days},
              onSelectionChanged: (value) => onDaysChanged(value.first),
              segments: const [
                ButtonSegment(value: 7, label: Text('7天')),
                ButtonSegment(value: 30, label: Text('30天')),
                ButtonSegment(value: 90, label: Text('90天')),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (isLoading)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Center(child: CircularProgressIndicator()),
            ),
          )
        else if (error != null)
          AsyncStatePanel(
            key: const Key('report-herd-error'),
            title: '猪群报表加载失败',
            message: '数据库查询未完成，请重试。',
            onRetry: onRetry,
          )
        else if (aggregates.isEmpty)
          const AsyncStatePanel(
            key: Key('report-herd-empty'),
            title: '暂无猪群报表数据',
            message: '当前日期范围内没有个体统计记录。',
          )
        else ...[
          _RiskCountGrid(aggregate: aggregates.last),
          const SizedBox(height: 12),
          _ReportChartGrid(
            children: [
              LineChartCard(
                title: '平均体重趋势',
                unit: 'kg',
                points: _points(aggregates, (item) => item.averageWeightKg),
                color: AppTheme.secondary,
                nonNegative: true,
                axisDecimals: 1,
              ),
              LineChartCard(
                title: '平均采食量趋势',
                unit: 'kg/头',
                points: _points(
                  aggregates,
                  (item) => item.pigCount == 0
                      ? 0
                      : item.totalFeedAmountKg / item.pigCount,
                ),
                color: AppTheme.warning,
                nonNegative: true,
                axisDecimals: 1,
              ),
              LineChartCard(
                title: '平均活动量趋势',
                unit: 'km',
                points: _points(
                  aggregates,
                  (item) => item.averageActivityDistanceMeters / 1000,
                ),
                color: AppTheme.secondary,
                nonNegative: true,
                axisDecimals: 1,
              ),
              LineChartCard(
                title: '猪群平均健康评分趋势',
                unit: '分',
                points: _points(
                  aggregates,
                  (item) => item.averageHealthScore,
                ),
                color: AppTheme.primary,
                nonNegative: true,
                axisDecimals: 1,
              ),
              LineChartCard(
                title: '每日健康预警数量',
                unit: '条',
                points: _alertPoints(aggregates, alerts),
                color: AppTheme.danger,
                nonNegative: true,
                axisDecimals: 0,
              ),
            ],
          ),
        ],
      ],
    );
  }

  static List<ChartPoint> _points(
    List<HerdDailyAggregate> items,
    double Function(HerdDailyAggregate) value,
  ) {
    return items
        .map(
          (item) => ChartPoint(
            label: '${item.date.month}/${item.date.day}',
            value: value(item),
          ),
        )
        .toList(growable: false);
  }

  static List<ChartPoint> _alertPoints(
    List<HerdDailyAggregate> aggregates,
    List<HealthAlert> alerts,
  ) {
    final counts = <String, int>{};
    for (final alert in alerts) {
      final key =
          '${alert.createdAt.year}-${alert.createdAt.month}-${alert.createdAt.day}';
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return aggregates.map((item) {
      final key = '${item.date.year}-${item.date.month}-${item.date.day}';
      return ChartPoint(
        label: '${item.date.month}/${item.date.day}',
        value: (counts[key] ?? 0).toDouble(),
      );
    }).toList(growable: false);
  }
}

class _ReportChartGrid extends StatelessWidget {
  const _ReportChartGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < AppBreakpoints.phone ? 1 : 2;
        final aspectRatio = switch (constraints.maxWidth) {
          < AppBreakpoints.phone => 1.5,
          < AppBreakpoints.tablet => 1.25,
          < AppBreakpoints.largeTablet => 2.0,
          _ => 2.35,
        };
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: columns,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: aspectRatio,
          children: children,
        );
      },
    );
  }
}

class _RiskCountGrid extends StatelessWidget {
  const _RiskCountGrid({required this.aggregate});

  final HerdDailyAggregate aggregate;

  @override
  Widget build(BuildContext context) {
    final normal =
        aggregate.pigCount - aggregate.watchCount - aggregate.highRiskCount;
    return LayoutBuilder(
      builder: (context, constraints) {
        final responsive = ResponsiveLayout(constraints.maxWidth);
        return GridView.count(
          crossAxisCount: responsive.compactMetricColumns,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: responsive.gridAspectRatio(
            phone: 1.22,
            tablet: 1.5,
            desktop: 1.7,
          ),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _RiskMetric(label: '正常', value: normal, color: AppTheme.primary),
            _RiskMetric(
              label: '重点关注',
              value: aggregate.watchCount,
              color: AppTheme.warning,
            ),
            _RiskMetric(
              label: '高风险',
              value: aggregate.highRiskCount,
              color: AppTheme.danger,
            ),
          ],
        );
      },
    );
  }
}

class _RiskMetric extends StatelessWidget {
  const _RiskMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w900,
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
