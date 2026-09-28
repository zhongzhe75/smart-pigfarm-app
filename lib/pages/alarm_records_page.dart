import 'package:flutter/material.dart';

import '../models/alarm_record.dart';
import '../models/health_alert.dart';
import '../models/user_role.dart';
import '../repositories/repository_bundle.dart';
import '../services/formatters.dart';
import '../widgets/app_state_scope.dart';
import '../widgets/app_theme.dart';
import '../widgets/async_state_panel.dart';
import '../widgets/page_scaffold.dart';
import '../widgets/repository_scope.dart';
import '../widgets/status_badge.dart';
import 'pig_detail_page.dart';

class AlarmRecordsPage extends StatefulWidget {
  const AlarmRecordsPage({super.key});

  @override
  State<AlarmRecordsPage> createState() => _AlarmRecordsPageState();
}

class _AlarmRecordsPageState extends State<AlarmRecordsPage> {
  RepositoryBundle? _repositories;
  _AlarmStatusFilter _statusFilter = _AlarmStatusFilter.all;
  _AlarmSourceFilter _sourceFilter = _AlarmSourceFilter.all;
  List<HealthAlert> _healthAlerts = const [];
  Object? _healthError;
  bool _healthLoading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repositories = RepositoryScope.read(context);
    if (!identical(repositories, _repositories)) {
      _repositories = repositories;
      _loadHealthAlerts();
    }
  }

  Future<void> _loadHealthAlerts() async {
    setState(() {
      _healthLoading = true;
      _healthError = null;
    });
    try {
      final alerts = await _repositories!.healthAlerts.queryAlerts(limit: 500);
      if (!mounted) return;
      setState(() {
        _healthAlerts = alerts;
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
    final operationalRecords =
        state.alarmRecords.where(_matchesOperational).toList();
    final healthRecords = _healthAlerts.where(_matchesHealth).toList();
    final showOperational = _sourceFilter != _AlarmSourceFilter.health;
    final showHealth = _sourceFilter == _AlarmSourceFilter.all ||
        _sourceFilter == _AlarmSourceFilter.health;

    return PageScaffold(
      children: [
        _FilterPanel(
          sourceFilter: _sourceFilter,
          statusFilter: _statusFilter,
          onSourceChanged: (value) => setState(() => _sourceFilter = value),
          onStatusChanged: (value) => setState(() => _statusFilter = value),
          onSimulate: () => _simulate(context),
        ),
        if (showOperational && operationalRecords.isNotEmpty) ...[
          _SectionTitle(
            title: _sourceFilter == _AlarmSourceFilter.all ? '环境与设备告警' : '告警记录',
            count: operationalRecords.length,
          ),
          ...operationalRecords.map((record) => _AlarmCard(record: record)),
        ],
        if (showHealth) ...[
          const SizedBox(height: 2),
          _SectionTitle(title: '猪只健康告警', count: healthRecords.length),
          if (_healthLoading)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (_healthError != null)
            AsyncStatePanel(
              key: const Key('health-alert-error'),
              title: '健康告警加载失败',
              message: '无法从数据库读取单猪健康告警。',
              onRetry: _loadHealthAlerts,
            )
          else if (healthRecords.isEmpty)
            const AsyncStatePanel(
              key: Key('health-alert-empty'),
              title: '暂无猪只健康告警',
              message: '当前筛选条件下没有个体健康风险记录。',
            )
          else
            ...healthRecords.map((alert) => _HealthAlertCard(alert: alert)),
        ],
        if (!_healthLoading &&
            _healthError == null &&
            (!showOperational || operationalRecords.isEmpty) &&
            (!showHealth || healthRecords.isEmpty))
          const AsyncStatePanel(
            title: '暂无告警记录',
            message: '当前来源与状态筛选下没有记录。',
          ),
      ],
    );
  }

  bool _matchesOperational(AlarmRecord record) {
    final statusMatches = switch (_statusFilter) {
      _AlarmStatusFilter.all => true,
      _AlarmStatusFilter.unhandled => record.status == AlarmStatus.unhandled,
      _AlarmStatusFilter.handled => record.status == AlarmStatus.handled,
    };
    if (!statusMatches) return false;
    return switch (_sourceFilter) {
      _AlarmSourceFilter.all => true,
      _AlarmSourceFilter.environment => record.type == AlarmType.environment,
      _AlarmSourceFilter.device => record.type == AlarmType.deviceFault ||
          record.type == AlarmType.feedShortage,
      _AlarmSourceFilter.health => false,
      _AlarmSourceFilter.ai => record.type == AlarmType.aiException,
    };
  }

  bool _matchesHealth(HealthAlert alert) {
    return switch (_statusFilter) {
      _AlarmStatusFilter.all => true,
      _AlarmStatusFilter.unhandled => alert.status == HealthAlertStatus.open,
      _AlarmStatusFilter.handled => alert.status != HealthAlertStatus.open,
    };
  }

  Future<void> _simulate(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final message = await SmartPigfarmScope.read(context).simulateAlarm();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}

enum _AlarmStatusFilter { all, unhandled, handled }

enum _AlarmSourceFilter { all, environment, device, health, ai }

class _FilterPanel extends StatelessWidget {
  const _FilterPanel({
    required this.sourceFilter,
    required this.statusFilter,
    required this.onSourceChanged,
    required this.onStatusChanged,
    required this.onSimulate,
  });

  final _AlarmSourceFilter sourceFilter;
  final _AlarmStatusFilter statusFilter;
  final ValueChanged<_AlarmSourceFilter> onSourceChanged;
  final ValueChanged<_AlarmStatusFilter> onStatusChanged;
  final VoidCallback onSimulate;

  @override
  Widget build(BuildContext context) {
    const sourceLabels = {
      _AlarmSourceFilter.all: '全部来源',
      _AlarmSourceFilter.environment: '环境告警',
      _AlarmSourceFilter.device: '设备告警',
      _AlarmSourceFilter.health: '猪只健康',
      _AlarmSourceFilter.ai: '行为分析',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '告警中心',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: '生成环境告警',
                  onPressed: onSimulate,
                  icon: const Icon(Icons.add_alert_outlined),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: sourceLabels.entries
                  .map(
                    (entry) => ChoiceChip(
                      label: Text(entry.value),
                      selected: sourceFilter == entry.key,
                      onSelected: (_) => onSourceChanged(entry.key),
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 10),
            SegmentedButton<_AlarmStatusFilter>(
              selected: {statusFilter},
              onSelectionChanged: (selected) => onStatusChanged(selected.first),
              segments: const [
                ButtonSegment(
                  value: _AlarmStatusFilter.all,
                  label: Text('全部'),
                ),
                ButtonSegment(
                  value: _AlarmStatusFilter.unhandled,
                  label: Text('未处理'),
                ),
                ButtonSegment(
                  value: _AlarmStatusFilter.handled,
                  label: Text('已处理'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
        ),
        StatusBadge(label: '$count 条', color: AppTheme.secondary),
      ],
    );
  }
}

class _AlarmCard extends StatelessWidget {
  const _AlarmCard({required this.record});

  final AlarmRecord record;

  @override
  Widget build(BuildContext context) {
    final state = SmartPigfarmScope.watch(context);
    final canHandle = state.can(Permission.alarmHandle);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    record.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                const SizedBox(width: 8),
                StatusBadge.alarmLevel(record.level),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                StatusBadge(
                  label: record.type.label,
                  color: AppTheme.secondary,
                ),
                StatusBadge.alarmStatus(record.status),
                StatusBadge(
                  label: '猪舍 ${record.pigHouseId}',
                  color: AppTheme.primary,
                ),
              ],
            ),
            const SizedBox(height: 8),
            _FieldRow(label: '时间', value: formatDateTime(record.time)),
            _FieldRow(label: '当前值', value: record.currentValue),
            _FieldRow(label: '阈值', value: record.threshold),
            if (record.status == AlarmStatus.unhandled)
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed:
                      canHandle ? () => _handle(context, record.id) : null,
                  icon: const Icon(Icons.task_alt),
                  label: const Text('标记处理'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handle(BuildContext context, String id) async {
    final messenger = ScaffoldMessenger.of(context);
    final message = await SmartPigfarmScope.read(context).markAlarmHandled(id);
    messenger.showSnackBar(SnackBar(content: Text(message)));
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
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PigDetailPage(pigId: alert.pigId),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: color,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${alert.pigId} · ${alert.alertType.label}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      alert.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${formatDateTime(alert.createdAt)} · 偏离 ${alert.deviationPercent.abs().toStringAsFixed(1)}% · ${alert.pigHouseId}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppTheme.textMuted,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              StatusBadge(
                label: alert.severity.label,
                color: color,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: const Color(0xFF8EA39B),
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
