import 'dart:async';

import 'package:flutter/material.dart';

import '../models/herd_daily_aggregate.dart';
import '../models/pig_daily_stat.dart';
import '../models/pig_summary.dart';
import '../repositories/pig_repository.dart';
import '../repositories/repository_bundle.dart';
import '../widgets/app_theme.dart';
import '../widgets/async_state_panel.dart';
import '../widgets/metric_card.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/repository_scope.dart';
import '../widgets/risk_badge.dart';
import 'pig_detail_page.dart';

class HerdManagementPage extends StatefulWidget {
  const HerdManagementPage({super.key});

  @override
  State<HerdManagementPage> createState() => _HerdManagementPageState();
}

class _HerdManagementPageState extends State<HerdManagementPage> {
  final TextEditingController _searchController = TextEditingController();
  RepositoryBundle? _repositories;
  Timer? _searchDebounce;
  HerdDailyAggregate? _summary;
  List<PigSummary> _pigs = const [];
  String? _pigHouseFilter;
  RiskLevel? _riskFilter;
  PigSummarySort _sort = PigSummarySort.id;
  bool _initialLoading = true;
  bool _listLoading = false;
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

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _initialLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<Object?>([
        _repositories!.pigMetrics.getLatestHerdAggregate(),
        _queryPigs(),
      ]);
      if (!mounted) return;
      setState(() {
        _summary = results[0] as HerdDailyAggregate?;
        _pigs = results[1]! as List<PigSummary>;
        _initialLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _initialLoading = false;
      });
    }
  }

  Future<List<PigSummary>> _queryPigs() {
    return _repositories!.pigs.queryPigSummaries(
      numberQuery: _searchController.text,
      pigHouseId: _pigHouseFilter,
      healthStatus: _riskFilter,
      sort: _sort,
      limit: 250,
    );
  }

  Future<void> _reloadList() async {
    setState(() {
      _listLoading = true;
      _error = null;
    });
    try {
      final pigs = await _queryPigs();
      if (!mounted) return;
      setState(() {
        _pigs = pigs;
        _listLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _listLoading = false;
      });
    }
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), _reloadList);
  }

  @override
  Widget build(BuildContext context) {
    if (_initialLoading && _summary == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _summary == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: AsyncStatePanel(
            key: const Key('herd-error-state'),
            title: '猪群数据加载失败',
            message: '无法读取 Repository，请检查数据库后重试。',
            icon: Icons.cloud_off_outlined,
            onRetry: _loadAll,
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final responsive = ResponsiveLayout(constraints.maxWidth);
        final horizontal = responsive.horizontalPadding;
        return SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppBreakpoints.maxContentWidth,
              ),
              child: CustomScrollView(
                key: const Key('herd-management-scroll'),
                slivers: [
                  SliverPadding(
                    padding:
                        EdgeInsets.fromLTRB(horizontal, 16, horizontal, 12),
                    sliver: SliverList.list(
                      children: [
                        if (_summary != null)
                          _HerdSummaryGrid(summary: _summary!),
                        const SizedBox(height: 14),
                        _buildFilters(),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          AsyncStatePanel(
                            title: '列表刷新失败',
                            message: '已保留上次成功数据，可重试当前筛选。',
                            icon: Icons.sync_problem_outlined,
                            onRetry: _reloadList,
                          ),
                        ],
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '猪只列表',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w900,
                                    ),
                              ),
                            ),
                            Text(
                              '已加载 ${_pigs.length} 头',
                              key: const Key('herd-loaded-count'),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    color: const Color(0xFF8EA39B),
                                  ),
                            ),
                          ],
                        ),
                        if (_listLoading) ...[
                          const SizedBox(height: 10),
                          const LinearProgressIndicator(minHeight: 2),
                        ],
                      ],
                    ),
                  ),
                  if (_pigs.isEmpty && !_listLoading)
                    SliverPadding(
                      padding:
                          EdgeInsets.fromLTRB(horizontal, 0, horizontal, 20),
                      sliver: const SliverToBoxAdapter(
                        child: AsyncStatePanel(
                          key: Key('herd-empty-state'),
                          title: '未找到猪只',
                          message: '请调整编号、耳标或健康状态筛选条件。',
                          icon: Icons.search_off_outlined,
                        ),
                      ),
                    )
                  else if (responsive.isPhone)
                    SliverPadding(
                      padding:
                          EdgeInsets.fromLTRB(horizontal, 0, horizontal, 24),
                      sliver: SliverList.separated(
                        itemCount: _pigs.length,
                        itemBuilder: (context, index) {
                          final summary = _pigs[index];
                          return _PigSummaryCard(
                            key: Key('pig-card-${summary.pig.id}'),
                            summary: summary,
                            onTap: () => _openPig(summary.pig.id),
                          );
                        },
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                      ),
                    )
                  else
                    SliverPadding(
                      padding:
                          EdgeInsets.fromLTRB(horizontal, 0, horizontal, 24),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: responsive.herdColumns,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: switch (responsive.windowClass) {
                            AppWindowClass.phone => 1.4,
                            AppWindowClass.smallTablet =>
                              constraints.maxWidth < 700 ? 1.55 : 2.1,
                            AppWindowClass.largeTablet => 2.7,
                            AppWindowClass.desktop => 3.3,
                          },
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final summary = _pigs[index];
                            return _PigSummaryCard(
                              key: Key('pig-card-${summary.pig.id}'),
                              summary: summary,
                              onTap: () => _openPig(summary.pig.id),
                            );
                          },
                          childCount: _pigs.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilters() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 560;
            final halfWidth = compact ? (constraints.maxWidth - 10) / 2 : 170.0;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: compact ? constraints.maxWidth : 280,
                  child: TextField(
                    key: const Key('herd-search-field'),
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: const InputDecoration(
                      labelText: '搜索编号或耳标',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                SizedBox(
                  width: halfWidth,
                  child: DropdownButtonFormField<String?>(
                    key: ValueKey('house-${_pigHouseFilter ?? 'all'}'),
                    initialValue: _pigHouseFilter,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: '猪舍'),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('全部猪舍')),
                      DropdownMenuItem(value: 'A01', child: Text('A01')),
                      DropdownMenuItem(value: 'A02', child: Text('A02')),
                      DropdownMenuItem(value: 'A03', child: Text('A03')),
                    ],
                    onChanged: (value) {
                      setState(() => _pigHouseFilter = value);
                      _reloadList();
                    },
                  ),
                ),
                SizedBox(
                  width: halfWidth,
                  child: DropdownButtonFormField<RiskLevel?>(
                    key: ValueKey('risk-${_riskFilter?.name ?? 'all'}'),
                    initialValue: _riskFilter,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: '健康状态'),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('全部状态')),
                      DropdownMenuItem(
                        value: RiskLevel.normal,
                        child: Text('正常'),
                      ),
                      DropdownMenuItem(
                        value: RiskLevel.watch,
                        child: Text('重点关注'),
                      ),
                      DropdownMenuItem(
                        value: RiskLevel.high,
                        child: Text('高风险'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() => _riskFilter = value);
                      _reloadList();
                    },
                  ),
                ),
                SizedBox(
                  width: compact ? constraints.maxWidth : 240,
                  child: DropdownButtonFormField<PigSummarySort>(
                    key: ValueKey('sort-${_sort.name}'),
                    initialValue: _sort,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: '排序',
                      prefixIcon: Icon(Icons.sort),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: PigSummarySort.id, child: Text('猪只编号')),
                      DropdownMenuItem(
                        value: PigSummarySort.healthScoreAscending,
                        child: Text('健康评分从低到高'),
                      ),
                      DropdownMenuItem(
                        value: PigSummarySort.weightDescending,
                        child: Text('体重从高到低'),
                      ),
                      DropdownMenuItem(
                        value: PigSummarySort.feedDescending,
                        child: Text('采食量从高到低'),
                      ),
                      DropdownMenuItem(
                        value: PigSummarySort.activityDescending,
                        child: Text('活动量从高到低'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _sort = value);
                      _reloadList();
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _openPig(String pigId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PigDetailPage(pigId: pigId),
      ),
    );
  }
}

class _HerdSummaryGrid extends StatelessWidget {
  const _HerdSummaryGrid({required this.summary});

  final HerdDailyAggregate summary;

  @override
  Widget build(BuildContext context) {
    final normalCount =
        summary.pigCount - summary.watchCount - summary.highRiskCount;
    final averageFeed = summary.pigCount == 0
        ? 0.0
        : summary.totalFeedAmountKg / summary.pigCount;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 4
            : constraints.maxWidth >= 650
                ? 3
                : 2;
        final itemWidth = (constraints.maxWidth - (columns - 1) * 10) / columns;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: columns,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: itemWidth / 128,
          children: [
            MetricCard(
              title: '当前存栏',
              value: '${summary.pigCount}',
              unit: '头',
              icon: Icons.agriculture_outlined,
              accent: AppTheme.secondary,
            ),
            MetricCard(
              title: '正常',
              value: '$normalCount',
              unit: '头',
              icon: Icons.check_circle_outline,
              accent: AppTheme.primary,
            ),
            MetricCard(
              title: '重点关注',
              value: '${summary.watchCount}',
              unit: '头',
              icon: Icons.visibility_outlined,
              accent: AppTheme.warning,
            ),
            MetricCard(
              title: '高风险',
              value: '${summary.highRiskCount}',
              unit: '头',
              icon: Icons.warning_amber_rounded,
              accent: AppTheme.danger,
            ),
            MetricCard(
              title: '平均体重',
              value: summary.averageWeightKg.toStringAsFixed(1),
              unit: 'kg',
              icon: Icons.monitor_weight_outlined,
              accent: const Color(0xFFA78BFA),
            ),
            MetricCard(
              title: '今日平均采食',
              value: averageFeed.toStringAsFixed(2),
              unit: 'kg',
              icon: Icons.restaurant_outlined,
              accent: const Color(0xFFF59E0B),
            ),
            MetricCard(
              title: '今日平均活动',
              value: (summary.averageActivityDistanceMeters / 1000)
                  .toStringAsFixed(2),
              unit: 'km',
              icon: Icons.directions_walk_outlined,
              accent: AppTheme.secondary,
            ),
          ],
        );
      },
    );
  }
}

class _PigSummaryCard extends StatelessWidget {
  const _PigSummaryCard({
    super.key,
    required this.summary,
    required this.onTap,
  });

  final PigSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final stat = summary.latestStat;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          summary.pig.id,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        Text(
                          '耳标 ${summary.pig.earTag} · 猪舍 ${summary.pig.pigHouseId}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: const Color(0xFF8EA39B),
                                  ),
                        ),
                      ],
                    ),
                  ),
                  if (stat != null) RiskBadge(level: stat.riskLevel),
                ],
              ),
              const SizedBox(height: 10),
              if (stat == null)
                const Text('暂无今日指标')
              else
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _InlineMetric(
                            label: '体重',
                            value: '${stat.weightKg.toStringAsFixed(1)} kg',
                          ),
                        ),
                        Expanded(
                          child: _InlineMetric(
                            label: '采食',
                            value: '${stat.feedAmountKg.toStringAsFixed(2)} kg',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: _InlineMetric(
                            label: '活动',
                            value:
                                '${(stat.activityDistanceMeters / 1000).toStringAsFixed(2)} km',
                          ),
                        ),
                        Expanded(
                          child: _InlineMetric(
                            label: '健康分',
                            value: '${stat.healthScore}',
                            color: riskColor(stat.riskLevel),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineMetric extends StatelessWidget {
  const _InlineMetric({
    required this.label,
    required this.value,
    this.color,
  });

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppTheme.textMuted,
              ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: color ?? Colors.white,
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}
