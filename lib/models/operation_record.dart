class OperationRecord {
  const OperationRecord({
    required this.id,
    required this.time,
    required this.roleName,
    required this.deviceName,
    required this.action,
  });

  final String id;
  final DateTime time;
  final String roleName;
  final String deviceName;
  final String action;
}
