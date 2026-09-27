import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/permit_profile.dart';

/// Saves the small, non-identifying permit profile on this device.
///
/// SharedPreferences is appropriate for simple settings. It is not encrypted
/// storage and should never hold passwords, API keys, UCInetIDs, or payment
/// information. ZotETA stores only the selected permit category and zone.
class PermitProfileStore {
  PermitProfileStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const _profileKey = 'zoteta.permit_profile.v1';
  final SharedPreferencesAsync _preferences;

  /// Returns the saved profile, or null on first launch/corrupt old data.
  Future<PermitProfile?> load() async {
    final encoded = await _preferences.getString(_profileKey);
    if (encoded == null) return null;

    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map<String, dynamic>) return null;
      return PermitProfile.fromJson(decoded);
    } on FormatException {
      return null;
    }
  }

  /// Replaces the previous local selection with [profile].
  Future<void> save(PermitProfile profile) async {
    await _preferences.setString(_profileKey, jsonEncode(profile.toJson()));
  }

  /// Removes onboarding data, useful for a future reset-data control.
  Future<void> clear() => _preferences.remove(_profileKey);
}
