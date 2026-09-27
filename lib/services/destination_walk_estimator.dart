import 'dart:math' as math;

import '../models/campus_destination.dart';
import '../models/parking_option.dart';

/// Estimates parking-to-classroom walking time from public spatial data.
///
/// Until ArcGIS pedestrian routing is connected, this uses geodesic distance,
/// a transparent campus-path detour factor, and the destination's separate
/// indoor allowance. It is more destination-sensitive than the old fixed DBH
/// values but is still labeled as an estimate in the UI.
class DestinationWalkEstimator {
  const DestinationWalkEstimator();

  static const _walkingMetersPerMinute = 75.0;
  static const _campusPathFactor = 1.25;

  int estimateMinutes(ParkingOption option, CampusDestination destination) {
    final directMeters = _haversineMeters(
      option.latitude,
      option.longitude,
      destination.latitude,
      destination.longitude,
    );
    final outdoorMinutes = math.max(
      1,
      (directMeters * _campusPathFactor / _walkingMetersPerMinute).ceil(),
    );
    return outdoorMinutes + destination.indoorMinutes;
  }

  double _haversineMeters(double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusMeters = 6371000.0;
    final latitudeDelta = _radians(lat2 - lat1);
    final longitudeDelta = _radians(lon2 - lon1);
    final a =
        math.sin(latitudeDelta / 2) * math.sin(latitudeDelta / 2) +
        math.cos(_radians(lat1)) *
            math.cos(_radians(lat2)) *
            math.sin(longitudeDelta / 2) *
            math.sin(longitudeDelta / 2);
    return earthRadiusMeters * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _radians(double degrees) => degrees * math.pi / 180;
}
