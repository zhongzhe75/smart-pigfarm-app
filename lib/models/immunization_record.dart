class ImmunizationRecord {
  const ImmunizationRecord({
    required this.id,
    required this.pigId,
    required this.batchNo,
    required this.vaccineName,
    required this.immunizedAt,
    required this.operatorName,
    required this.note,
    this.nextDueAt,
  });

  final String id;
  final String pigId;
  final String batchNo;
  final String vaccineName;
  final DateTime immunizedAt;
  final DateTime? nextDueAt;
  final String operatorName;
  final String note;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'pig_id': pigId,
      'batch_no': batchNo,
      'vaccine_name': vaccineName,
      'immunized_at': immunizedAt.millisecondsSinceEpoch,
      'next_due_at': nextDueAt?.millisecondsSinceEpoch,
      'operator_name': operatorName,
      'note': note,
    };
  }

  factory ImmunizationRecord.fromMap(Map<String, Object?> map) {
    final nextDueAt = map['next_due_at'] as int?;
    return ImmunizationRecord(
      id: map['id']! as String,
      pigId: map['pig_id']! as String,
      batchNo: map['batch_no']! as String,
      vaccineName: map['vaccine_name']! as String,
      immunizedAt:
          DateTime.fromMillisecondsSinceEpoch(map['immunized_at']! as int),
      nextDueAt: nextDueAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(nextDueAt),
      operatorName: map['operator_name']! as String,
      note: map['note']! as String,
    );
  }
}
