class AiBehaviorRecord {
  const AiBehaviorRecord({
    required this.id,
    required this.pigId,
    required this.pigHouseId,
    required this.occurredAt,
    required this.behaviorType,
    required this.confidence,
    required this.durationSeconds,
    this.source = 'camera_prototype',
    this.cameraId,
  });

  final String id;
  final String pigId;
  final String pigHouseId;
  final DateTime occurredAt;
  final String behaviorType;
  final double confidence;
  final int durationSeconds;
  final String source;
  final String? cameraId;
}

extension AiBehaviorRecordText on AiBehaviorRecord {
  String get behaviorLabel {
    switch (behaviorType) {
      case 'low_activity':
        return '活动量下降';
      case 'feeding_reduction':
        return '采食量下降';
      case 'prolonged_rest':
        return '持续休息时间偏长';
      case 'abnormal_behavior':
        return '多因素行为异常';
      default:
        return '行为指标异常';
    }
  }
}
