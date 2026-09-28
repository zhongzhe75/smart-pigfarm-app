import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_pigfarm_app/data_source/mock_data_source.dart';
import 'package:smart_pigfarm_app/models/pig_daily_stat.dart';
import 'package:smart_pigfarm_app/models/pig_summary.dart';
import 'package:smart_pigfarm_app/pages/dashboard_page.dart';
import 'package:smart_pigfarm_app/pages/herd_management_page.dart';
import 'package:smart_pigfarm_app/pages/pig_detail_page.dart';
import 'package:smart_pigfarm_app/repositories/in_memory_repository_store.dart';
import 'package:smart_pigfarm_app/repositories/pig_repository.dart';
import 'package:smart_pigfarm_app/repositories/repository_bundle.dart';
import 'package:smart_pigfarm_app/services/app_state.dart';
import 'package:smart_pigfarm_app/services/pig_farm_seed_data_generator.dart';
import 'package:smart_pigfarm_app/widgets/app_state_scope.dart';
import 'package:smart_pigfarm_app/widgets/app_theme.dart';
import 'package:smart_pigfarm_app/widgets/repository_scope.dart';

void main() {
  final endDate = DateTime.utc(2026, 9, 17);
  late PigFarmSeedData seedData;

  setUpAll(() {
    seedData = PigFarmSeedDataGenerator().generate(endDate: endDate);
  });

  testWidgets('HerdManagementPage loads 180 pigs', (tester) async {
    final repositories = _bundle(InMemoryRepositoryStore(seedData));
    await _pumpRepositoryPage(
      tester,
      repositories: repositories,
      page: const HerdManagementPage(),
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('herd-loaded-count')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('已加载 180 头'), findsOneWidget);
    expect(find.byKey(const Key('herd-management-scroll')), findsOneWidget);
  });

  testWidgets('searching PIG-037 returns one pig', (tester) async {
    final repositories = _bundle(InMemoryRepositoryStore(seedData));
    await _pumpRepositoryPage(
      tester,
      repositories: repositories,
      page: const HerdManagementPage(),
    );

    await tester.enterText(
      find.byKey(const Key('herd-search-field')),
      'PIG-037',
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('herd-loaded-count')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('已加载 1 头'), findsOneWidget);
    expect(find.byKey(const Key('pig-card-PIG-037')), findsOneWidget);
  });

  testWidgets('PigDetailPage can query the 90 day range', (tester) async {
    final repositories = _bundle(InMemoryRepositoryStore(seedData));
    await _pumpRepositoryPage(
      tester,
      repositories: repositories,
      page: const PigDetailPage(pigId: 'PIG-037'),
    );

    expect(find.byKey(const Key('pig-digital-profile')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('pig-range-selector')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('90天'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('90天'));
    await tester.pumpAndSettle();

    expect(find.text('已加载 90 天记录'), findsOneWidget);
  });

  testWidgets('high risk pig detail displays a health alert', (tester) async {
    final store = InMemoryRepositoryStore(seedData);
    final highRisk = (await store.queryPigSummaries(
      healthStatus: RiskLevel.high,
      sort: PigSummarySort.healthScoreAscending,
      limit: 20,
    ))
        .first;
    final alerts = await store.queryAlerts(pigId: highRisk.pig.id);
    expect(alerts, isNotEmpty);

    await _pumpRepositoryPage(
      tester,
      repositories: _bundle(store),
      page: PigDetailPage(pigId: highRisk.pig.id),
    );

    expect(find.text('高风险'), findsWidgets);
    await tester.scrollUntilVisible(
      find.byKey(Key('health-alert-${alerts.first.id}')),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(Key('health-alert-${alerts.first.id}')), findsOneWidget);
  });

  testWidgets('Dashboard health count matches repository aggregate',
      (tester) async {
    final store = InMemoryRepositoryStore(seedData);
    final aggregate = await store.getLatestHerdAggregate();
    final repositories = _bundle(store);
    final appState = AppState(
      dataSource: MockDataSource(),
      enableRealtimeLoop: false,
    );
    await tester.runAsync(appState.initialize);
    addTearDown(appState.dispose);

    await _pumpRepositoryPage(
      tester,
      repositories: repositories,
      page: const DashboardPage(),
      appState: appState,
      surfaceSize: const Size(430, 3000),
    );

    final countCard = find.byKey(const Key('dashboard-health-pig-count'));
    expect(countCard, findsOneWidget);
    expect(
      find.descendant(
        of: countCard,
        matching: find.text('${aggregate!.pigCount}'),
      ),
      findsOneWidget,
    );
    expect(find.text('全场 · A01 / A02 / A03'), findsOneWidget);
    expect(find.text('全场概览'), findsOneWidget);
  });

  testWidgets('empty repository renders an empty state without crashing',
      (tester) async {
    final repositories = _bundle(
      InMemoryRepositoryStore(_emptySeedData()),
    );
    await _pumpRepositoryPage(
      tester,
      repositories: repositories,
      page: const HerdManagementPage(),
    );

    expect(find.byKey(const Key('herd-empty-state')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('repository exception renders a retryable error state',
      (tester) async {
    final repositories = _bundle(
      _ThrowingInMemoryStore(_emptySeedData()),
    );
    await _pumpRepositoryPage(
      tester,
      repositories: repositories,
      page: const HerdManagementPage(),
    );

    expect(find.byKey(const Key('herd-error-state')), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpRepositoryPage(
  WidgetTester tester, {
  required RepositoryBundle repositories,
  required Widget page,
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
  if (appState == null) {
    await tester.pumpAndSettle();
  } else {
    for (var index = 0; index < 5; index++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
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

PigFarmSeedData _emptySeedData() {
  return const PigFarmSeedData(
    pigs: [],
    dailyStats: [],
    healthAlerts: [],
    immunizations: [],
    environmentRecords: [],
  );
}

class _ThrowingInMemoryStore extends InMemoryRepositoryStore {
  _ThrowingInMemoryStore(super.data);

  @override
  Future<List<PigSummary>> queryPigSummaries({
    String? numberQuery,
    String? pigHouseId,
    RiskLevel? healthStatus,
    PigSummarySort sort = PigSummarySort.id,
    int limit = 50,
    int offset = 0,
  }) {
    return Future.error(StateError('repository unavailable'));
  }
}
