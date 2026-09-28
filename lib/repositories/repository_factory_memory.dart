import '../services/pig_farm_seed_data_generator.dart';
import 'in_memory_repository_store.dart';
import 'repository_bundle.dart';

Future<RepositoryBundle> createPlatformRepositoryBundle() async {
  final data = PigFarmSeedDataGenerator().generate();
  final store = InMemoryRepositoryStore(data);
  return RepositoryBundle(
    pigs: store,
    pigMetrics: store,
    healthAlerts: store,
    environment: store,
    aiBehavior: store,
    dispose: store.close,
  );
}
