import 'repository_bundle.dart';
import 'repository_factory_memory.dart'
    if (dart.library.io) 'repository_factory_sqlite.dart' as platform;

Future<RepositoryBundle> createDefaultRepositoryBundle() {
  return platform.createPlatformRepositoryBundle();
}
