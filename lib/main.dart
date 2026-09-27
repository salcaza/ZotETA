import 'package:arcgis_maps/arcgis_maps.dart';
import 'package:flutter/material.dart';

import 'app.dart';

/// The native entry point for ZotETA.
///
/// Flutter calls this function when Android launches the application. It must
/// prepare any global SDK configuration before creating the widget tree.
void main() {
  // Some Flutter services are not available until the framework binding has
  // been initialized. Calling this explicitly is useful because we configure
  // ArcGIS before runApp() starts rendering widgets.
  WidgetsFlutterBinding.ensureInitialized();

  // String.fromEnvironment reads a compile-time value, not an operating-system
  // environment variable. Our run command supplies it from config.json with:
  //   flutter run --dart-define-from-file=config.json
  // This keeps the real key out of source code and version control.
  const apiKey = String.fromEnvironment('ARCGIS_API_KEY');

  // ArcGIS SDK requests, such as downloading the basemap, use this key.
  ArcGISEnvironment.apiKey = apiKey;

  // runApp hands Flutter the root widget. We also tell the UI whether the key
  // was present so it can show a useful setup warning when it is missing.
  runApp(const ZotEtaApp(hasArcGISKey: apiKey != ''));
}
