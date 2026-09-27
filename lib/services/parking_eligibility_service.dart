import '../models/parking_option.dart';

/// Applies time- and permit-dependent parking rules to a parking option.
///
/// The first prototype deliberately isolates these rules from the UI. That
/// allows us to expand the policy model or replace it with authoritative data
/// without changing the map and cards that consume the answer.
class ParkingEligibilityService {
  const ParkingEligibilityService();

  /// Returns whether [permit] may use [option] at [arrivalTime].
  ///
  /// Current simplified policy:
  /// 1. General zone flexibility is assumed on weekends.
  /// 2. General zone flexibility is assumed from 3 p.m. on weekdays.
  /// 3. During weekday restricted hours, the permit zone must be listed in
  ///    [ParkingOption.normalPermitZones].
  ///
  /// These rules are prototype assumptions and must be checked against current
  /// UCI Transportation policy before production use.
  bool canPark({
    required ParkingOption option,
    required PermitProfile permit,
    required DateTime arrivalTime,
  }) {
    // Dart numbers weekdays from Monday (1) through Sunday (7).
    final isWeekend =
        arrivalTime.weekday == DateTime.saturday ||
        arrivalTime.weekday == DateTime.sunday;

    // DateTime.hour uses a 24-hour clock, so 15 means 3:00 p.m.
    final zoneRestrictionsHaveEnded = arrivalTime.hour >= 15;

    // The first prototype models general/unassigned areas only. Current UCI
    // rules allow zone flexibility after 3 p.m. on weekdays and on weekends.
    if (isWeekend || zoneRestrictionsHaveEnded) return true;

    // Set.contains is an efficient membership check for the assigned zone.
    return option.normalPermitZones.contains(permit.zone);
  }
}
