# ZotETA Architecture and Code Walkthrough

This document explains how the current prototype works from app launch to the
recommendation shown on screen. It is written for someone learning Flutter,
Dart, Android, and ArcGIS for the first time.

## 1. What the app is solving

Ordinary navigation often treats arrival at a parking facility as arrival at
the destination. A UCI commuter still has to find a legal stall, possibly
abandon a full facility, and walk to class. ZotETA models the complete trip:

```text
drive + parking search + full-facility risk + hill-adjusted walk
```

The prototype ranks parking options using this total and places legally usable
facilities ahead of ineligible ones.

## 2. The technology layers

```text
Android emulator or phone
        |
Flutter engine (renders the cross-platform UI)
        |
Dart application code in lib/
        |
ArcGIS Maps SDK for Flutter
        |
ArcGIS basemap service over the internet
```

- **Dart** is the programming language used in `lib/` and `test/`.
- **Flutter** turns a tree of Dart widgets into a native mobile experience.
- **ArcGIS Maps SDK for Flutter** embeds a native ArcGIS map inside that tree.
- **Gradle** builds the Android application and packages Flutter and ArcGIS.
- **Android SDK/NDK** provide Android build tools and native-code support.

The NDK is needed because parts of the ArcGIS runtime are compiled native code,
even though ZotETA's application logic is written in Dart.

## 3. Files we own versus generated files

The main hand-written files are:

```text
lib/
  main.dart                         process entry point
  app.dart                          app-wide theme and first screen
  models/permit_profile.dart        permit types and local profile
  models/campus_destination.dart    building and exact-room destination
  models/parking_observation.dart   parked reports and active search timer
  models/parking_option.dart        parking-facility vocabulary
  data/sample_parking_data.dart     prototype inputs
  data/uci_classroom_catalog.dart   139 official room identifiers
  services/destination_store.dart   selected-destination persistence
  services/destination_walk_estimator.dart
                                    destination-aware walk estimate
  services/permit_profile_store.dart
                                    on-device profile persistence
  services/arrival_estimator.dart   travel-time calculations
  services/live_parking_estimator.dart
                                    time baseline + fresh report blend
  services/parking_observation_store.dart
                                    replaceable report storage boundary
  services/parking_eligibility_service.dart
                                    permit rules
  screens/permit_onboarding_screen.dart
                                    first-launch and edit form
  screens/destination_search_screen.dart
                                    building and exact-room search
  screens/parking_map_screen.dart   ArcGIS map and recommendations

test/
  arrival_estimator_test.dart
  parking_eligibility_service_test.dart
  permit_profile_test.dart
  campus_destination_test.dart
  live_parking_estimator_test.dart
```

The `android/` and `ios/` directories mostly contain platform scaffolding
created by Flutter. We make small platform changes there, but do not normally
edit generated registrant, build-output, or tool-cache files.

## 4. Startup flow

Android starts the Flutter engine, which calls `main()` in `lib/main.dart`.

```text
main()
  -> initialize Flutter bindings
  -> read ARCGIS_API_KEY from the compiled environment
  -> assign the key to ArcGISEnvironment
  -> runApp(ZotEtaApp)
  -> MaterialApp builds _AppHome
  -> _AppHome loads the local permit profile and destination
  -> show permit onboarding if the permit is absent
  -> require a building or classroom if the destination is absent
  -> show ParkingMapScreen when both choices exist
```

`config.json` is not read directly by code at runtime. The command

```powershell
flutter run --dart-define-from-file=config.json
```

passes its values to the Dart compiler. `String.fromEnvironment` retrieves the
compiled value. The real file is ignored by Git; `config.example.json` safely
documents the required shape.

## 5. How Flutter builds a screen

Flutter interfaces are trees of widgets. A widget is an immutable description
of part of the interface. For example, the root of the main screen is roughly:

```text
Scaffold
  Stack
    ArcGISMapView
    SafeArea
      TripHeader
    DraggableScrollableSheet
      ListView
        ParkingOptionCard...
```

`ParkingMapScreen` is a `StatefulWidget` because the selected parking option
and map-ready flag can change. The associated State object stores those values.
Calling `setState` tells Flutter that the description may now be different, so
Flutter calls `build` again and efficiently updates the rendered interface.

Private Dart names begin with `_`. For example, `_selectedId` and
`_ParkingOptionCard` are visible only inside their Dart library/file context.

## 6. Domain models

`PermitProfile` and `ParkingOption` are domain models: plain Dart objects that
represent concepts in the problem rather than visual controls.

They are immutable because their fields are `final`. Immutability makes data
flow easier to understand and prevents an unrelated part of the app from
silently changing an option after it has been created.

The model deliberately contains ordinary values such as numbers and strings,
not widgets or ArcGIS graphics. That separation lets tests calculate results
without starting Android or loading a map.

`PermitProfile` uses nullable fields because different permit families require
different details: S/P need a zone, R needs a resident subtype, ACC needs a
community, and E/MX/no-permit need no second selection. Its `isComplete`
property validates those combinations before they can be saved.

## 7. Local settings and observation storage

`PermitProfileStore` turns the profile into JSON and saves that short string
with Flutter's `shared_preferences` package. On Android this becomes ordinary
app preference data on the device. It is not a remote database and does not
sync across phones.

This is intentionally a setting—not an identity system. The app stores no
UCInetID, password, license plate, home address, payment information, or trip
history. `app.dart` waits for the asynchronous load before deciding whether to
show onboarding, destination search, or the map. Saving updates both device
storage and Flutter state, which immediately switches screens.

`DestinationStore` does the same for a building or room. Parking reports use
`ParkingObservationRepository`, an interface separating the rest of the app
from storage. Its current local implementation saves an active search timer
and up to 200 completed observations. A later shared service can implement the
same interface without rewriting the map or estimator. Reports do not yet sync
across users or devices.

## 8. Seed data boundary

`sample_parking_data.dart` creates six `ParkingOption` objects. This is a local,
in-memory list: it does not query UCI, ArcGIS, or a database.

The coordinates place prototype point markers. All travel-time, elevation,
and availability-baseline values are demonstrations. Centralizing them makes
it straightforward to replace their source later while preserving
the objects consumed by the rest of the app.

The classroom catalog has a different trust boundary. Its 139 room identifiers
come from UCI Classroom Technologies, while each of its 29 building marker
coordinates and public map IDs comes from UCI's interactive campus map. These
are official public records checked in September 2026, not demo coordinates.
However, UCI does not expose room-level GIS geometry publicly. A destination
therefore keeps the exact room identity while using the official building
marker as its outdoor endpoint.

A building selection uses that endpoint directly with no invented room or
floor. A classroom selection adds an explicitly labeled indoor allowance.

## 9. Eligibility service

`ParkingEligibilityService.canPark` accepts four explicit inputs:

1. A parking option
2. A permit profile
3. An intended arrival time
4. An optional departure time

The service branches by permit family. S/P enforce assigned zones before 3
p.m., allow general cross-zone parking after 3 p.m. and on weekends, and reject
a planned stay that crosses midnight. Resident profiles use their assigned
facility plus the verified after-hours surface-lot exception. E begins at 5
p.m. on weekdays and works on weekends. ACC-only profiles do not imply campus
access. No-permit profiles see only facilities with a verified on-site visitor
purchase option. MX stays ineligible until motorcycle stalls are represented.

The present markers represent general parking areas, not individual general,
preferred, reserved, pay-by-space, or 24-hour stalls. Holiday rules are also
deliberately deferred. Posted signs always override this prototype.

Keeping the function deterministic is valuable: the same inputs always produce
the same result, making it easy to test and reason about.

## 10. Arrival estimator

`ArrivalEstimator.estimate` converts a `ParkingOption` into an
`ArrivalEstimate`.

### Walking adjustment

```text
hill minutes = ceiling(elevation gain in meters / 12)
adjusted walk = base walk + hill minutes
```

The 12-meter heuristic is intentionally visible and replaceable. A later model
can use an ArcGIS pedestrian route's elevation profile and a more defensible
walking-speed function.

### Expected parking search

```text
failure-risk minutes = round(probability full * fallback penalty)
expected parking = median search + failure-risk minutes
```

Before this formula is evaluated, `LiveParkingEstimator` adjusts the seed
median for the current time bucket. Weekday 9:30 a.m.–2 p.m. is the prototype
peak bucket; weekday shoulders, evenings, and weekends use lower factors.
Fresh reports from the last hour are blended with a two-report baseline
prior and decay as they age. A new report affects the ETA immediately without
allowing one report to replace all historical knowledge.

Tapping **Searching** creates a persistent timer. Tapping **Parked** later
turns it into a measured search duration. Tapping **Parked** directly creates
an availability signal but deliberately does not claim the search took zero
minutes. The card displays adjusted search time, freshness, and confidence.

This is an expected-value calculation. A failure that costs 14 minutes and
occurs 25 percent of the time contributes about 4 minutes to the long-run
average cost.

### Expected total

```text
drive + expected parking + adjusted walk
```

### Conservative total

The cautious total uses the 80th-percentile search time. High-risk options
reserve the full fallback penalty; lower-risk options reserve half. This is a
prototype policy intended to communicate uncertainty, not a trained forecast.

### Destination-aware walking

`DestinationWalkEstimator` replaces the old fixed DBH walk when a parking
recommendation is rendered. Until pedestrian routing is connected, it uses:

```text
outdoor minutes = ceil(
  geodesic parking-to-building distance × 1.25 path factor ÷ 75 meters/minute
)
classroom walk = outdoor minutes + indoor allowance
```

The floor is inferred from UCI's room-number convention and clearly labeled as
inferred. The indoor allowance is two minutes on the first level plus one
minute for each additional level. This is transparent and destination-sensitive
but not presented as indoor turn-by-turn navigation.

## 11. ArcGIS map lifecycle

`ArcGISMapView` creates a native map view and gives the app a controller. Once
the view reports that it is ready, `_onMapReady`:

1. Creates an Esri Light Gray basemap.
2. Assigns it to the controller.
3. Adds a client-side `GraphicsOverlay`.
4. Converts each option's longitude and latitude into an `ArcGISPoint`.
5. Creates green or gray marker graphics based on eligibility.
6. Centers the map over UCI.

The points use WGS 84, the common longitude/latitude spatial reference. In an
`ArcGISPoint`, `x` is longitude and `y` is latitude.

When a user taps the map, `identifyGraphicsOverlay` searches near the screen
pixel for a marker. A lookup map connects the returned ArcGIS `Graphic` to the
app's parking ID. Selecting a card performs the reverse interaction: it updates
the ID and moves the ArcGIS viewpoint toward the corresponding coordinates.

## 12. Ranking and rendering

The `_rankedOptions` getter copies the seed list before sorting it. The copy is
important because Dart's `sort` modifies a list in place, while seed data should
remain a stable source.

The comparison is intentionally lexicographic:

1. Legal before ineligible
2. Lower expected total within the same eligibility group

The resulting list is transformed into widgets by Flutter's collection `for`
syntax. Each `ParkingOptionCard` receives data and callbacks; it does not own
the ranking logic itself.

## 13. Testing strategy

Unit tests call the services directly and assert known outcomes. They do not
need a map, API key, network, or emulator.

The estimator tests protect both exact arithmetic and the higher-level behavior
that a lower-risk option receives a smaller search buffer. The eligibility tests
protect weekday zone enforcement, after-hours flexibility, overnight rejection,
resident access, visitor purchase filtering, and profile serialization.

Run the quality checks with:

```powershell
flutter analyze
flutter test
```

`flutter analyze` finds type, style, and common correctness problems without
running the app. `flutter test` executes the behavioral assertions.

## 14. What is real and what is not yet connected

Real today:

- Android application and Flutter UI
- ArcGIS basemap, viewpoints, overlay markers, and marker identification
- Permit-rule and arrival-estimation services
- Editable, locally persisted parking profile
- Required building/classroom search with a locally persisted selection
- Official building destination marker and room-aware walking estimate
- Device-local Parked/Searching reports, timer, and live ETA updates
- Recommendation sorting and interaction
- Compile-time API-key configuration
- Unit tests

Still mocked:

- Intended arrival/departure time (currently launch + 30 minutes / two hours)
- Starting point input
- ArcGIS driving and walking routes
- ArcGIS elevation queries
- Room-level indoor geometry and turn-by-turn indoor routing
- Authoritative UCI parking polygons and rule records
- Shared/campus-wide observation backend
- Confidence, abuse prevention, and privacy controls

This boundary should be stated clearly in demos. The current version validates
the product concept, software structure, and geographic user experience. Its
“live” values are only as current as reports saved on that device; it does not
claim campus-wide live parking availability.

## 15. How future data should flow

The desired production flow is:

```text
User inputs permit, destination, and desired arrival
        |
Eligibility engine filters authoritative parking areas
        |
ArcGIS routing calculates drive and walking routes
        |
Elevation service characterizes walking effort
        |
Observation model estimates search time and full probability
        |
ArrivalEstimator combines the inputs
        |
UI ranks and explains the recommendations
```

This preserves the current separation: external systems gather inputs, domain
services make decisions, and Flutter/ArcGIS explain the result to the user.
