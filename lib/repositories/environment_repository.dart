import '../models/environment_record.dart';

abstract interface class EnvironmentRepository {
  Future<List<EnvironmentRecord>> queryHistory({
    required String pigHouseId,
    required DateTime from,
    required DateTime to,
  });
}
