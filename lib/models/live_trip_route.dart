import 'package:arcgis_maps/arcgis_maps.dart';

/// The two network modes ZotETA solves for one door-to-door trip.
enum TripLegMode { driving, walking }

/// One route returned by ArcGIS, including its drawable line and measurements.
class LiveRouteLeg {
  const LiveRouteLeg({
    required this.mode,
    required this.geometry,
    required this.durationMinutes,
    required this.distanceMeters,
  });

  final TripLegMode mode;
  final Polyline geometry;
  final double durationMinutes;
  final double distanceMeters;

  /// Whole minutes are easier to scan and avoid implying false precision.
  int get roundedMinutes => durationMinutes.ceil();
}

/// A complete trip: drive to parking, then walk to the campus destination.
class LiveTripRoute {
  const LiveTripRoute({
    required this.drive,
    required this.walk,
    required this.solvedAt,
  });

  final LiveRouteLeg drive;
  final LiveRouteLeg walk;
  final DateTime solvedAt;
}
