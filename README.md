# ZotETA

ZotETA is a mobile-first UCI parking planner that ranks legal parking options
by total expected arrival time:

```text
drive + parking search + hill-adjusted walk + full-lot risk
```

The prototype uses Flutter and Esri's official ArcGIS Maps SDK for Flutter.

## Learn the codebase

Start with [`docs/architecture.md`](docs/architecture.md) for a beginner-friendly
walkthrough of Flutter, Dart, Android, ArcGIS, every hand-written app layer, the
arrival formulas, testing, and the current prototype boundaries. The Dart source
also contains documentation comments explaining each model, service, and major
map/UI operation in context.

## What works now

- ArcGIS map centered on UCI with six parking options
- First-launch permit onboarding with editable S, P, R, E, MX, ACC, and
  no-permit profiles
- Local-only profile storage with no login or backend
- Time-aware S/P zone, resident, evening, and paid-visitor eligibility
- Expected and conservative total-time estimates
- Parking-search and failed-lot penalties
- Hill-adjusted walking time
- Mobile recommendation sheet and map selection
- Unit tests for permit and arrival-time logic

The permit rules and displayed rates were checked in September 2026 against
UCI Transportation's official [student permit rules](https://parking.uci.edu/permits/student/),
[visitor permit options](https://parking.uci.edu/permits/visitor/), and
[published rate table](https://parking.uci.edu/permits/rates/). The rate table
currently labels its values as 2025–2026. Posted signs and current UCI guidance
always override the prototype.

Parking times, live reports, and coordinates are explicitly seed/demo data.
They must not be presented as live UCI availability.

## One-time setup

1. Install Android Studio and allow its setup wizard to install the Android SDK,
   platform tools, and an Android emulator.
2. In a terminal, run `flutter doctor` and accept any requested Android licenses.
3. Create a free ArcGIS Location Platform account and API key. Leave
   pay-as-you-go disabled.
4. Copy `config.example.json` to `config.json` and paste the key into the new
   file. `config.json` is ignored by Git.

The ArcGIS Flutter runtime is also ignored by Git. After cloning the project,
install it with:

```powershell
dart pub get
dart run arcgis_maps install
```

On Windows, Esri recommends enabling Developer Mode so the installer can create
a local symlink. A normal local `arcgis_maps_core` directory also works.

## Run on Android

Start an Android emulator, then run:

```powershell
flutter run --dart-define-from-file=config.json
```

Windows can build the Android version. Building the iOS version requires macOS
and Xcode.

## Validate

```powershell
flutter analyze
flutter test
```

## Next slices

1. Add editable arrival time, destination, and planned departure.
2. Represent parking facilities as area/stall-category polygons, including
   preferred, reserved, motorcycle, pay-by-space, and 24-hour restrictions.
3. Add voluntary `started searching`, `parked`, `gave up`, and `leaving`
   observations.
4. Replace demo search estimates with time-bucketed observations and confidence.
5. Add ArcGIS routing and Elevation service calls.
