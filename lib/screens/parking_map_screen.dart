import 'dart:async';

import 'package:arcgis_maps/arcgis_maps.dart';
import 'package:flutter/material.dart';

import '../data/sample_parking_data.dart';
import '../models/campus_destination.dart';
import '../models/live_trip_route.dart';
import '../models/parking_option.dart';
import '../models/parking_observation.dart';
import '../models/permit_profile.dart';
import '../services/arrival_estimator.dart';
import '../services/arcgis_trip_route_service.dart';
import '../services/destination_walk_estimator.dart';
import '../services/live_parking_estimator.dart';
import '../services/parking_eligibility_service.dart';
import '../services/parking_observation_store.dart';
import 'destination_search_screen.dart';

/// The main ZotETA experience: an ArcGIS map plus ranked parking choices.
///
/// This is stateful because selecting a card or map marker changes what the
/// user sees. The current trip inputs are fixed prototype values; future input
/// screens will supply them dynamically.
class ParkingMapScreen extends StatefulWidget {
  /// Creates the screen using the locally saved permit selection.
  const ParkingMapScreen({
    required this.hasArcGISKey,
    required this.permit,
    required this.destination,
    required this.onDestinationChanged,
    required this.onEditProfile,
    super.key,
  });

  /// Whether the build command supplied an ArcGIS API key.
  final bool hasArcGISKey;

  /// Current permit selection used for every eligibility decision.
  final PermitProfile permit;

  /// Official building or exact classroom selected by the user.
  final CampusDestination destination;

  /// Saves a newly selected destination in the app coordinator.
  final Future<void> Function(CampusDestination destination)
  onDestinationChanged;

  /// Opens the same form used during first-launch onboarding.
  final VoidCallback onEditProfile;

  @override
  State<ParkingMapScreen> createState() => _ParkingMapScreenState();
}

class _ParkingMapScreenState extends State<ParkingMapScreen> {
  // Trip editing is the next vertical slice. For now, the prototype evaluates
  // parking 30 minutes from launch and assumes a two-hour campus stay.
  late final DateTime _arrivalTime = DateTime.now().add(
    const Duration(minutes: 30),
  );
  late final DateTime _departureTime = _arrivalTime.add(
    const Duration(hours: 2),
  );

  // The controller is Flutter's programmatic handle to the native ArcGIS map.
  // It is used to assign a map, add overlays, identify taps, and move the view.
  final _mapController = ArcGISMapView.createController();

  // A graphics overlay holds temporary client-side markers. A production app
  // may use an ArcGIS FeatureLayer when facilities come from a hosted dataset.
  final _markerOverlay = GraphicsOverlay();
  final _routeOverlay = GraphicsOverlay();

  // Business rules live in services rather than directly inside UI widgets.
  final _eligibility = const ParkingEligibilityService();
  final _estimator = const ArrivalEstimator();
  final _walkEstimator = const DestinationWalkEstimator();
  final _liveEstimator = const LiveParkingEstimator();
  final _routeService = ArcGISTripRouteService();
  final ParkingObservationRepository _observationRepository =
      LocalParkingObservationRepository();

  // ArcGIS returns a Graphic after a marker tap. This lookup connects that
  // SDK object back to the ParkingOption ID understood by our app.
  final Map<Graphic, String> _parkingIdByGraphic = {};

  // Mutable screen state. Calling setState after changing either value asks
  // Flutter to rebuild the affected widgets.
  late String _selectedId;
  bool _mapReady = false;
  bool _reportsLoaded = false;
  String? _dismissedPromptForId;
  List<ParkingObservation> _observations = const [];
  ActiveParkingSearch? _activeSearch;
  Timer? _clock;
  Timer? _routeRefreshClock;
  LiveTripRoute? _liveRoute;
  bool _routeLoading = false;
  String? _routeError;
  int _routeRequestSequence = 0;

  @override
  void initState() {
    super.initState();
    _selectedId = sampleParkingOptions
        .firstWhere(_isLegal, orElse: () => sampleParkingOptions.first)
        .id;
    _loadParkingReports();
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && _activeSearch != null) setState(() {});
    });
    // Refreshing the selected route periodically updates traffic-dependent
    // driving time without repeatedly solving routes for every parking card.
    _routeRefreshClock = Timer.periodic(const Duration(minutes: 5), (_) {
      if (_mapReady && widget.hasArcGISKey) _loadSelectedRoute(fitMap: false);
    });
  }

  ParkingOption get _selectedOption => sampleParkingOptions.firstWhere(
    (option) => option.id == _selectedId,
    orElse: () => sampleParkingOptions.first,
  );

  Future<void> _loadParkingReports() async {
    final values = await Future.wait([
      _observationRepository.loadRecent(),
      _observationRepository.loadActiveSearch(),
    ]);
    if (!mounted) return;
    setState(() {
      _observations = values[0] as List<ParkingObservation>;
      _activeSearch = values[1] as ActiveParkingSearch?;
      if (_activeSearch != null) _selectedId = _activeSearch!.facilityId;
      _reportsLoaded = true;
    });
  }

  LiveParkingPrediction _prediction(ParkingOption option) => _liveEstimator
      .estimate(option: option, observations: _observations, at: _arrivalTime);

  /// Produces a new list ordered by legality and then expected arrival time.
  ///
  /// The spread (`[...]`) copies the constant seed list because sorting changes
  /// a list in place. Legal facilities always precede ineligible facilities.
  List<ParkingOption> get _rankedOptions {
    final options = [...sampleParkingOptions];
    options.sort((a, b) {
      final aLegal = _isLegal(a);
      final bLegal = _isLegal(b);
      if (aLegal != bLegal) return aLegal ? -1 : 1;
      return _estimate(a).expectedMinutes
          .compareTo(_estimate(b).expectedMinutes);
    });
    return options;
  }

  /// Convenience wrapper for applying the current scenario's permit and time.
  bool _isLegal(ParkingOption option) => _eligibility.canPark(
    option: option,
    permit: widget.permit,
    arrivalTime: _arrivalTime,
    departureTime: _departureTime,
  );

  int _walkMinutes(ParkingOption option) =>
      option.id == _selectedId && _liveRoute != null
      ? _liveRoute!.walk.roundedMinutes + widget.destination.indoorMinutes
      : _walkEstimator.estimateMinutes(option, widget.destination);

  int _driveMinutes(ParkingOption option) =>
      option.id == _selectedId && _liveRoute != null
      ? _liveRoute!.drive.roundedMinutes
      : option.driveMinutes;

  ArrivalEstimate _estimate(ParkingOption option) {
    final prediction = _prediction(option);
    return _estimator.estimate(
      option,
      driveMinutesOverride: _driveMinutes(option),
      walkMinutesOverride: _walkMinutes(option),
      parkingSearchMinutesOverride: prediction.typicalMinutes,
      cautiousSearchMinutesOverride: prediction.cautiousMinutes,
    );
  }

  String get _formattedArrivalTime {
    final hour = _arrivalTime.hour % 12 == 0 ? 12 : _arrivalTime.hour % 12;
    final minute = _arrivalTime.minute.toString().padLeft(2, '0');
    final period = _arrivalTime.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  @override
  void dispose() {
    // Native-backed controllers own resources outside Dart's garbage collector.
    // Releasing the controller prevents leaks when this screen is removed.
    _mapController.dispose();
    _clock?.cancel();
    _routeRefreshClock?.cancel();
    super.dispose();
  }

  /// Configures the ArcGIS map after its native view is available.
  Future<void> _onMapReady() async {
    // A basemap supplies the geographic background. Parking markers are added
    // separately so their styles and interactions remain under app control.
    final map = ArcGISMap.withBasemapStyle(BasemapStyle.arcGISLightGray);
    _mapController.arcGISMap = map;
    // Routes sit below markers so the origin, parking, and destination remain
    // easy to tap and recognize.
    _mapController.graphicsOverlays.addAll([_routeOverlay, _markerOverlay]);

    for (final option in sampleParkingOptions) {
      final legal = _isLegal(option);

      // Marker color communicates eligibility. The initially selected option
      // is slightly larger, and every marker gets a white outline for contrast.
      final symbol =
          SimpleMarkerSymbol(
              color: legal ? const Color(0xFF1B8A5A) : const Color(0xFF8A929C),
              size: option.id == _selectedId ? 18 : 14,
            )
            ..outline = SimpleLineSymbol(
              style: SimpleLineSymbolStyle.solid,
              color: Colors.white,
              width: 2,
            );
      final graphic = Graphic(
        // ArcGISPoint expects x before y: longitude is x and latitude is y.
        // WGS 84 is the standard spatial reference used by GPS coordinates.
        geometry: ArcGISPoint(
          x: option.longitude,
          y: option.latitude,
          spatialReference: SpatialReference.wgs84,
        ),
        symbol: symbol,
      );
      _markerOverlay.graphics.add(graphic);
      _parkingIdByGraphic[graphic] = option.id;
    }

    // UCI publishes the exact room identifier but only building-level GIS
    // geometry. This gold marker therefore represents the official building
    // endpoint; indoor minutes remain explicit in the ETA and UI.
    final destinationSymbol =
        SimpleMarkerSymbol(color: const Color(0xFFFFC72C), size: 20)
          ..outline = SimpleLineSymbol(
            style: SimpleLineSymbolStyle.solid,
            color: const Color(0xFF255799),
            width: 3,
          );
    _markerOverlay.graphics.add(
      Graphic(
        geometry: ArcGISPoint(
          x: widget.destination.longitude,
          y: widget.destination.latitude,
          spatialReference: SpatialReference.wgs84,
        ),
        symbol: destinationSymbol,
      ),
    );

    // This fixed purple marker makes the temporary test origin explicit. It
    // will be replaced by the device location in the next location phase.
    final originSymbol =
        SimpleMarkerSymbol(color: const Color(0xFF7C3AED), size: 16)
          ..outline = SimpleLineSymbol(
            style: SimpleLineSymbolStyle.solid,
            color: Colors.white,
            width: 2,
          );
    _markerOverlay.graphics.add(
      Graphic(geometry: prototypeOrigin, symbol: originSymbol),
    );

    // A viewpoint is the map camera. Scale 18,000 shows the UCI campus area.
    _mapController.setViewpoint(
      Viewpoint.fromCenter(
        ArcGISPoint(
          x: -117.8378,
          y: 33.6465,
          spatialReference: SpatialReference.wgs84,
        ),
        scale: 18000,
      ),
    );

    // An async operation might finish after a widget has been removed. mounted
    // prevents setState from being called on a state object no longer on screen.
    if (mounted) {
      setState(() => _mapReady = true);
      await _loadSelectedRoute();
    }
  }

  /// Requests fresh online driving and walking routes for the selected lot.
  ///
  /// The sequence number prevents a slower, older response from replacing the
  /// route after the user quickly chooses a different parking facility.
  Future<void> _loadSelectedRoute({bool fitMap = true}) async {
    if (!_mapReady || !widget.hasArcGISKey) return;
    final request = ++_routeRequestSequence;
    final selectedId = _selectedId;
    setState(() {
      _routeLoading = true;
      _routeError = null;
    });

    try {
      final route = await _routeService.solveTrip(
        parking: _selectedOption,
        destination: widget.destination,
      );
      if (!mounted || request != _routeRequestSequence) return;

      _drawRoute(route);
      setState(() {
        _liveRoute = route;
        _routeLoading = false;
      });

      if (fitMap) {
        final extent = GeometryEngine.combineExtents(
          geometry1: route.drive.geometry,
          geometry2: route.walk.geometry,
        );
        await _mapController.setViewpointGeometry(extent, paddingInDiPs: 72);
      }
    } catch (_) {
      if (!mounted || request != _routeRequestSequence) return;
      setState(() {
        _routeLoading = false;
        _routeError =
            'Live route unavailable. Showing prototype time estimates.';
      });
    }

    // If the selected ID changed without issuing a newer request, do not leave
    // route data associated with the previous card.
    if (mounted &&
        selectedId != _selectedId &&
        request == _routeRequestSequence) {
      setState(() => _liveRoute = null);
    }
  }

  void _drawRoute(LiveTripRoute route) {
    _routeOverlay.graphics.clear();

    // White casings keep both lines readable over streets and campus labels.
    for (final leg in [route.drive, route.walk]) {
      _routeOverlay.graphics.add(
        Graphic(
          geometry: leg.geometry,
          symbol: SimpleLineSymbol(
            style: leg.mode == TripLegMode.walking
                ? SimpleLineSymbolStyle.shortDash
                : SimpleLineSymbolStyle.solid,
            color: Colors.white,
            width: 8,
          ),
        ),
      );
    }
    _routeOverlay.graphics.addAll([
      Graphic(
        geometry: route.drive.geometry,
        symbol: SimpleLineSymbol(
          style: SimpleLineSymbolStyle.solid,
          color: const Color(0xFF1677FF),
          width: 5,
        ),
      ),
      Graphic(
        geometry: route.walk.geometry,
        symbol: SimpleLineSymbol(
          style: SimpleLineSymbolStyle.shortDash,
          color: const Color(0xFFFFB000),
          width: 5,
        ),
      ),
    ]);
  }

  /// Selects the parking facility whose ArcGIS marker the user tapped.
  Future<void> _onMapTap(Offset position) async {
    if (!_mapReady) return;

    // identifyGraphicsOverlay translates a screen pixel into nearby graphics.
    // The 24-pixel tolerance makes small markers easier to tap on a phone.
    final result = await _mapController.identifyGraphicsOverlay(
      _markerOverlay,
      screenPoint: position,
      tolerance: 24,
      maximumResults: 1,
    );
    if (result.graphics.isEmpty) return;
    final parkingId = _parkingIdByGraphic[result.graphics.first];
    if (parkingId != null && mounted) {
      final option = sampleParkingOptions.firstWhere(
        (candidate) => candidate.id == parkingId,
      );
      await _selectOption(option);
    }
  }

  /// Selects a recommendation card and moves the map camera to its facility.
  Future<void> _selectOption(ParkingOption option) async {
    setState(() {
      _selectedId = option.id;
      _dismissedPromptForId = null;
      _liveRoute = null;
      _routeError = null;
    });
    if (!_mapReady) return;
    await _loadSelectedRoute();
  }

  Future<void> _chooseDestination() async {
    final selected = await Navigator.push<CampusDestination>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            DestinationSearchScreen(currentDestination: widget.destination),
      ),
    );
    if (selected != null &&
        selected.storageKey != widget.destination.storageKey) {
      await widget.onDestinationChanged(selected);
    }
  }

  Future<void> _markSearching() async {
    final option = _selectedOption;
    final active = await _observationRepository.startSearching(
      option.id,
      DateTime.now(),
    );
    if (!mounted) return;
    setState(() {
      _activeSearch = active;
      _dismissedPromptForId = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Search timer started for ${option.shortName}.')),
    );
  }

  Future<void> _markParked() async {
    final option = _selectedOption;
    final observation = await _observationRepository.markParked(
      option.id,
      DateTime.now(),
    );
    if (!mounted) return;
    setState(() {
      _observations = [observation, ..._observations];
      _activeSearch = null;
      _dismissedPromptForId = option.id;
    });
    final duration = observation.searchDurationMinutes;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          duration == null
              ? 'Parked report added. The estimate updated.'
              : 'Recorded a $duration-minute search. The estimate updated.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Stack layers the map, header, and draggable results sheet on top of one
    // another. The first child is visually at the back.
    return Scaffold(
      body: Stack(
        children: [
          // Positioned.fill makes the ArcGIS view occupy the entire screen.
          Positioned.fill(
            child: ArcGISMapView(
              controllerProvider: () => _mapController,
              onMapViewReady: _onMapReady,
              onTap: _onMapTap,
            ),
          ),
          // SafeArea avoids system UI such as the status bar and camera cutout.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TripHeader(
                    permitLabel: widget.permit.label,
                    destination: widget.destination,
                    arrivalTimeLabel: _formattedArrivalTime,
                    onChooseDestination: _chooseDestination,
                    onEditProfile: widget.onEditProfile,
                  ),
                  if (!widget.hasArcGISKey) ...[
                    const SizedBox(height: 8),
                    const _ApiKeyNotice(),
                  ],
                  if (widget.hasArcGISKey) ...[
                    const SizedBox(height: 8),
                    _LiveRouteSummary(
                      route: _liveRoute,
                      loading: _routeLoading,
                      error: _routeError,
                      destination: widget.destination,
                      onRefresh: _routeLoading
                          ? null
                          : () => _loadSelectedRoute(fitMap: false),
                    ),
                  ],
                  if (_reportsLoaded &&
                      _isLegal(_selectedOption) &&
                      _dismissedPromptForId != _selectedId) ...[
                    const SizedBox(height: 8),
                    _ParkingCheckInBanner(
                      option: _selectedOption,
                      activeSearch: _activeSearch?.facilityId == _selectedId
                          ? _activeSearch
                          : null,
                      now: DateTime.now(),
                      onParked: _markParked,
                      onSearching: _markSearching,
                      onDismiss: () =>
                          setState(() => _dismissedPromptForId = _selectedId),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // This bottom sheet can be dragged between 22% and 72% of the screen.
          DraggableScrollableSheet(
            initialChildSize: 0.36,
            minChildSize: 0.22,
            maxChildSize: 0.72,
            builder: (context, scrollController) {
              return DecoratedBox(
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x26000000),
                      blurRadius: 18,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD2DA),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Best parking for your arrival',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Drive + search + destination-aware walk + indoor buffer',
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: const Color(0xFF59636F)),
                    ),
                    const SizedBox(height: 14),
                    // Rebuilding evaluates the getter again, so the cards stay
                    // sorted using the current business rules and estimates.
                    for (final option in _rankedOptions) ...[
                      _ParkingOptionCard(
                        option: option,
                        estimate: _estimate(option),
                        prediction: _prediction(option),
                        legal: _isLegal(option),
                        noPermit: widget.permit.type == PermitType.none,
                        driveMinutes: _driveMinutes(option),
                        usesLiveRoute:
                            option.id == _selectedId && _liveRoute != null,
                        arrivalTimeLabel: _formattedArrivalTime,
                        selected: option.id == _selectedId,
                        onTap: () => _selectOption(option),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Compact summary of the active permit, destination, and arrival time.
class _TripHeader extends StatelessWidget {
  const _TripHeader({
    required this.permitLabel,
    required this.destination,
    required this.arrivalTimeLabel,
    required this.onChooseDestination,
    required this.onEditProfile,
  });

  final String permitLabel;
  final CampusDestination destination;
  final String arrivalTimeLabel;
  final VoidCallback onChooseDestination;
  final VoidCallback onEditProfile;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 5,
      borderRadius: BorderRadius.circular(20),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.local_parking, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ZotETA',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  Text(
                    '$permitLabel  ·  $arrivalTimeLabel',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 2),
                  InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: onChooseDestination,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          const Icon(Icons.search, size: 15),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              destination.isClassroom
                                  ? '${destination.roomCode} · '
                                        '${destination.building.name}'
                                  : destination.building.name,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Edit parking profile',
              onPressed: onEditProfile,
              icon: const Icon(Icons.tune),
            ),
          ],
        ),
      ),
    );
  }
}

/// Setup guidance shown when the app was built without an ArcGIS API key.
class _ApiKeyNotice extends StatelessWidget {
  const _ApiKeyNotice();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFF4CF),
      borderRadius: BorderRadius.circular(12),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          children: [
            Icon(Icons.key, size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Add your free ArcGIS API key to load the basemap.',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Non-blocking status card for the selected online route.
class _LiveRouteSummary extends StatelessWidget {
  const _LiveRouteSummary({
    required this.route,
    required this.loading,
    required this.error,
    required this.destination,
    required this.onRefresh,
  });

  final LiveTripRoute? route;
  final bool loading;
  final String? error;
  final CampusDestination destination;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final currentRoute = route;
    final subtitle = loading
        ? 'Updating driving and walking routes…'
        : error ??
              (currentRoute == null
                  ? 'Preparing route…'
                  : '${currentRoute.drive.roundedMinutes} min drive · '
                        '${currentRoute.walk.roundedMinutes + destination.indoorMinutes} '
                        'min walk · ArcGIS online');

    return Material(
      elevation: 3,
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 9, 4, 9),
        child: Row(
          children: [
            if (loading)
              const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            else
              Icon(
                error == null ? Icons.route : Icons.cloud_off_outlined,
                size: 21,
              ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '$prototypeOriginLabel → parking → destination',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Refresh live route',
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small, dismissible Apple-Maps-style check-in that does not block the map.
class _ParkingCheckInBanner extends StatelessWidget {
  const _ParkingCheckInBanner({
    required this.option,
    required this.activeSearch,
    required this.now,
    required this.onParked,
    required this.onSearching,
    required this.onDismiss,
  });

  final ParkingOption option;
  final ActiveParkingSearch? activeSearch;
  final DateTime now;
  final VoidCallback onParked;
  final VoidCallback onSearching;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final active = activeSearch;
    final message = active == null
        ? 'At ${option.shortName}?'
        : 'Searching ${active.elapsedMinutesAt(now)} min at '
              '${option.shortName}';
    return Material(
      elevation: 4,
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Row(
          children: [
            const Icon(Icons.radar, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            TextButton(onPressed: onParked, child: const Text('Parked')),
            TextButton(
              onPressed: onSearching,
              child: Text(active == null ? 'Searching' : 'Still searching'),
            ),
            IconButton(
              tooltip: 'Dismiss check-in',
              visualDensity: VisualDensity.compact,
              onPressed: onDismiss,
              icon: const Icon(Icons.close, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}

/// A tappable summary of one parking option and its calculated travel times.
class _ParkingOptionCard extends StatelessWidget {
  const _ParkingOptionCard({
    required this.option,
    required this.estimate,
    required this.prediction,
    required this.legal,
    required this.noPermit,
    required this.driveMinutes,
    required this.usesLiveRoute,
    required this.arrivalTimeLabel,
    required this.selected,
    required this.onTap,
  });

  final ParkingOption option;
  final ArrivalEstimate estimate;
  final LiveParkingPrediction prediction;
  final bool legal;
  final bool noPermit;
  final int driveMinutes;
  final bool usesLiveRoute;
  final String arrivalTimeLabel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // The selected recommendation gets a thicker UCI-blue border.
    final borderColor = selected
        ? Theme.of(context).colorScheme.primary
        : const Color(0xFFDCE1E7);

    // Ineligible options remain visible for context but are visually muted.
    return Opacity(
      opacity: legal ? 1 : 0.66,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: borderColor, width: selected ? 2 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        option.shortName,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    _StatusChip(legal: legal, noPermit: noPermit),
                  ],
                ),
                const SizedBox(height: 2),
                Text(option.name, style: Theme.of(context).textTheme.bodySmall),
                if (legal && option.paidParkingSummary != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    option.paidParkingSummary!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF11643F),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    _Metric(
                      icon: Icons.directions_car,
                      value: '$driveMinutes min',
                      label: usesLiveRoute ? 'live drive' : 'drive estimate',
                    ),
                    _Metric(
                      icon: Icons.local_parking,
                      value: '${estimate.expectedParkingMinutes} min',
                      label: 'parking + risk',
                    ),
                    _Metric(
                      icon: Icons.directions_walk,
                      value: '${estimate.adjustedWalkMinutes} min',
                      label: 'walk',
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          legal
                              ? '${estimate.expectedMinutes} min'
                              : 'Not eligible',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: legal
                                    ? Theme.of(context).colorScheme.primary
                                    : const Color(0xFF6B7280),
                              ),
                        ),
                        Text(
                          legal ? 'total expected' : 'at $arrivalTimeLabel',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ],
                ),
                if (legal) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.groups_2_outlined, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${prediction.typicalMinutes} min search · '
                          '${prediction.summary}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      Text(
                        '${prediction.confidenceLabel} · plan for '
                        '${estimate.conservativeMinutes} min',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small icon/value/label group used for drive, parking, and walking time.
class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15),
              const SizedBox(width: 4),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

/// Human-readable eligibility badge displayed in each parking card.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.legal, required this.noPermit});

  final bool legal;
  final bool noPermit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: legal ? const Color(0xFFE3F5EC) : const Color(0xFFF0F1F3),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        legal
            ? (noPermit ? 'Paid visitor option' : 'Legal for permit')
            : (noPermit ? 'No verified purchase' : 'Not eligible'),
        style: TextStyle(
          color: legal ? const Color(0xFF11643F) : const Color(0xFF626973),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
