/// Student parking permit categories represented by the prototype.
///
/// Only S and P are modeled so far. More UCI permit categories can be added
/// after the authoritative rule set is gathered.
enum PermitType { s, p }

/// The permit information that affects a student's parking eligibility.
///
/// A profile is immutable: both fields are `final`, so a new profile is
/// created if the user changes their permit in a future settings screen.
class PermitProfile {
  /// Creates a permit with a category and assigned parking zone.
  const PermitProfile({required this.type, required this.zone});

  /// The permit category, such as an S student permit.
  final PermitType type;

  /// The numbered UCI parking zone assigned to the permit.
  final int zone;

  /// A human-readable label used in the trip header.
  String get label => '${type.name.toUpperCase()} Zone $zone';
}

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
    required this.driveMinutes,
    required this.walkMinutes,
    required this.elevationGainMeters,
    required this.searchMedianMinutes,
    required this.searchP80Minutes,
    required this.fullProbability,
    required this.fallbackPenaltyMinutes,
    required this.liveReportSummary,
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

  /// Prototype summary that will eventually come from community observations.
  final String liveReportSummary;
}
