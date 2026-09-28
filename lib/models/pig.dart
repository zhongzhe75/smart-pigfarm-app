enum PigSex {
  male,
  female,
}

extension PigSexText on PigSex {
  String get label => this == PigSex.male ? '公' : '母';
}

enum PigStatus {
  active,
  observation,
  treatment,
  sold,
}

extension PigStatusText on PigStatus {
  String get label {
    switch (this) {
      case PigStatus.active:
        return '在栏';
      case PigStatus.observation:
        return '观察';
      case PigStatus.treatment:
        return '处置中';
      case PigStatus.sold:
        return '已出栏';
    }
  }
}

class Pig {
  const Pig({
    required this.id,
    required this.earTag,
    required this.pigHouseId,
    required this.batchNo,
    required this.sex,
    required this.birthDate,
    required this.currentStatus,
    required this.createdAt,
  });

  final String id;
  final String earTag;
  final String pigHouseId;
  final String batchNo;
  final PigSex sex;
  final DateTime birthDate;
  final PigStatus currentStatus;
  final DateTime createdAt;

  int ageDaysAt(DateTime date) => date.difference(birthDate).inDays;

  Pig copyWith({PigStatus? currentStatus}) {
    return Pig(
      id: id,
      earTag: earTag,
      pigHouseId: pigHouseId,
      batchNo: batchNo,
      sex: sex,
      birthDate: birthDate,
      currentStatus: currentStatus ?? this.currentStatus,
      createdAt: createdAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'ear_tag': earTag,
      'pig_house_id': pigHouseId,
      'batch_no': batchNo,
      'sex': sex.name,
      'birth_date': birthDate.millisecondsSinceEpoch,
      'current_status': currentStatus.name,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory Pig.fromMap(Map<String, Object?> map) {
    return Pig(
      id: map['id']! as String,
      earTag: map['ear_tag']! as String,
      pigHouseId: map['pig_house_id']! as String,
      batchNo: map['batch_no']! as String,
      sex: PigSex.values.byName(map['sex']! as String),
      birthDate: DateTime.fromMillisecondsSinceEpoch(map['birth_date']! as int),
      currentStatus: PigStatus.values.byName(map['current_status']! as String),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']! as int),
    );
  }
}
