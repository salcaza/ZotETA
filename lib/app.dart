import 'package:flutter/material.dart';

import 'models/campus_destination.dart';
import 'models/permit_profile.dart';
import 'screens/destination_search_screen.dart';
import 'screens/permit_onboarding_screen.dart';
import 'screens/parking_map_screen.dart';
import 'services/destination_store.dart';
import 'services/permit_profile_store.dart';

/// The root widget for the ZotETA application.
///
/// This widget owns configuration that applies to the whole app, such as its
/// name, theme, and first screen. It is stateless because those values do not
/// change while the app is running.
class ZotEtaApp extends StatelessWidget {
  /// Creates the app and records whether ArcGIS was given an API key.
  const ZotEtaApp({required this.hasArcGISKey, super.key});

  /// Whether `ARCGIS_API_KEY` was supplied when Flutter built the app.
  final bool hasArcGISKey;

  @override
  Widget build(BuildContext context) {
    // These brand colors seed Flutter's complete Material color scheme.
    const uciBlue = Color(0xFF255799);
    const uciGold = Color(0xFFFFC72C);

    // MaterialApp provides app-wide navigation, styling, and accessibility
    // conventions. ParkingMapScreen is currently our only route/screen.
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ZotETA',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: uciBlue,
          primary: uciBlue,
          secondary: uciGold,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        useMaterial3: true,
      ),
      home: _AppHome(hasArcGISKey: hasArcGISKey),
    );
  }
}

/// Coordinates startup loading and switches between onboarding and the map.
class _AppHome extends StatefulWidget {
  const _AppHome({required this.hasArcGISKey});

  final bool hasArcGISKey;

  @override
  State<_AppHome> createState() => _AppHomeState();
}

class _AppHomeState extends State<_AppHome> {
  final _profileStore = PermitProfileStore();
  final _destinationStore = DestinationStore();
  PermitProfile? _profile;
  CampusDestination? _destination;
  bool _loaded = false;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _loadLocalSettings();
  }

  Future<void> _loadLocalSettings() async {
    final profile = await _profileStore.load();
    final destination = await _destinationStore.load();
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _destination = destination;
      _loaded = true;
    });
  }

  Future<void> _saveProfile(PermitProfile profile) async {
    await _profileStore.save(profile);
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _editing = false;
    });
  }

  Future<void> _saveDestination(CampusDestination destination) async {
    await _destinationStore.save(destination);
    if (!mounted) return;
    setState(() => _destination = destination);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final profile = _profile;
    if (profile == null || _editing) {
      return PermitOnboardingScreen(
        initialProfile: profile,
        onSave: _saveProfile,
      );
    }

    final destination = _destination;
    if (destination == null) {
      return DestinationSearchScreen(
        currentDestination: null,
        selectionRequired: true,
        onSelected: _saveDestination,
      );
    }

    return ParkingMapScreen(
      key: ValueKey('${profile.cacheKey}:${destination.storageKey}'),
      hasArcGISKey: widget.hasArcGISKey,
      permit: profile,
      destination: destination,
      onDestinationChanged: _saveDestination,
      onEditProfile: () => setState(() => _editing = true),
    );
  }
}
