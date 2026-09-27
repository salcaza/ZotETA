import 'package:flutter_test/flutter_test.dart';
import 'package:zot_eta/data/sample_parking_data.dart';
import 'package:zot_eta/models/parking_option.dart';
import 'package:zot_eta/services/parking_eligibility_service.dart';

void main() {
  const service = ParkingEligibilityService();

  // All tests use the same sample student profile.
  const permit = PermitProfile(type: PermitType.s, zone: 4);

  // Pick representative facilities from the shared seed dataset.
  final aps = sampleParkingOptions.firstWhere((option) => option.id == 'aps');
  final ssps = sampleParkingOptions.firstWhere((option) => option.id == 'ssps');
  final arc = sampleParkingOptions.firstWhere((option) => option.id == 'arc');

  test(
    'allows the assigned zone and all-zone fallback areas before 3 p.m.',
    () {
      final tuesdayMorning = DateTime(2026, 10, 13, 10);

      // APS includes Zone 4, ARC is modeled as all-zone, and SSPS is Zone 5.
      expect(
        service.canPark(
          option: aps,
          permit: permit,
          arrivalTime: tuesdayMorning,
        ),
        isTrue,
      );
      expect(
        service.canPark(
          option: arc,
          permit: permit,
          arrivalTime: tuesdayMorning,
        ),
        isTrue,
      );
      expect(
        service.canPark(
          option: ssps,
          permit: permit,
          arrivalTime: tuesdayMorning,
        ),
        isFalse,
      );
    },
  );

  test('allows general zone flexibility after 3 p.m.', () {
    final tuesdayAfternoon = DateTime(2026, 10, 13, 15, 5);

    // The simplified prototype policy permits cross-zone parking after 3 p.m.
    expect(
      service.canPark(
        option: ssps,
        permit: permit,
        arrivalTime: tuesdayAfternoon,
      ),
      isTrue,
    );
  });
}
