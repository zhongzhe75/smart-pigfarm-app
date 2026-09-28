import '../models/ai_behavior_record.dart';

abstract interface class AiBehaviorRepository {
  Future<List<AiBehaviorRecord>> queryBehaviorRecords({
    String? pigId,
    DateTime? from,
    DateTime? to,
  });
}
