import '../models/parking_option.dart';

/// The calculated door-to-door travel estimates for one parking option.
///
/// Both a typical estimate and a cautious estimate are returned so the UI can
/// communicate uncertainty instead of pretending parking is deterministic.
class ArrivalEstimate {
  /// Creates the result of an [ArrivalEstimator] calculation.
  const ArrivalEstimate({
    required this.expectedMinutes,
    required this.conservativeMinutes,
    required this.adjustedWalkMinutes,
    required this.expectedParkingMinutes,
  });

  /// Typical drive + parking + adjusted walking time.
  final int expectedMinutes;

  /// Safer total based on a high search-time percentile and fallback allowance.
  final int conservativeMinutes;

  /// Base walking time plus the prototype uphill penalty.
  final int adjustedWalkMinutes;

  /// Median search time plus the expected cost of a full facility.
  final int expectedParkingMinutes;
}

/// Converts raw parking inputs into understandable total-arrival estimates.
///
/// The formulas are intentionally small and transparent for the prototype. A
/// future version can replace individual inputs with live models while keeping
/// this service's public interface stable.
class ArrivalEstimator {
  const ArrivalEstimator();

  /// Calculates expected and conservative totals for [option].
  ///
  /// Expected total:
  /// `drive + median search + expected fallback cost + adjusted walk`
  ///
  /// Conservative total:
  /// `drive + P80 search + fallback allowance + adjusted walk`
  ArrivalEstimate estimate(ParkingOption option, {int? walkMinutesOverride}) {
    // Transparent prototype heuristic: every 12 m of ascent adds roughly a
    // minute to the base walk. The production version will use route samples.
    final adjustedWalk =
        walkMinutesOverride ??
        option.walkMinutes + (option.elevationGainMeters / 12).ceil();

    // Expected-value reasoning weights the fallback cost by its probability.
    // For a 25% full probability and a 14-minute fallback, this adds 4 minutes
    // after rounding: round(0.25 * 14) = 4.
    final failureRiskMinutes =
        (option.fullProbability * option.fallbackPenaltyMinutes).round();
    final expectedParking = option.searchMedianMinutes + failureRiskMinutes;

    // High-risk options reserve the entire fallback penalty. Lower-risk
    // options reserve half, rounded upward, for a less extreme safety margin.
    final conservativeFallback = option.fullProbability >= 0.20
        ? option.fallbackPenaltyMinutes
        : (option.fallbackPenaltyMinutes / 2).ceil();

    return ArrivalEstimate(
      expectedMinutes: option.driveMinutes + expectedParking + adjustedWalk,
      conservativeMinutes:
          option.driveMinutes +
          option.searchP80Minutes +
          conservativeFallback +
          adjustedWalk,
      adjustedWalkMinutes: adjustedWalk,
      expectedParkingMinutes: expectedParking,
    );
  }
}
