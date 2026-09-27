/// An official UCI building that contains searchable classrooms.
class CampusBuilding {
  const CampusBuilding({
    required this.abbreviation,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.mapLocationId,
    required this.roomCodes,
  });

  final String abbreviation;
  final String name;

  /// Official marker coordinates from UCI's public interactive campus map.
  final double latitude;
  final double longitude;
  final int mapLocationId;

  /// General-assignment classrooms published by UCI Classroom Technologies.
  final List<String> roomCodes;
}

/// A precise room selection paired with its best public geographic endpoint.
///
/// UCI publicly identifies exact rooms, but does not publish GIS coordinates
/// for each room. Therefore the map endpoint is the official building marker;
/// [indoorMinutes] explicitly represents the remaining indoor portion.
class CampusDestination {
  const CampusDestination({required this.building, required this.roomCode});

  final CampusBuilding building;
  final String roomCode;

  double get latitude => building.latitude;
  double get longitude => building.longitude;
  String get label => roomCode;
  String get subtitle => building.name;

  /// Best-effort floor parsed from UCI room-number conventions.
  ///
  /// Four-digit rooms use their first digit; three-digit rooms use the
  /// hundreds digit. The UI labels this as inferred rather than surveyed.
  int get inferredFloor {
    final roomPart = roomCode.split(' ').last;
    final digits = RegExp(r'^\d+').stringMatch(roomPart);
    if (digits == null || digits.isEmpty) return 1;
    final number = int.tryParse(digits) ?? 100;
    return number >= 1000 ? number ~/ 1000 : number ~/ 100;
  }

  /// Transparent allowance after reaching the building marker.
  int get indoorMinutes => 2 + (inferredFloor - 1).clamp(0, 8);

  String get officialClassroomUrl {
    final slug = building.abbreviation.toLowerCase();
    final roomSlug = roomCode.toLowerCase().replaceAll(' ', '-');
    return 'https://classrooms.uci.edu/classrooms/$slug/$roomSlug';
  }
}
