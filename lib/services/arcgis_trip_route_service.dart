import 'package:arcgis_maps/arcgis_maps.dart';

import '../models/campus_destination.dart';
import '../models/live_trip_route.dart';
import '../models/parking_option.dart';

/// Temporary origin used until device-location permission is implemented.
///
/// The coordinate is the ArcGIS geocoder result for 10 Ravenna, Irvine, CA.
const prototypeOriginLabel = '10 Ravenna, Irvine';
final prototypeOrigin = ArcGISPoint(
  x: -117.820188541813,
  y: 33.675376644207,
  spatialReference: SpatialReference.wgs84,
);

/// Solves the driving and walking legs against ArcGIS's online route service.
///
/// The service owns networking and ArcGIS-specific objects so the screen only
/// coordinates loading states and renders the returned [LiveTripRoute].
class ArcGISTripRouteService {
  ArcGISTripRouteService({RouteTask? routeTask})
    : _routeTask =
          routeTask ??
          RouteTask.withUri(
            Uri.parse(
              'https://route-api.arcgis.com/arcgis/rest/services/'
              'World/Route/NAServer/Route_World',
            ),
          );

  final RouteTask _routeTask;
  Future<void>? _loadFuture;

  Future<LiveTripRoute> solveTrip({
    required ParkingOption parking,
    required CampusDestination destination,
  }) async {
    _loadFuture ??= _routeTask.load();
    await _loadFuture;

    final parkingPoint = _point(parking.longitude, parking.latitude);
    final destinationPoint = _point(
      destination.longitude,
      destination.latitude,
    );

    // Solve independently because the user changes travel mode after parking.
    final results = await Future.wait([
      _solveLeg(
        start: prototypeOrigin,
        end: parkingPoint,
        mode: TripLegMode.driving,
      ),
      _solveLeg(
        start: parkingPoint,
        end: destinationPoint,
        mode: TripLegMode.walking,
      ),
    ]);

    return LiveTripRoute(
      drive: results[0],
      walk: results[1],
      solvedAt: DateTime.now(),
    );
  }

  Future<LiveRouteLeg> _solveLeg({
    required ArcGISPoint start,
    required ArcGISPoint end,
    required TripLegMode mode,
  }) async {
    final parameters = await _routeTask.createDefaultParameters();
    final travelMode = _travelModeFor(mode);
    if (travelMode == null && mode == TripLegMode.walking) {
      throw StateError('The ArcGIS route service did not provide walking.');
    }

    parameters
      ..returnRoutes = true
      ..returnDirections = true
      ..routeShapeType = RouteShapeType.trueShapeWithMeasures
      ..outputSpatialReference = SpatialReference.wgs84
      ..travelMode = travelMode ?? parameters.travelMode
      ..setStops([Stop(start), Stop(end)]);

    final result = await _routeTask.solveRoute(parameters);
    if (result.routes.isEmpty) {
      throw StateError('ArcGIS could not find a ${mode.name} route.');
    }

    final route = result.routes.first;
    final geometry = route.routeGeometry;
    if (geometry == null) {
      throw StateError('ArcGIS returned a route without geometry.');
    }

    return LiveRouteLeg(
      mode: mode,
      geometry: geometry,
      durationMinutes: route.travelTime,
      distanceMeters: route.totalLength,
    );
  }

  TravelMode? _travelModeFor(TripLegMode requestedMode) {
    final modes = _routeTask.getRouteTaskInfo().travelModes;
    for (final mode in modes) {
      final description = '${mode.name} ${mode.type}'.toLowerCase();
      final matches = switch (requestedMode) {
        TripLegMode.driving =>
          description.contains('driv') ||
              description.contains('automobile') ||
              description.contains('car'),
        TripLegMode.walking =>
          description.contains('walk') || description.contains('pedestrian'),
      };
      if (matches) return mode;
    }
    return null;
  }

  ArcGISPoint _point(double longitude, double latitude) => ArcGISPoint(
    x: longitude,
    y: latitude,
    spatialReference: SpatialReference.wgs84,
  );
}
