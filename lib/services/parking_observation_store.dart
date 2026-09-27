import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/parking_observation.dart';

/// Storage boundary for parking check-ins.
///
/// The UI depends on this interface rather than SharedPreferences directly.
/// A future ArcGIS feature service or other shared backend can implement the
/// same contract without changing the screen or prediction logic.
abstract interface class ParkingObservationRepository {
  Future<List<ParkingObservation>> loadRecent();
  Future<ActiveParkingSearch?> loadActiveSearch();
  Future<ActiveParkingSearch> startSearching(String facilityId, DateTime now);
  Future<ParkingObservation> markParked(String facilityId, DateTime now);
}

/// Device-local prototype implementation of parking report persistence.
class LocalParkingObservationRepository
    implements ParkingObservationRepository {
  LocalParkingObservationRepository({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const _observationsKey = 'zoteta.parking_observations.v1';
  static const _activeSearchKey = 'zoteta.active_parking_search.v1';
  static const _maximumStoredObservations = 200;
  final SharedPreferencesAsync _preferences;

  @override
  Future<List<ParkingObservation>> loadRecent() async {
    final encoded = await _preferences.getString(_observationsKey);
    if (encoded == null) return [];
    try {
      final values = jsonDecode(encoded) as List<dynamic>;
      return values
          .whereType<Map<String, dynamic>>()
          .map((value) => ParkingObservation.fromJson(value))
          .whereType<ParkingObservation>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<ActiveParkingSearch?> loadActiveSearch() async {
    final encoded = await _preferences.getString(_activeSearchKey);
    if (encoded == null) return null;
    try {
      final value = jsonDecode(encoded) as Map<String, dynamic>;
      final active = ActiveParkingSearch.fromJson(value);
      if (active != null &&
          DateTime.now().difference(active.startedAt) >
              const Duration(hours: 4)) {
        await _preferences.remove(_activeSearchKey);
        return null;
      }
      return active;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<ActiveParkingSearch> startSearching(
    String facilityId,
    DateTime now,
  ) async {
    final existing = await loadActiveSearch();
    if (existing?.facilityId == facilityId) return existing!;

    final active = ActiveParkingSearch(facilityId: facilityId, startedAt: now);
    await _preferences.setString(_activeSearchKey, jsonEncode(active.toJson()));
    return active;
  }

  @override
  Future<ParkingObservation> markParked(String facilityId, DateTime now) async {
    final active = await loadActiveSearch();
    final measuredDuration = active?.facilityId == facilityId
        ? active!.elapsedMinutesAt(now).clamp(1, 120)
        : null;
    final observation = ParkingObservation(
      id: '${now.microsecondsSinceEpoch}-$facilityId',
      facilityId: facilityId,
      reportedAt: now,
      searchDurationMinutes: measuredDuration,
    );

    final observations = await loadRecent();
    final updated = [
      observation,
      ...observations,
    ].take(_maximumStoredObservations).map((value) => value.toJson()).toList();
    await _preferences.setString(_observationsKey, jsonEncode(updated));
    await _preferences.remove(_activeSearchKey);
    return observation;
  }
}
