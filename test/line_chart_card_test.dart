import 'package:flutter_test/flutter_test.dart';
import 'package:smart_pigfarm_app/widgets/line_chart_card.dart';

void main() {
  test('non-negative chart bounds never create a negative y axis', () {
    final zeroBounds = calculateChartBounds(
      const [0, 0, 0],
      nonNegative: true,
    );
    final activityBounds = calculateChartBounds(
      const [0.0, 0.2, 0.4],
      nonNegative: true,
    );

    expect(zeroBounds.min, 0);
    expect(activityBounds.min, 0);
    expect(zeroBounds.max, greaterThan(0));
  });

  test('axis labels normalize negative zero and preserve small decimals', () {
    expect(formatChartAxisValue(-0.0, 4), '0');
    expect(formatChartAxisValue(-0.0001, 4), '0');
    expect(formatChartAxisValue(3.56, 0.8), '3.6');
    expect(formatChartAxisValue(4, 4, 1), '4.0');
    expect(formatChartAxisValue(4, 4, 0), '4');
  });
}
