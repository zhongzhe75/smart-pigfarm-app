import 'dart:math';

import 'package:flutter/material.dart';

import '../models/report_data.dart';
import 'app_theme.dart';

class LineChartCard extends StatelessWidget {
  const LineChartCard({
    super.key,
    required this.title,
    required this.unit,
    required this.points,
    this.color = AppTheme.primary,
    this.labelInterval,
    this.nonNegative = false,
    this.axisDecimals,
    this.chartHeight = 140,
  });

  final String title;
  final String unit;
  final List<ChartPoint> points;
  final Color color;
  final int? labelInterval;
  final bool nonNegative;
  final int? axisDecimals;
  final double chartHeight;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                Text(
                  unit,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppTheme.textMuted,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: chartHeight,
              width: double.infinity,
              child: CustomPaint(
                painter: _LineChartPainter(
                  points: points,
                  color: color,
                  textColor: AppTheme.textMuted,
                  labelInterval:
                      labelInterval ?? _defaultLabelInterval(points.length),
                  nonNegative: nonNegative,
                  axisDecimals: axisDecimals,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _defaultLabelInterval(int pointCount) {
    if (pointCount <= 7) return 1;
    if (pointCount <= 30) return 5;
    return 15;
  }
}

class _LineChartPainter extends CustomPainter {
  const _LineChartPainter({
    required this.points,
    required this.color,
    required this.textColor,
    required this.labelInterval,
    required this.nonNegative,
    required this.axisDecimals,
  });

  final List<ChartPoint> points;
  final Color color;
  final Color textColor;
  final int labelInterval;
  final bool nonNegative;
  final int? axisDecimals;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) {
      return;
    }

    const left = 28.0;
    const bottom = 24.0;
    const top = 8.0;
    const right = 8.0;
    final chartWidth = size.width - left - right;
    final chartHeight = size.height - top - bottom;
    final values = points.map((point) => point.value).toList();
    final bounds = calculateChartBounds(values, nonNegative: nonNegative);
    final minValue = bounds.min;
    final maxValue = bounds.max;
    final visibleRange = maxValue - minValue;

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    final axisPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.09)
      ..strokeWidth = 1;
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          color.withValues(alpha: 0.24),
          color.withValues(alpha: 0.01),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(left, top, chartWidth, chartHeight));

    for (var i = 0; i <= 3; i++) {
      final y = top + chartHeight * i / 3;
      canvas.drawLine(
          Offset(left, y), Offset(size.width - right, y), gridPaint);
    }
    canvas.drawLine(
        const Offset(left, top), Offset(left, top + chartHeight), axisPaint);
    canvas.drawLine(
      Offset(left, top + chartHeight),
      Offset(size.width - right, top + chartHeight),
      axisPaint,
    );

    Offset pointOffset(int index) {
      final x = points.length == 1
          ? left + chartWidth / 2
          : left + chartWidth * index / (points.length - 1);
      final normalized =
          (points[index].value - minValue) / (maxValue - minValue);
      final y = top + chartHeight * (1 - normalized);
      return Offset(x, y);
    }

    final path = Path()..moveTo(pointOffset(0).dx, pointOffset(0).dy);
    for (var i = 1; i < points.length; i++) {
      final prev = pointOffset(i - 1);
      final current = pointOffset(i);
      final controlX = (prev.dx + current.dx) / 2;
      path.cubicTo(
          controlX, prev.dy, controlX, current.dy, current.dx, current.dy);
    }
    final fillPath = Path.from(path)
      ..lineTo(pointOffset(points.length - 1).dx, top + chartHeight)
      ..lineTo(pointOffset(0).dx, top + chartHeight)
      ..close();
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    final dotPaint = Paint()..color = color;
    for (var i = 0; i < points.length; i++) {
      final offset = pointOffset(i);
      if (i % labelInterval == 0 || i == points.length - 1) {
        canvas.drawCircle(offset, points.length <= 7 ? 3 : 2.2, dotPaint);
      }
      if (i % labelInterval == 0 || i == points.length - 1) {
        _drawText(
          canvas,
          points[i].label,
          Offset(offset.dx, top + chartHeight + 8),
          fontSize: 10,
          align: TextAlign.center,
        );
      }
    }

    _drawText(
      canvas,
      formatChartAxisValue(maxValue, visibleRange, axisDecimals),
      const Offset(0, top - 2),
      fontSize: 10,
      align: TextAlign.left,
    );
    _drawText(
      canvas,
      formatChartAxisValue(minValue, visibleRange, axisDecimals),
      Offset(0, top + chartHeight - 10),
      fontSize: 10,
      align: TextAlign.left,
    );
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset, {
    required double fontSize,
    required TextAlign align,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: textColor, fontSize: fontSize),
      ),
      textDirection: TextDirection.ltr,
      textAlign: align,
    )..layout(minWidth: 0, maxWidth: 48);
    final dx =
        align == TextAlign.center ? offset.dx - painter.width / 2 : offset.dx;
    painter.paint(canvas, Offset(dx, offset.dy));
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.color != color ||
        oldDelegate.textColor != textColor ||
        oldDelegate.labelInterval != labelInterval ||
        oldDelegate.nonNegative != nonNegative ||
        oldDelegate.axisDecimals != axisDecimals;
  }
}

String formatChartAxisValue(
  double value,
  double visibleRange, [
  int? fractionDigits,
]) {
  final normalized = value.abs() < 0.0005 ? 0.0 : value;
  if (normalized == 0) return '0';
  final digits = fractionDigits ?? (visibleRange < 10 ? 1 : 0);
  return normalized.toStringAsFixed(digits);
}

({double min, double max}) calculateChartBounds(
  Iterable<double> source, {
  bool nonNegative = false,
}) {
  final values = source.toList(growable: false);
  var minValue = values.reduce(min);
  var maxValue = values.reduce(max);
  if ((maxValue - minValue).abs() < 0.1) {
    if (nonNegative) {
      maxValue = max(1, maxValue + 1);
      minValue = 0;
    } else {
      maxValue += 1;
      minValue -= 1;
    }
  }
  final padding = (maxValue - minValue) * 0.16;
  minValue -= padding;
  maxValue += padding;
  if (nonNegative) minValue = max(0, minValue);
  return (min: minValue, max: maxValue);
}
