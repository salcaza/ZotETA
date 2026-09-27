import 'package:shared_preferences/shared_preferences.dart';

import '../data/uci_classroom_catalog.dart';
import '../models/campus_destination.dart';

/// Persists the selected building or classroom on the user's device.
class DestinationStore {
  DestinationStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const _destinationKey = 'zoteta.destination_room.v1';
  final SharedPreferencesAsync _preferences;

  Future<CampusDestination?> load() async {
    final storageKey = await _preferences.getString(_destinationKey);
    return destinationByStorageKey(storageKey);
  }

  Future<void> save(CampusDestination destination) =>
      _preferences.setString(_destinationKey, destination.storageKey);
}
