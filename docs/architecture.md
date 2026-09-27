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
  models/parking_option.dart        domain vocabulary
  data/sample_parking_data.dart     prototype inputs
  services/arrival_estimator.dart   travel-time calculations
  services/parking_eligibility_service.dart
                                    permit rules
  screens/parking_map_screen.dart   ArcGIS map and Flutter interface

test/
  arrival_estimator_test.dart
  parking_eligibility_service_test.dart
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
  -> MaterialApp builds ParkingMapScreen
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

## 7. Seed data boundary

`sample_parking_data.dart` creates six `ParkingOption` objects. This is a local,
in-memory list: it does not query UCI, ArcGIS, or a database.

The coordinates place prototype point markers. All travel-time, elevation,
availability, and community-report values are demonstrations. Centralizing
them makes it straightforward to replace their source later while preserving
the objects consumed by the rest of the app.

## 8. Eligibility service

`ParkingEligibilityService.canPark` accepts three explicit inputs:

1. A parking option
2. A permit profile
3. An intended arrival time

The prototype assumes cross-zone flexibility on weekends and after 3 p.m. On a
weekday before 3 p.m., it checks whether the option's zone set contains the
permit zone. This is a simplified rule model, not an authoritative statement of
all UCI, ARC, ACC, stall, event, or overnight restrictions.

Keeping the function deterministic is valuable: the same inputs always produce
the same result, making it easy to test and reason about.

## 9. Arrival estimator

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

## 10. ArcGIS map lifecycle

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

## 11. Ranking and rendering

The `_rankedOptions` getter copies the seed list before sorting it. The copy is
important because Dart's `sort` modifies a list in place, while seed data should
remain a stable source.

The comparison is intentionally lexicographic:

1. Legal before ineligible
2. Lower expected total within the same eligibility group

The resulting list is transformed into widgets by Flutter's collection `for`
syntax. Each `ParkingOptionCard` receives data and callbacks; it does not own
the ranking logic itself.

## 12. Testing strategy

Unit tests call the services directly and assert known outcomes. They do not
need a map, API key, network, or emulator.

The estimator tests protect both exact arithmetic and the higher-level behavior
that a lower-risk option receives a smaller search buffer. The eligibility tests
protect weekday zone enforcement and after-hours flexibility.

Run the quality checks with:

```powershell
flutter analyze
flutter test
```

`flutter analyze` finds type, style, and common correctness problems without
running the app. `flutter test` executes the behavioral assertions.

## 13. What is real and what is not yet connected

Real today:

- Android application and Flutter UI
- ArcGIS basemap, viewpoints, overlay markers, and marker identification
- Permit-rule and arrival-estimation services
- Recommendation sorting and interaction
- Compile-time API-key configuration
- Unit tests

Still mocked:

- User permit and intended arrival time
- Starting point and destination input
- ArcGIS driving and walking routes
- ArcGIS elevation queries
- Authoritative UCI parking polygons and rule records
- Live availability observations and a backend
- Confidence, abuse prevention, and privacy controls

This boundary should be stated clearly in demos. The current version validates
the product concept, software structure, and geographic user experience; it
does not claim to know live parking availability.

## 14. How future data should flow

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
