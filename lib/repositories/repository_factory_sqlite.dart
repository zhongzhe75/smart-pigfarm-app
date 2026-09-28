import '../database/app_database.dart';
import '../services/pig_farm_seed_data_generator.dart';
import 'repository_bundle.dart';
import 'sqlite_repository_store.dart';

Future<RepositoryBundle> createPlatformRepositoryBundle() async {
  final database = await AppDatabase.open();
  await ensurePlatformSeedData(database);
  final store = SqliteRepositoryStore(database);
  return RepositoryBundle(
    pigs: store,
    pigMetrics: store,
    healthAlerts: store,
    environment: store,
    aiBehavior: store,
    dispose: store.close,
  );
}

Future<void> ensurePlatformSeedData(
  AppDatabase database, {
  PigFarmSeedDataGenerator? generator,
  DateTime? endDate,
}) async {
  final seedGenerator = generator ?? PigFarmSeedDataGenerator();
  if (!await database.isSeeded) {
    final data = seedGenerator.generate(endDate: endDate);
    await database.seed(data);
    return;
  }
  if (!await database.isEnvironmentSeeded) {
    final records = seedGenerator.generateEnvironmentRecords(endDate: endDate);
    await database.seedEnvironment(records);
  }
}
