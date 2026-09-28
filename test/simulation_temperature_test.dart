import 'package:flutter_test/flutter_test.dart';
import 'package:smart_pigfarm_app/models/threshold_settings.dart';
import 'package:smart_pigfarm_app/services/simulation_service.dart';

void main() {
  test('keeps live and report temperatures near the indoor baseline', () {
    final simulation = SimulationService();
    final thresholds = ThresholdSettings.defaults();
    final liveTemperatures = List.generate(
      240,
      (_) => simulation
          .nextSensorSnapshot(
            pigHouseId: 'A01',
            thresholds: thresholds,
          )
          .temperature,
    );
    final reportTemperatures =
        simulation.reportData().temperatureCurve.map((point) => point.value);

    expect(liveTemperatures, everyElement(inInclusiveRange(24.6, 25.8)));
    expect(liveTemperatures.toSet().length, greaterThan(1));
    expect(reportTemperatures, everyElement(inInclusiveRange(24.6, 25.8)));
    expect(reportTemperatures.toSet().length, greaterThan(1));
  });
}
