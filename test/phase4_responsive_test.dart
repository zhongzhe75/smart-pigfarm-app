import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_pigfarm_app/config/runtime_mode.dart';
import 'package:smart_pigfarm_app/data_source/mock_data_source.dart';
import 'package:smart_pigfarm_app/models/user_role.dart';
import 'package:smart_pigfarm_app/pages/app_shell.dart';
import 'package:smart_pigfarm_app/pages/pig_detail_page.dart';
import 'package:smart_pigfarm_app/pages/video_ai_page.dart';
import 'package:smart_pigfarm_app/repositories/in_memory_repository_store.dart';
import 'package:smart_pigfarm_app/repositories/repository_bundle.dart';
import 'package:smart_pigfarm_app/services/app_state.dart';
import 'package:smart_pigfarm_app/services/pig_farm_seed_data_generator.dart';
import 'package:smart_pigfarm_app/widgets/app_state_scope.dart';
import 'package:smart_pigfarm_app/widgets/app_theme.dart';
import 'package:smart_pigfarm_app/widgets/repository_scope.dart';
import 'package:smart_pigfarm_app/widgets/responsive_layout.dart';

void main() {
  test('RuntimeMode auto selects local Web and live Android', () {
    expect(
      RuntimeMode.auto.resolve(
        isWeb: true,
        platform: TargetPlatform.android,
      ),
      RuntimeMode.webLocal,
    );
    expect(
      RuntimeMode.auto.resolve(
        isWeb: false,
        platform: TargetPlatform.android,
      ),
      RuntimeMode.padLive,
    );
    expect(RuntimeMode.padLocal.resolve(), RuntimeMode.padLocal);
    expect(RuntimeMode.webLive.usesLiveCamera, isTrue);
    expect(RuntimeMode.webLive.usesLocalVideo, isFalse);
    expect(RuntimeMode.webLocal.usesLocalVideo, isTrue);
    expect(RuntimeMode.webLocal.usesLiveCamera, isFalse);
  });

  final cases = <(double, AppWindowClass, int, bool)>[
    (390, AppWindowClass.phone, 2, false),
    (600, AppWindowClass.smallTablet, 2, false),
    (800, AppWindowClass.smallTablet, 2, false),
    (1024, AppWindowClass.largeTablet, 4, true),
    (1280, AppWindowClass.desktop, 4, true),
  ];

  for (final testCase in cases) {
    final width = testCase.$1;
    testWidgets(
      'Phase 4 pages fit ${width.toInt()}px and keep video at 16:9',
      (tester) async {
        final responsive = ResponsiveLayout(width);
        expect(responsive.windowClass, testCase.$2);
        expect(responsive.metricColumns, testCase.$3);

        await tester.binding.setSurfaceSize(Size(width, 1800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final store = InMemoryRepositoryStore(
          PigFarmSeedDataGenerator().generate(
            endDate: DateTime.utc(2026, 9, 17),
          ),
        );
        final repositories = _bundle(store);
        final appState = AppState(
          dataSource: MockDataSource(),
          enableRealtimeLoop: false,
        );
        await tester.runAsync(appState.initialize);
        appState.login(UserRole.manager);
        addTearDown(() async {
          appState.dispose();
          await repositories.dispose();
        });

        await tester.pumpWidget(
          _testApp(
            repositories: repositories,
            appState: appState,
            child: const AppShell(),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(NavigationRail),
            testCase.$4 ? findsOneWidget : findsNothing);
        expect(find.byType(NavigationBar),
            testCase.$4 ? findsNothing : findsOneWidget);
        if (width >= 800) {
          expect(
            tester
                .getSize(find.byKey(const Key('dashboard-overview-strip')))
                .height,
            lessThanOrEqualTo(160),
          );
        }
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(
          _testApp(
            repositories: repositories,
            appState: appState,
            child: const PigDetailPage(pigId: 'PIG-037'),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('pig-trend-chart')), findsOneWidget);
        if (width >= 900) {
          final chartHeight =
              tester.getSize(find.byKey(const Key('pig-trend-chart'))).height;
          expect(chartHeight, inInclusiveRange(250, 300));
        }
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(
          _testApp(
            repositories: repositories,
            appState: appState,
            child: const Scaffold(
              body: VideoAiPage(runtimeMode: RuntimeMode.padLocal),
            ),
          ),
        );
        // The local video widget may keep a platform progress indicator active;
        // finite pumps validate layout without waiting for an idle frame.
        await tester.pump();
        await tester.pump(const Duration(seconds: 2));
        final videoSize = tester.getSize(
          find.byKey(const Key('local-video-aspect-ratio')),
        );
        expect(videoSize.width / videoSize.height, closeTo(16 / 9, 0.01));
        expect(find.byType(VideoAiPage), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Widget _testApp({
  required RepositoryBundle repositories,
  required AppState appState,
  required Widget child,
}) {
  return RepositoryScope(
    repositories: repositories,
    child: SmartPigfarmScope(
      notifier: appState,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        home: child,
      ),
    ),
  );
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
