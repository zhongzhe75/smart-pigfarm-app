import 'package:flutter_test/flutter_test.dart';
import 'package:smart_pigfarm_app/data_source/mock_data_source.dart';
import 'package:smart_pigfarm_app/main.dart';
import 'package:smart_pigfarm_app/repositories/in_memory_repository_store.dart';
import 'package:smart_pigfarm_app/repositories/repository_bundle.dart';
import 'package:smart_pigfarm_app/services/app_state.dart';
import 'package:smart_pigfarm_app/services/pig_farm_seed_data_generator.dart';

void main() {
  testWidgets('app still opens the existing login page', (tester) async {
    final store = InMemoryRepositoryStore(
      PigFarmSeedDataGenerator().generate(endDate: DateTime.utc(2026, 9, 17)),
    );
    final repositories = RepositoryBundle(
      pigs: store,
      pigMetrics: store,
      healthAlerts: store,
      environment: store,
      aiBehavior: store,
      dispose: store.close,
    );

    await tester.pumpWidget(SmartPigfarmApp(
      appState: AppState(dataSource: MockDataSource()),
      repositories: repositories,
    ));
    await tester.pump();

    expect(find.text('智慧养猪场管理系统'), findsOneWidget);
    expect(find.text('选择登录角色'), findsOneWidget);
  });
}
