class ChartPoint {
  const ChartPoint({
    required this.label,
    required this.value,
  });

  final String label;
  final double value;
}

class ReportData {
  const ReportData({
    required this.temperatureCurve,
    required this.humidityCurve,
    required this.lightCurve,
    required this.feedCurve,
    required this.ventilationHours,
    required this.sprayHours,
    required this.feedCost,
    required this.electricityCost,
    required this.medicineCost,
  });

  final List<ChartPoint> temperatureCurve;
  final List<ChartPoint> humidityCurve;
  final List<ChartPoint> lightCurve;
  final List<ChartPoint> feedCurve;
  final double ventilationHours;
  final double sprayHours;
  final double feedCost;
  final double electricityCost;
  final double medicineCost;

  double get totalCost => feedCost + electricityCost + medicineCost;
}
