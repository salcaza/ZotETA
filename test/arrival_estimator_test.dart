import 'package:flutter_test/flutter_test.dart';
import 'package:zot_eta/data/sample_parking_data.dart';
import 'package:zot_eta/services/arrival_estimator.dart';

void main() {
  // A stateless service can be shared by all tests.
  const estimator = ArrivalEstimator();

  test('includes search, fallback risk, and elevation in expected time', () {
    final aps = sampleParkingOptions.firstWhere((option) => option.id == 'aps');
    final estimate = estimator.estimate(aps);

    // APS expected parking: 11 median + round(25% * 14 fallback) = 15.
    expect(estimate.expectedParkingMinutes, 15);
    // APS walk: 7 base + ceil(12 m / 12) = 8.
    expect(estimate.adjustedWalkMinutes, 8);
    // Expected: 18 drive + 15 parking + 8 walk = 41.
    expect(estimate.expectedMinutes, 41);
    // Conservative: 18 drive + 17 P80 search + 14 fallback + 8 walk = 57.
    expect(estimate.conservativeMinutes, 57);
  });

  test('lower-risk ARC option has a smaller parking buffer', () {
    final aps = sampleParkingOptions.firstWhere((option) => option.id == 'aps');
    final arc = sampleParkingOptions.firstWhere((option) => option.id == 'arc');

    // This protects the behavioral goal rather than duplicating exact totals:
    // an option with lower failure risk should reserve less parking time.
    expect(
      estimator.estimate(arc).expectedParkingMinutes,
      lessThan(estimator.estimate(aps).expectedParkingMinutes),
    );
  });

  test('accepts a destination-specific walking estimate', () {
    final aps = sampleParkingOptions.firstWhere((option) => option.id == 'aps');
    final estimate = estimator.estimate(aps, walkMinutesOverride: 12);

    expect(estimate.adjustedWalkMinutes, 12);
    expect(estimate.expectedMinutes, 45);
  });

  test('accepts live driving and walking route durations', () {
    final aps = sampleParkingOptions.firstWhere((option) => option.id == 'aps');
    final estimate = estimator.estimate(
      aps,
      driveMinutesOverride: 14,
      walkMinutesOverride: 10,
    );

    expect(estimate.expectedMinutes, 39);
    expect(estimate.conservativeMinutes, 55);
  });

  test('accepts live typical and cautious parking-search overrides', () {
    final arc = sampleParkingOptions.firstWhere((option) => option.id == 'arc');
    final estimate = estimator.estimate(
      arc,
      parkingSearchMinutesOverride: 9,
      cautiousSearchMinutesOverride: 13,
    );

    expect(estimate.expectedParkingMinutes, 9);
    expect(estimate.conservativeMinutes, 20 + 13 + 4 + 15);
  });
}
