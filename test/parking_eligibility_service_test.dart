import 'package:flutter_test/flutter_test.dart';
import 'package:zot_eta/data/sample_parking_data.dart';
import 'package:zot_eta/models/permit_profile.dart';
import 'package:zot_eta/services/parking_eligibility_service.dart';

void main() {
  const service = ParkingEligibilityService();

  // Zone 5 mirrors the initial commuter scenario this project is designed for.
  const permit = PermitProfile(type: PermitType.s, zone: 5);

  // Pick representative facilities from the shared seed dataset.
  final aps = sampleParkingOptions.firstWhere((option) => option.id == 'aps');
  final ssps = sampleParkingOptions.firstWhere((option) => option.id == 'ssps');
  final arc = sampleParkingOptions.firstWhere((option) => option.id == 'arc');

  test('allows only assigned-zone facilities before 3 p.m. on weekdays', () {
    final tuesdayMorning = DateTime(2026, 10, 13, 10);

    // SSPS is Zone 5. ARC serves every S zone, while APS is Zone 4 only.
    expect(
      service.canPark(
        option: ssps,
        permit: permit,
        arrivalTime: tuesdayMorning,
      ),
      isTrue,
    );
    expect(
      service.canPark(option: arc, permit: permit, arrivalTime: tuesdayMorning),
      isTrue,
    );
    expect(
      service.canPark(option: aps, permit: permit, arrivalTime: tuesdayMorning),
      isFalse,
    );
  });

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

  test('never treats an S/P trip crossing midnight as eligible', () {
    final lateArrival = DateTime(2026, 10, 13, 23);
    final afterMidnight = DateTime(2026, 10, 14, 1);

    expect(
      service.canPark(
        option: ssps,
        permit: permit,
        arrivalTime: lateArrival,
        departureTime: afterMidnight,
      ),
      isFalse,
    );
  });

  test('no-permit profile only allows verified on-site visitor purchase', () {
    const noPermit = PermitProfile(type: PermitType.none);
    final tuesdayMorning = DateTime(2026, 10, 13, 10);

    expect(
      service.canPark(
        option: arc,
        permit: noPermit,
        arrivalTime: tuesdayMorning,
      ),
      isTrue,
    );
    expect(
      service.canPark(
        option: ssps,
        permit: noPermit,
        arrivalTime: tuesdayMorning,
      ),
      isFalse,
    );
  });

  test(
    'resident base access and after-hours surface exception are distinct',
    () {
      const middleEarth = PermitProfile(
        type: PermitType.r,
        residentPermit: ResidentPermitType.rMe,
      );
      final weekdayMorning = DateTime(2026, 10, 13, 10);
      final weekdayEvening = DateTime(2026, 10, 13, 18);

      expect(
        service.canPark(
          option: aps,
          permit: middleEarth,
          arrivalTime: weekdayMorning,
        ),
        isTrue,
      );
      expect(
        service.canPark(
          option: arc,
          permit: middleEarth,
          arrivalTime: weekdayEvening,
        ),
        isTrue,
      );
    },
  );
}
