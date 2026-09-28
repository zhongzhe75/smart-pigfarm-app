import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_pigfarm_app/camera/camera_config.dart';
import 'package:smart_pigfarm_app/camera/camera_controller.dart';
import 'package:smart_pigfarm_app/camera/camera_state.dart';
import 'package:smart_pigfarm_app/camera/camera_status.dart';
import 'package:smart_pigfarm_app/camera/unsupported_camera_controller.dart';
import 'package:smart_pigfarm_app/data_source/mock_data_source.dart';
import 'package:smart_pigfarm_app/models/pig_daily_stat.dart';
import 'package:smart_pigfarm_app/pages/dashboard_page.dart';
import 'package:smart_pigfarm_app/pages/video_ai_page.dart';
import 'package:smart_pigfarm_app/repositories/in_memory_repository_store.dart';
import 'package:smart_pigfarm_app/repositories/pig_repository.dart';
import 'package:smart_pigfarm_app/repositories/repository_bundle.dart';
import 'package:smart_pigfarm_app/services/app_state.dart';
import 'package:smart_pigfarm_app/services/pig_farm_seed_data_generator.dart';
import 'package:smart_pigfarm_app/widgets/app_state_scope.dart';
import 'package:smart_pigfarm_app/widgets/app_theme.dart';
import 'package:smart_pigfarm_app/widgets/repository_scope.dart';

void main() {
  final seedData = PigFarmSeedDataGenerator().generate(
    endDate: DateTime.utc(2026, 9, 17),
  );

  testWidgets('missing camera configuration does not crash', (tester) async {
    final controller = _FakeCameraController(
      _state(
        CameraStatus.unconfigured,
        configured: false,
        missingKeys: const ['EZVIZ_ACCESS_TOKEN'],
      ),
    );
    await _pumpVideoPage(tester, seedData, controller);

    expect(find.byKey(const Key('camera-status-unconfigured')), findsOneWidget);
    expect(find.text('实时监控暂未配置'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  final statusCases = <(CameraStatus, Key, String)>[
    (
      CameraStatus.connecting,
      const Key('camera-status-connecting'),
      '正在连接 H6c 实时视频',
    ),
    (
      CameraStatus.offline,
      const Key('camera-status-offline'),
      '摄像头当前离线',
    ),
    (
      CameraStatus.tokenExpired,
      const Key('camera-status-token-expired'),
      '视频授权已过期',
    ),
    (
      CameraStatus.verifyCodeRequired,
      const Key('camera-status-verify-code'),
      '设备视频加密验证失败',
    ),
  ];

  for (final statusCase in statusCases) {
    testWidgets('${statusCase.$1.name} camera state renders correctly',
        (tester) async {
      final controller = _FakeCameraController(_state(statusCase.$1));
      await _pumpVideoPage(tester, seedData, controller);

      expect(find.byKey(statusCase.$2), findsOneWidget);
      expect(find.text(statusCase.$3), findsOneWidget);
    });
  }

  testWidgets('playing camera state renders live video chrome', (tester) async {
    final controller = _FakeCameraController(_state(CameraStatus.playing));
    await _pumpVideoPage(tester, seedData, controller);

    expect(find.text('LIVE · H6c'), findsOneWidget);
    expect(find.text('实时监控 · H6c'), findsWidgets);
  });

  testWidgets('camera error can be retried', (tester) async {
    final controller = _FakeCameraController(
      _state(CameraStatus.error, lastError: 'SDK 错误 500000：测试错误'),
    );
    await _pumpVideoPage(tester, seedData, controller);

    await tester.tap(find.byKey(const Key('camera-retry-button')));
    await tester.pump();

    expect(controller.retryCount, 1);
    expect(find.text('正在连接 H6c 实时视频'), findsOneWidget);
  });

  testWidgets('unsupported platform does not load the Android camera view',
      (tester) async {
    final controller = _FakeCameraController(const CameraState(
      status: CameraStatus.unconfigured,
      config: CameraConfig.unsupported(),
    ));
    await _pumpVideoPage(tester, seedData, controller);

    expect(find.byKey(const Key('camera-status-web')), findsOneWidget);
    expect(find.text('实时监控仅在现场终端启用。'), findsOneWidget);
    expect(find.byKey(const Key('camera-native-view')), findsNothing);
  });

  test('web-safe controller never requests a platform view', () async {
    final controller = UnsupportedCameraController();
    await controller.initialize();

    expect(controller.requiresPlatformView, isFalse);
    expect(controller.state.config.platformSupported, isFalse);
    expect(controller.state.status, CameraStatus.unconfigured);
    controller.dispose();
  });

  testWidgets('Dashboard renders only a lightweight H6c summary',
      (tester) async {
    final store = InMemoryRepositoryStore(seedData);
    final repositories = _bundle(store);
    final appState = AppState(
      dataSource: MockDataSource(),
      enableRealtimeLoop: false,
    );
    await tester.runAsync(appState.initialize);
    addTearDown(appState.dispose);
    await _pumpPage(
      tester,
      repositories,
      const DashboardPage(),
      appState: appState,
      surfaceSize: const Size(430, 1800),
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('dashboard-camera-summary')),
      360,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('dashboard-camera-summary')), findsOneWidget);
    expect(find.text('视频监控'), findsOneWidget);
    expect(find.byKey(const Key('camera-native-view')), findsNothing);
  });

  testWidgets('tapping an attention pig opens PigDetailPage', (tester) async {
    final store = InMemoryRepositoryStore(seedData);
    final priority = (await store.queryPigSummaries(
      pigHouseId: 'A01',
      healthStatus: RiskLevel.high,
      sort: PigSummarySort.healthScoreAscending,
      limit: 1,
    ))
        .first;
    final controller = _FakeCameraController(_state(CameraStatus.playing));
    await _pumpVideoPage(
      tester,
      seedData,
      controller,
      store: store,
      surfaceSize: const Size(430, 1000),
    );

    final pigCard = find.byKey(Key('video-attention-${priority.pig.id}'));
    await tester.scrollUntilVisible(
      pigCard,
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(pigCard);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pig-digital-profile')), findsOneWidget);
    expect(find.text(priority.pig.id), findsWidgets);
  });

  testWidgets('disposing VideoAiPage releases its camera controller',
      (tester) async {
    final controller = _FakeCameraController(_state(CameraStatus.playing));
    await _pumpVideoPage(tester, seedData, controller);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(controller.releaseCount, 1);
  });
}

CameraState _state(
  CameraStatus status, {
  bool configured = true,
  List<String> missingKeys = const [],
  String? lastError,
}) {
  return CameraState(
    status: status,
    config: CameraConfig(
      platformSupported: true,
      configured: configured,
      missingKeys: missingKeys,
      sdkVersion: 'test',
    ),
    lastError: lastError,
  );
}

Future<void> _pumpVideoPage(
  WidgetTester tester,
  PigFarmSeedData seedData,
  _FakeCameraController controller, {
  InMemoryRepositoryStore? store,
  Size surfaceSize = const Size(430, 900),
}) async {
  final activeStore = store ?? InMemoryRepositoryStore(seedData);
  await _pumpPage(
    tester,
    _bundle(activeStore),
    VideoAiPage(cameraControllerFactory: () => controller),
    surfaceSize: surfaceSize,
  );
}

Future<void> _pumpPage(
  WidgetTester tester,
  RepositoryBundle repositories,
  Widget page, {
  AppState? appState,
  Size surfaceSize = const Size(430, 900),
}) async {
  await tester.binding.setSurfaceSize(surfaceSize);
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
    await repositories.dispose();
  });
  Widget app = RepositoryScope(
    repositories: repositories,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: Scaffold(body: page),
    ),
  );
  if (appState != null) {
    app = SmartPigfarmScope(notifier: appState, child: app);
  }
  await tester.pumpWidget(app);
  for (var index = 0; index < 12; index++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

RepositoryBundle _bundle(InMemoryRepositoryStore store) {
  return RepositoryBundle(
    pigs: store,
    pigMetrics: store,
    healthAlerts: store,
    environment: store,
    aiBehavior: store,
    dispose: store.close,
  );
}

class _FakeCameraController extends CameraController {
  _FakeCameraController(this._state);

  CameraState _state;
  int retryCount = 0;
  int releaseCount = 0;

  @override
  bool get requiresPlatformView => false;

  @override
  CameraState get state => _state;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> attachPlatformView(int viewId) async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> release() async {
    releaseCount++;
  }

  @override
  Future<void> resume() async {}

  @override
  Future<void> retry() async {
    retryCount++;
    _state = CameraState(
      status: CameraStatus.connecting,
      config: _state.config,
    );
    notifyListeners();
  }
}
