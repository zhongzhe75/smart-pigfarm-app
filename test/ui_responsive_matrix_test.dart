import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_pigfarm_app/data_source/mock_data_source.dart';
import 'package:smart_pigfarm_app/models/user_role.dart';
import 'package:smart_pigfarm_app/pages/alarm_records_page.dart';
import 'package:smart_pigfarm_app/pages/herd_management_page.dart';
import 'package:smart_pigfarm_app/pages/login_page.dart';
import 'package:smart_pigfarm_app/pages/more_page.dart';
import 'package:smart_pigfarm_app/pages/permission_page.dart';
import 'package:smart_pigfarm_app/pages/realtime_monitor_page.dart';
import 'package:smart_pigfarm_app/pages/remote_control_page.dart';
import 'package:smart_pigfarm_app/pages/report_page.dart';
import 'package:smart_pigfarm_app/pages/threshold_settings_page.dart';
import 'package:smart_pigfarm_app/repositories/in_memory_repository_store.dart';
import 'package:smart_pigfarm_app/repositories/repository_bundle.dart';
import 'package:smart_pigfarm_app/services/app_state.dart';
import 'package:smart_pigfarm_app/services/pig_farm_seed_data_generator.dart';
import 'package:smart_pigfarm_app/widgets/app_state_scope.dart';
import 'package:smart_pigfarm_app/widgets/app_theme.dart';
import 'package:smart_pigfarm_app/widgets/repository_scope.dart';

void main() {
  const sizes = <Size>[
    Size(390, 844),
    Size(600, 960),
    Size(800, 600),
    Size(1024, 768),
    Size(1280, 800),
  ];

  for (final size in sizes) {
    testWidgets(
        'all management pages avoid overflow at ${size.width.toInt()}px',
        (tester) async {
      await tester.binding.setSurfaceSize(size);
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

      final pages = <Widget>[
        const RealtimeMonitorPage(),
        const RemoteControlPage(),
        const HerdManagementPage(),
        const AlarmRecordsPage(),
        const ReportPage(),
        const ThresholdSettingsPage(),
        const PermissionPage(),
        const MorePage(),
        const LoginPage(),
      ];

      for (final page in pages) {
        await tester.pumpWidget(
          RepositoryScope(
            repositories: repositories,
            child: SmartPigfarmScope(
              notifier: appState,
              child: MaterialApp(
                theme: AppTheme.dark(),
                home: Scaffold(body: page),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: '${page.runtimeType} overflowed at ${size.width}px');
        if (page is MorePage && size.width >= 600) {
          final card = find.byKey(const Key('more-entry-/thresholds'));
          expect(tester.getSize(card).height, inInclusiveRange(120, 150));
        }

        final scrollable = find.byType(Scrollable);
        if (scrollable.evaluate().isNotEmpty) {
          await tester.drag(scrollable.first, const Offset(0, -600));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull,
              reason:
                  '${page.runtimeType} overflowed after scroll at ${size.width}px');
          if (page is HerdManagementPage && size.width >= 600) {
            final card = find.byKey(const Key('pig-card-PIG-001'));
            if (card.evaluate().isNotEmpty) {
              expect(tester.getSize(card).height, lessThanOrEqualTo(190));
            }
          }
        }
      }
    });
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
