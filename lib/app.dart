import 'package:flutter/material.dart';

import 'screens/parking_map_screen.dart';

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
      home: ParkingMapScreen(hasArcGISKey: hasArcGISKey),
    );
  }
}
