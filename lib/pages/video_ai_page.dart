import 'dart:async';

import 'package:flutter/material.dart';

import '../camera/camera_controller.dart';
import '../camera/camera_controller_factory.dart';
import '../camera/camera_state.dart';
import '../camera/camera_status.dart';
import '../camera/camera_view.dart';
import '../config/runtime_mode.dart';
import '../models/ai_behavior_record.dart';
import '../models/health_alert.dart';
import '../models/herd_daily_aggregate.dart';
import '../models/pig_daily_stat.dart';
import '../models/pig_summary.dart';
import '../repositories/pig_repository.dart';
import '../repositories/repository_bundle.dart';
import '../services/formatters.dart';
import '../widgets/app_theme.dart';
import '../widgets/app_surface_card.dart';
import '../widgets/async_state_panel.dart';
import '../widgets/local_video_player.dart';
import '../widgets/page_scaffold.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/repository_scope.dart';
import '../widgets/status_badge.dart';
import 'pig_detail_page.dart';

class VideoAiPage extends StatefulWidget {
  const VideoAiPage({
    super.key,
    this.cameraControllerFactory,
    this.runtimeMode,
    this.showHeader = true,
  });

  final CameraControllerFactory? cameraControllerFactory;
  final RuntimeMode? runtimeMode;
  final bool showHeader;

  @override
  State<VideoAiPage> createState() => _VideoAiPageState();
}

class _VideoAiPageState extends State<VideoAiPage> with WidgetsBindingObserver {
  CameraController? _cameraController;
  late final RuntimeMode _runtimeMode;
  RepositoryBundle? _repositories;
  _VideoAiData? _data;
  Object? _dataError;
  bool _dataLoading = true;

  @override
  void initState() {
    super.initState();
    _runtimeMode = widget.runtimeMode?.resolve() ??
        (widget.cameraControllerFactory != null
            ? RuntimeMode.padLive
            : RuntimeConfig.current);
    if (_runtimeMode.usesLiveCamera) {
      WidgetsBinding.instance.addObserver(this);
      final controller =
          widget.cameraControllerFactory?.call() ?? createCameraController();
      _cameraController = controller;
      controller.addListener(_onCameraChanged);
      unawaited(controller.initialize());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repositories = RepositoryScope.read(context);
    if (!identical(_repositories, repositories)) {
      _repositories = repositories;
      unawaited(_loadBusinessData());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _cameraController;
    if (controller == null) return;
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(controller.resume());
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        unawaited(controller.pause());
    }
  }

  void _onCameraChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadBusinessData() async {
    final repositories = _repositories;
    if (repositories == null) return;
    setState(() {
      _dataLoading = true;
      _dataError = null;
    });
    try {
      final aggregate = await repositories.pigMetrics
          .getLatestHerdAggregate(pigHouseId: 'A01');
      if (aggregate == null) {
        if (!mounted) return;
        setState(() {
          _data = const _VideoAiData.empty();
          _dataLoading = false;
        });
        return;
      }
      final dayStart = DateTime.utc(
        aggregate.date.year,
        aggregate.date.month,
        aggregate.date.day,
      );
      final dayEnd = dayStart.add(const Duration(days: 1));
      final results = await Future.wait<Object>([
        repositories.pigs.queryPigSummaries(
          pigHouseId: 'A01',
          sort: PigSummarySort.healthScoreAscending,
          limit: 60,
        ),
        repositories.healthAlerts.queryAlerts(
          status: HealthAlertStatus.open,
          from: dayStart,
          to: dayEnd,
          limit: 500,
        ),
        repositories.aiBehavior.queryBehaviorRecords(
          from: dayStart,
          to: dayEnd,
        ),
      ]);
      final summaries = (results[0] as List<PigSummary>)
          .where((item) => item.latestStat != null)
          .toList(growable: false);
      final priority = summaries
          .where((item) => item.latestStat!.riskLevel != RiskLevel.normal)
          .take(6)
          .toList(growable: false);
      final alerts = (results[1] as List<HealthAlert>)
          .where((item) => item.pigHouseId == 'A01')
          .toList(growable: false);
      final behaviors = (results[2] as List<AiBehaviorRecord>)
          .where((item) => item.pigHouseId == 'A01')
          .toList(growable: false);
      final attention = await Future.wait(
        priority.map((summary) => _buildAttention(summary, alerts)),
      );
      if (!mounted) return;
      setState(() {
        _data = _VideoAiData(
          aggregate: aggregate,
          attention: attention,
          alerts: alerts.take(5).toList(growable: false),
          behaviors: behaviors.take(8).toList(growable: false),
        );
        _dataLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _dataError = error;
        _dataLoading = false;
      });
    }
  }

  Future<_PigAttention> _buildAttention(
    PigSummary summary,
    List<HealthAlert> alerts,
  ) async {
    final latest = summary.latestStat!;
    final history = await _repositories!.pigMetrics.queryDailyStats(
      pigId: summary.pig.id,
      from: latest.date.subtract(const Duration(days: 7)),
      to: latest.date,
    );
    final baseline = history
        .where((item) => item.date.isBefore(latest.date))
        .toList(growable: false);
    final baselineActivity = _average(
      baseline.map((item) => item.activityDistanceMeters),
    );
    final baselineFeed = _average(baseline.map((item) => item.feedAmountKg));
    return _PigAttention(
      summary: summary,
      activityDropPercent:
          _dropPercent(latest.activityDistanceMeters, baselineActivity),
      feedDropPercent: _dropPercent(latest.feedAmountKg, baselineFeed),
      alerts: alerts
          .where((item) => item.pigId == summary.pig.id)
          .toList(growable: false),
    );
  }

  double _average(Iterable<double> values) {
    final list = values.toList(growable: false);
    return list.isEmpty ? 0 : list.reduce((a, b) => a + b) / list.length;
  }

  double _dropPercent(double current, double baseline) {
    if (baseline <= 0 || current >= baseline) return 0;
    return (baseline - current) / baseline * 100;
  }

  @override
  void dispose() {
    final controller = _cameraController;
    if (controller != null) {
      WidgetsBinding.instance.removeObserver(this);
      controller.removeListener(_onCameraChanged);
      unawaited(controller.release());
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _cameraController;
    final player = _runtimeMode.usesLiveCamera && controller != null
        ? _CameraPanel(controller: controller)
        : const LocalVideoPlayer();
    final businessPanel = _dataLoading
        ? const AppSurfaceCard(
            child: Center(child: CircularProgressIndicator()),
          )
        : _dataError != null
            ? AsyncStatePanel(
                key: const Key('video-business-error'),
                title: '智慧养殖数据加载失败',
                message: '视频状态不受影响，可以重试业务数据加载。',
                onRetry: _loadBusinessData,
              )
            : _VideoSidePanel(data: _data ?? const _VideoAiData.empty());
    return PageScaffold(
      children: [
        if (widget.showHeader)
          _PageHeader(
            runtimeMode: _runtimeMode,
            cameraState: controller?.state,
          ),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < AppBreakpoints.tablet) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  player,
                  const SizedBox(height: 16),
                  businessPanel,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 68, child: player),
                const SizedBox(width: 20),
                Expanded(flex: 32, child: businessPanel),
              ],
            );
          },
        ),
        if (!_dataLoading && _dataError == null && _data != null)
          LayoutBuilder(
            builder: (context, constraints) {
              final behavior = _BehaviorSection(behaviors: _data!.behaviors);
              final alerts = _HealthAlertSection(alerts: _data!.alerts);
              if (constraints.maxWidth < AppBreakpoints.phone) {
                return Column(
                  children: [behavior, const SizedBox(height: 20), alerts],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: behavior),
                  const SizedBox(width: 20),
                  Expanded(child: alerts),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _VideoSidePanel extends StatelessWidget {
  const _VideoSidePanel({required this.data});

  final _VideoAiData data;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HealthOverview(data: data),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 18),
          _AttentionSection(attention: data.attention.take(4).toList()),
        ],
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.runtimeMode,
    required this.cameraState,
  });

  final RuntimeMode runtimeMode;
  final CameraState? cameraState;

  @override
  Widget build(BuildContext context) {
    final state = cameraState;
    if (!runtimeMode.usesLiveCamera || state == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '猪舍智能视频监控',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusBadge(
                label: '猪舍 A01',
                color: AppTheme.secondary,
                icon: Icons.home_work_outlined,
              ),
              StatusBadge(
                label: '本地监控视频',
                color: AppTheme.secondary,
                icon: Icons.video_library_outlined,
              ),
            ],
          ),
        ],
      );
    }
    final deviceColor = switch (state.status) {
      CameraStatus.playing => AppTheme.primary,
      CameraStatus.offline => AppTheme.danger,
      CameraStatus.unconfigured => AppTheme.warning,
      _ => AppTheme.secondary,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '猪舍智能视频监控',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            const StatusBadge(
              label: '猪舍 A01',
              color: AppTheme.secondary,
              icon: Icons.home_work_outlined,
            ),
            StatusBadge(
              label: '实时监控 · H6c',
              color: deviceColor,
              icon: Icons.videocam_outlined,
            ),
          ],
        ),
      ],
    );
  }
}

class _CameraPanel extends StatelessWidget {
  const _CameraPanel({required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF050C0A),
            border: Border.all(color: AppTheme.border),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (controller.requiresPlatformView)
                CameraView(
                  key: const Key('camera-native-view'),
                  controller: controller,
                )
              else
                CustomPaint(painter: _CameraGridPainter()),
              if (state.status != CameraStatus.playing)
                ColoredBox(
                  color: const Color(0xD9050C0A),
                  child: _CameraStateContent(
                    state: state,
                    onRetry: controller.retry,
                  ),
                ),
              Positioned(
                left: 10,
                top: 10,
                child: StatusBadge(
                  label: state.status == CameraStatus.playing
                      ? 'LIVE · H6c'
                      : state.status.label,
                  color: state.status == CameraStatus.playing
                      ? AppTheme.primary
                      : AppTheme.secondary,
                  icon: state.status == CameraStatus.playing
                      ? Icons.fiber_manual_record
                      : Icons.videocam_outlined,
                ),
              ),
              if (state.status == CameraStatus.playing)
                const Positioned(
                  right: 10,
                  bottom: 10,
                  child: StatusBadge(
                    label: '实时监控 · H6c',
                    color: AppTheme.secondary,
                    icon: Icons.videocam_outlined,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CameraStateContent extends StatelessWidget {
  const _CameraStateContent({required this.state, required this.onRetry});

  final CameraState state;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final (title, message, icon, key) = switch (state.status) {
      CameraStatus.unconfigured when !state.config.platformSupported => (
          '当前使用本地监控模式',
          '实时监控仅在现场终端启用。',
          Icons.devices_outlined,
          const Key('camera-status-web'),
        ),
      CameraStatus.unconfigured => (
          '实时监控暂未配置',
          '请联系现场管理员完成视频授权配置。',
          Icons.settings_input_component_outlined,
          const Key('camera-status-unconfigured'),
        ),
      CameraStatus.initializing => (
          '正在准备实时监控',
          '正在检查视频授权并准备画面…',
          Icons.hourglass_top,
          const Key('camera-status-initializing'),
        ),
      CameraStatus.connecting => (
          '正在连接 H6c 实时视频',
          '正在建立安全视频连接…',
          Icons.sync,
          const Key('camera-status-connecting'),
        ),
      CameraStatus.offline => (
          '摄像头当前离线',
          state.lastError ?? '请检查 H6c 电源和网络连接。',
          Icons.videocam_off_outlined,
          const Key('camera-status-offline'),
        ),
      CameraStatus.tokenExpired => (
          '视频授权已过期',
          '请联系管理员更新视频授权后重试。',
          Icons.key_off_outlined,
          const Key('camera-status-token-expired'),
        ),
      CameraStatus.verifyCodeRequired => (
          '设备视频加密验证失败',
          state.lastError ?? '请检查本机设备验证码配置。',
          Icons.lock_outline,
          const Key('camera-status-verify-code'),
        ),
      CameraStatus.error => (
          '实时视频连接失败',
          state.lastError ?? '萤石播放器发生未知错误。',
          Icons.error_outline,
          const Key('camera-status-error'),
        ),
      CameraStatus.playing => (
          '',
          '',
          Icons.videocam,
          const Key('camera-status-playing'),
        ),
    };
    final canRetry = switch (state.status) {
      CameraStatus.offline ||
      CameraStatus.tokenExpired ||
      CameraStatus.verifyCodeRequired ||
      CameraStatus.error =>
        true,
      _ => false,
    };
    final loading = state.status == CameraStatus.initializing ||
        state.status == CameraStatus.connecting;
    return Center(
      key: key,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              const SizedBox(
                width: 34,
                height: 34,
                child: CircularProgressIndicator(strokeWidth: 3),
              )
            else
              Icon(icon, color: AppTheme.primary, size: 42),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFFA7BDB5),
                  ),
            ),
            if (canRetry) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const Key('camera-retry-button'),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('重新连接'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HealthOverview extends StatelessWidget {
  const _HealthOverview({required this.data});

  final _VideoAiData data;

  @override
  Widget build(BuildContext context) {
    final aggregate = data.aggregate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '当前猪群健康概况',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final responsive = ResponsiveLayout(constraints.maxWidth);
            return GridView.count(
              crossAxisCount: responsive.metricColumns,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: responsive.gridAspectRatio(
                phone: 1.2,
                tablet: 1.45,
                desktop: 1.65,
              ),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _OverviewMetric(
                  label: 'A01 当前猪群',
                  value: '${aggregate?.pigCount ?? 0} 头',
                  color: AppTheme.secondary,
                ),
                _OverviewMetric(
                  label: '今日行为异常',
                  value: '${data.behaviors.length} 条',
                  color: data.behaviors.isEmpty
                      ? AppTheme.primary
                      : AppTheme.warning,
                ),
                _OverviewMetric(
                  label: '重点关注',
                  value: '${aggregate?.watchCount ?? 0} 头',
                  color: AppTheme.warning,
                ),
                _OverviewMetric(
                  label: '高风险',
                  value: '${aggregate?.highRiskCount ?? 0} 头',
                  color: AppTheme.danger,
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _OverviewMetric extends StatelessWidget {
  const _OverviewMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 5),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BehaviorSection extends StatelessWidget {
  const _BehaviorSection({required this.behaviors});

  final List<AiBehaviorRecord> behaviors;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '今日行为异常',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          '结合猪群日统计与健康预警，辅助现场巡检与重点关注。',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFFA7BDB5),
              ),
        ),
        const SizedBox(height: 10),
        if (behaviors.isEmpty)
          const AsyncStatePanel(
            title: '今日暂无行为异常记录',
            message: '当前猪群日统计与健康预警未发现需要重点关注的行为异常。',
            icon: Icons.check_circle_outline,
          )
        else
          ...behaviors.map(
            (behavior) => Card(
              key: Key('ai-behavior-${behavior.id}'),
              child: ListTile(
                leading: const Icon(
                  Icons.visibility_outlined,
                  color: AppTheme.warning,
                ),
                title: Text(
                  '${behavior.pigId} · ${behavior.behaviorLabel}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  '${formatClock(behavior.occurredAt)} · 行为分析记录 · 待现场复核',
                ),
                trailing: const StatusBadge(
                  label: '待复核',
                  color: Color(0xFFA78BFA),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AttentionSection extends StatelessWidget {
  const _AttentionSection({required this.attention});

  final List<_PigAttention> attention;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '重点关注猪只',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 10),
        if (attention.isEmpty)
          const AsyncStatePanel(
            title: '当前无重点关注猪只',
            message: 'A01 猪群今日健康评分均处于正常范围。',
          )
        else
          ...attention.map((item) {
            final stat = item.summary.latestStat!;
            return Card(
              key: Key('video-attention-${item.summary.pig.id}'),
              child: ListTile(
                dense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PigDetailPage(pigId: item.summary.pig.id),
                  ),
                ),
                leading: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: _riskColor(stat.riskLevel),
                    shape: BoxShape.circle,
                  ),
                ),
                title: Text(
                  item.summary.pig.id,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text(
                  '活动量下降 ${item.activityDropPercent.toStringAsFixed(0)}% · '
                  '采食量下降 ${item.feedDropPercent.toStringAsFixed(0)}%',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: AppTheme.textMuted,
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _HealthAlertSection extends StatelessWidget {
  const _HealthAlertSection({required this.alerts});

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
            title: '今日暂无 A01 健康预警',
            message: '预警仍使用 Phase 2 已有健康评分规则。',
          )
        else
          ...alerts.map(
            (alert) => Card(
              key: Key('video-alert-${alert.id}'),
              child: ListTile(
                leading: Icon(
                  Icons.health_and_safety_outlined,
                  color: alert.severity == HealthAlertSeverity.critical
                      ? AppTheme.danger
                      : AppTheme.warning,
                ),
                title: Text(
                  '${alert.pigId} · ${alert.alertType.label}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  '${alert.title} · 偏离 '
                  '${alert.deviationPercent.abs().toStringAsFixed(1)}%',
                ),
                trailing: StatusBadge(
                  label: alert.severity.label,
                  color: alert.severity == HealthAlertSeverity.critical
                      ? AppTheme.danger
                      : AppTheme.warning,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

Color _riskColor(RiskLevel level) {
  return switch (level) {
    RiskLevel.normal => AppTheme.primary,
    RiskLevel.watch => AppTheme.warning,
    RiskLevel.high => AppTheme.danger,
  };
}

class _VideoAiData {
  const _VideoAiData({
    required this.aggregate,
    required this.attention,
    required this.alerts,
    required this.behaviors,
  });

  const _VideoAiData.empty()
      : aggregate = null,
        attention = const [],
        alerts = const [],
        behaviors = const [];

  final HerdDailyAggregate? aggregate;
  final List<_PigAttention> attention;
  final List<HealthAlert> alerts;
  final List<AiBehaviorRecord> behaviors;
}

class _PigAttention {
  const _PigAttention({
    required this.summary,
    required this.activityDropPercent,
    required this.feedDropPercent,
    required this.alerts,
  });

  final PigSummary summary;
  final double activityDropPercent;
  final double feedDropPercent;
  final List<HealthAlert> alerts;
}

class _CameraGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.primary.withValues(alpha: 0.08)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 28) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += 28) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CameraGridPainter oldDelegate) => false;
}
