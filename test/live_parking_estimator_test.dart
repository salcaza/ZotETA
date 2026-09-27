import 'package:flutter_test/flutter_test.dart';
import 'package:zot_eta/data/sample_parking_data.dart';
import 'package:zot_eta/models/parking_observation.dart';
import 'package:zot_eta/services/live_parking_estimator.dart';

void main() {
  const estimator = LiveParkingEstimator();
  final ssps = sampleParkingOptions.firstWhere((option) => option.id == 'ssps');

  test('uses a lower baseline outside weekday peak hours', () {
    final peak = estimator.estimate(
      option: ssps,
      observations: const [],
      at: DateTime(2026, 10, 13, 11),
    );
    final evening = estimator.estimate(
      option: ssps,
      observations: const [],
      at: DateTime(2026, 10, 13, 19),
    );

    expect(peak.typicalMinutes, 10);
    expect(evening.typicalMinutes, lessThan(peak.typicalMinutes));
    expect(peak.freshReportCount, 0);
  });

  test('fresh measured search changes the prediction immediately', () {
    final now = DateTime(2026, 10, 13, 11);
    final prediction = estimator.estimate(
      option: ssps,
      observations: [
        ParkingObservation(
          id: 'report-1',
          facilityId: 'ssps',
          reportedAt: now.subtract(const Duration(minutes: 5)),
          searchDurationMinutes: 18,
        ),
      ],
      at: now,
    );

    expect(prediction.typicalMinutes, 13);
    expect(prediction.freshReportCount, 1);
    expect(prediction.isLiveAdjusted, isTrue);
  });

  test('ignores reports for another facility or older than one hour', () {
    final now = DateTime(2026, 10, 13, 11);
    final prediction = estimator.estimate(
      option: ssps,
      observations: [
        ParkingObservation(
          id: 'old',
          facilityId: 'ssps',
          reportedAt: now.subtract(const Duration(minutes: 61)),
          searchDurationMinutes: 30,
        ),
        ParkingObservation(
          id: 'other',
          facilityId: 'arc',
          reportedAt: now,
          searchDurationMinutes: 30,
        ),
      ],
      at: now,
    );

    expect(prediction.typicalMinutes, 10);
    expect(prediction.freshReportCount, 0);
  });

  test('observation and active search survive JSON round trips', () {
    final at = DateTime(2026, 10, 13, 11, 30);
    final observation = ParkingObservation(
      id: 'report',
      facilityId: 'ssps',
      reportedAt: at,
      searchDurationMinutes: 7,
    );
    final restored = ParkingObservation.fromJson(observation.toJson())!;
    final active = ActiveParkingSearch(facilityId: 'ssps', startedAt: at);
    final activeRestored = ActiveParkingSearch.fromJson(active.toJson())!;

    expect(restored.searchDurationMinutes, 7);
    expect(restored.reportedAt, at);
    expect(activeRestored.facilityId, 'ssps');
    expect(
      activeRestored.elapsedMinutesAt(at.add(const Duration(seconds: 61))),
      2,
    );
  });
}
