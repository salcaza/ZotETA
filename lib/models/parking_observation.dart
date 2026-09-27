/// A completed, voluntary parking check-in for one facility.
///
/// [searchDurationMinutes] is present when the driver first tapped Searching
/// and later tapped Parked. A direct Parked tap is still useful as a fresh
/// availability signal, but does not claim a measured search duration.
class ParkingObservation {
  const ParkingObservation({
    required this.id,
    required this.facilityId,
    required this.reportedAt,
    this.searchDurationMinutes,
  });

  final String id;
  final String facilityId;
  final DateTime reportedAt;
  final int? searchDurationMinutes;

  Map<String, Object?> toJson() => {
    'id': id,
    'facilityId': facilityId,
    'reportedAt': reportedAt.toIso8601String(),
    'searchDurationMinutes': searchDurationMinutes,
  };

  static ParkingObservation? fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final facilityId = json['facilityId'];
    final reportedAt = DateTime.tryParse(json['reportedAt'] as String? ?? '');
    final duration = json['searchDurationMinutes'];
    if (id is! String || facilityId is! String || reportedAt == null) {
      return null;
    }
    return ParkingObservation(
      id: id,
      facilityId: facilityId,
      reportedAt: reportedAt,
      searchDurationMinutes: duration is int ? duration : null,
    );
  }
}

/// A timer that begins when the driver reports that they are still searching.
class ActiveParkingSearch {
  const ActiveParkingSearch({
    required this.facilityId,
    required this.startedAt,
  });

  final String facilityId;
  final DateTime startedAt;

  int elapsedMinutesAt(DateTime now) {
    final seconds = now.difference(startedAt).inSeconds.clamp(0, 86400);
    return (seconds / 60).ceil();
  }

  Map<String, Object?> toJson() => {
    'facilityId': facilityId,
    'startedAt': startedAt.toIso8601String(),
  };

  static ActiveParkingSearch? fromJson(Map<String, Object?> json) {
    final facilityId = json['facilityId'];
    final startedAt = DateTime.tryParse(json['startedAt'] as String? ?? '');
    if (facilityId is! String || startedAt == null) return null;
    return ActiveParkingSearch(facilityId: facilityId, startedAt: startedAt);
  }
}
