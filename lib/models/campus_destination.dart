/// An official UCI building that contains searchable classrooms.
class CampusBuilding {
  const CampusBuilding({
    required this.abbreviation,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.mapLocationId,
    required this.roomCodes,
    this.aliases = const [],
  });

  final String abbreviation;
  final String name;

  /// Common names that students may type instead of the official name.
  final List<String> aliases;

  /// Public building-level coordinates in WGS 84.
  ///
  /// These are navigation endpoints, not surveyed classroom coordinates.
  final double latitude;
  final double longitude;

  /// UCI interactive-map identifier when the public catalog exposes one.
  final int? mapLocationId;

  /// General-assignment classrooms published by UCI Classroom Technologies.
  final List<String> roomCodes;
}

/// A precise room selection paired with its best public geographic endpoint.
///
/// UCI publicly identifies exact rooms, but does not publish GIS coordinates
/// for each room. Therefore the map endpoint is the official building marker;
/// [indoorMinutes] explicitly represents the remaining indoor portion.
class CampusDestination {
  const CampusDestination({required this.building, this.roomCode});

  final CampusBuilding building;

  /// Exact classroom code, or `null` when the whole building was selected.
  final String? roomCode;

  double get latitude => building.latitude;
  double get longitude => building.longitude;
  bool get isClassroom => roomCode != null;
  String get storageKey =>
      isClassroom ? 'room:$roomCode' : 'building:${building.abbreviation}';
  String get label => roomCode ?? building.abbreviation;
  String get subtitle => isClassroom ? building.name : 'Building destination';

  /// Best-effort floor parsed from UCI room-number conventions.
  ///
  /// Four-digit rooms use their first digit; three-digit rooms use the
  /// hundreds digit. The UI labels this as inferred rather than surveyed.
  int? get inferredFloor {
    final code = roomCode;
    if (code == null) return null;
    final roomPart = code.split(' ').last;
    final digits = RegExp(r'^\d+').stringMatch(roomPart);
    if (digits == null || digits.isEmpty) return 1;
    final number = int.tryParse(digits) ?? 100;
    return number >= 1000 ? number ~/ 1000 : number ~/ 100;
  }

  /// Transparent allowance after reaching the building marker.
  int get indoorMinutes {
    final floor = inferredFloor;
    if (floor == null) return 0;
    return 2 + (floor - 1).clamp(0, 8);
  }

  String? get officialClassroomUrl {
    final code = roomCode;
    if (code == null) return null;
    final slug = building.abbreviation.toLowerCase();
    final roomSlug = code.toLowerCase().replaceAll(' ', '-');
    return 'https://classrooms.uci.edu/classrooms/$slug/$roomSlug';
  }
}
