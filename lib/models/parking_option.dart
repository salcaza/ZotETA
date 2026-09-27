import 'permit_profile.dart';

/// All inputs required to evaluate and display one parking facility.
///
/// This is a plain, immutable domain model. It contains no Flutter widgets and
/// no ArcGIS objects, which allows the ranking logic to be tested without an
/// emulator or network connection.
class ParkingOption {
  /// Creates one fully described parking option.
  const ParkingOption({
    required this.id,
    required this.name,
    required this.shortName,
    required this.latitude,
    required this.longitude,
    required this.normalPermitZones,
    required this.residentPermits,
    required this.isSurfaceLot,
    required this.visitorPurchaseAvailable,
    this.paidParkingSummary,
    required this.driveMinutes,
    required this.walkMinutes,
    required this.elevationGainMeters,
    required this.searchMedianMinutes,
    required this.searchP80Minutes,
    required this.fullProbability,
    required this.fallbackPenaltyMinutes,
  });

  /// Stable machine-readable identifier used to connect cards and map markers.
  final String id;

  /// Full facility name displayed beneath the abbreviation.
  final String name;

  /// Compact label displayed prominently on a recommendation card.
  final String shortName;

  /// WGS 84 latitude of the prototype point marker.
  final double latitude;

  /// WGS 84 longitude of the prototype point marker.
  final double longitude;

  /// Zones that may normally use this option during restricted hours.
  final Set<int> normalPermitZones;

  /// Resident permit variants with normal access to this facility.
  final Set<ResidentPermitType> residentPermits;

  /// Whether this option is a surface lot rather than a parking structure.
  /// This distinction matters for resident after-hours privileges.
  final bool isSurfaceLot;

  /// Whether a driver can buy visitor parking at this exact option.
  final bool visitorPurchaseAvailable;

  /// Human-readable purchase method and price, when verified.
  final String? paidParkingSummary;

  /// Demonstration driving time from the assumed starting point.
  final int driveMinutes;

  /// Demonstration base walking time before accounting for hills.
  final int walkMinutes;

  /// Demonstration uphill elevation gain along the walking route.
  final int elevationGainMeters;

  /// Median, or typical, number of minutes spent searching for a stall.
  final int searchMedianMinutes;

  /// 80th-percentile search time used for a more cautious estimate.
  final int searchP80Minutes;

  /// Estimated probability from 0.0 to 1.0 that the option is effectively full.
  final double fullProbability;

  /// Extra time lost if the driver must abandon this option and use a fallback.
  final int fallbackPenaltyMinutes;
}
