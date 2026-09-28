class AiFinding {
  const AiFinding({
    required this.title,
    required this.value,
    required this.status,
    required this.isAbnormal,
  });

  final String title;
  final String value;
  final String status;
  final bool isAbnormal;
}

class AiInsight {
  const AiInsight({
    required this.updatedAt,
    required this.findings,
  });

  final DateTime updatedAt;
  final List<AiFinding> findings;
}
