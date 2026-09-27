import '../models/parking_option.dart';
import '../models/permit_profile.dart';

/// Applies time- and permit-dependent parking rules to a parking option.
///
/// The first prototype deliberately isolates these rules from the UI. That
/// allows us to expand the policy model or replace it with authoritative data
/// without changing the map and cards that consume the answer.
class ParkingEligibilityService {
  const ParkingEligibilityService();

  /// Returns whether [permit] may use [option] for the planned stay.
  ///
  /// This MVP intentionally ignores university holidays. Posted signs,
  /// 24-hour reserved spaces, closures, and enforcement instructions always
  /// override an app recommendation.
  bool canPark({
    required ParkingOption option,
    required PermitProfile permit,
    required DateTime arrivalTime,
    DateTime? departureTime,
  }) {
    // Dart numbers weekdays from Monday (1) through Sunday (7).
    final isWeekend =
        arrivalTime.weekday == DateTime.saturday ||
        arrivalTime.weekday == DateTime.sunday;

    return switch (permit.type) {
      PermitType.s || PermitType.p => _studentCanPark(
        option: option,
        permit: permit,
        arrivalTime: arrivalTime,
        departureTime: departureTime,
        isWeekend: isWeekend,
      ),
      PermitType.r => _residentCanPark(
        option: option,
        permit: permit,
        arrivalTime: arrivalTime,
        isWeekend: isWeekend,
      ),
      // Evening permits gain access at 5 p.m. on weekdays and all weekend.
      PermitType.e => isWeekend || arrivalTime.hour >= 17,
      // Motorcycle permits require motorcycle-stall data, which the current
      // six general-parking markers do not yet represent.
      PermitType.mx => false,
      // ACC housing permits do not automatically authorize campus parking.
      PermitType.acc => false,
      // Only show options where an on-site visitor purchase was verified.
      PermitType.none => option.visitorPurchaseAvailable,
    };
  }

  bool _studentCanPark({
    required ParkingOption option,
    required PermitProfile permit,
    required DateTime arrivalTime,
    required DateTime? departureTime,
    required bool isWeekend,
  }) {
    // Per the MVP product decision, S and P are never treated as overnight
    // permits—even if the arrival itself occurs during an allowed period.
    if (departureTime != null && !_sameDate(arrivalTime, departureTime)) {
      return false;
    }

    // UCI grants cross-zone general parking after 3 p.m. and on weekends.
    if (isWeekend || arrivalTime.hour >= 15) return true;

    // From 7 a.m. to 3 p.m. on weekdays, the assigned zone controls access.
    // Times before 7 a.m. are rejected to avoid implying overnight validity.
    if (arrivalTime.hour < 7) return false;
    return option.normalPermitZones.contains(permit.zone);
  }

  bool _residentCanPark({
    required ParkingOption option,
    required PermitProfile permit,
    required DateTime arrivalTime,
    required bool isWeekend,
  }) {
    final residentPermit = permit.residentPermit;
    if (residentPermit == null) return false;

    // R-CVGRAD is specifically excluded from the broad surface-lot exception.
    final hasSurfaceLotPrivilege =
        residentPermit != ResidentPermitType.rCvGrad &&
        (isWeekend || arrivalTime.hour >= 17) &&
        option.isSurfaceLot;

    return option.residentPermits.contains(residentPermit) ||
        hasSurfaceLotPrivilege;
  }

  bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
