# Ride Metrics

<p align="center">
  <img src="assets/ride_metrics_logo.png" alt="Ride Metrics logo" width="160" />
</p>

<p align="center"><strong>Offline vehicle fuel, mileage, document, and maintenance tracking for bikes and cars.</strong></p>

Ride Metrics is a focused Flutter application for people who want a simple, private way to understand the running cost and maintenance history of every vehicle they own. It stores data locally on the device, works without an account, and keeps the experience centered on vehicles only.

## Why this project is useful

Vehicle information is often scattered across paper documents, fuel receipts, service bills, and memory. Ride Metrics brings those records together into one vehicle-specific dashboard with calculations that become more useful as the user adds fuel entries.

## Product highlights

- Vehicle-first home screen with compact tiles for every registered vehicle
- Bike and car profiles with registration, model, year, engine capacity, tank capacity, and odometer reading
- Fuel entry in two modes: total amount paid or litres plus price per litre
- Automatic fuel calculations for litres, price, cost, mileage, spending, and estimated range
- Editable fuel entries so incorrect odometer, price, or quantity values can be corrected
- Vehicle deletion with confirmation, plus automatic odometer synchronization from fuel records
- Vehicle document vault for RC, insurance, pollution certificate, driving licence, and custom documents
- Tap-to-open document viewer for saved images and PDFs
- Service reminders for oil change, tyre pressure, chain service, brakes, insurance, PUC, and custom services
- Trip fuel budget planner based on the selected vehicle's recorded mileage and fuel price history
- Weekly and monthly mileage and spending trends
- Fuel-station history with station, distance, mileage, and price comparisons
- Offline-first local JSON persistence with no account or server dependency
- Vehicle-focused dark UI with a custom app logo and Android launcher icon

## Screens and flow

1. The opening screen lists all vehicles and provides an **Add vehicle** tile.
2. Selecting a vehicle opens its dashboard and vehicle-specific features.
3. Fuel records feed the dashboard statistics, mileage calculations, budget planner, and insights.
4. Documents are hidden until the user taps a document name, keeping sensitive images out of the normal list view.
5. Services and expiry dates are tracked per vehicle so reminders do not get mixed between vehicles.

## Technical overview

| Area | Implementation |
| --- | --- |
| UI | Flutter and Material components |
| Language | Dart |
| Persistence | Local JSON file using `path_provider` |
| Documents | `file_picker` with local file copies |
| PDF viewing | `flutter_pdfview` |
| Location | `geolocator` for optional fuel-station coordinates |
| Charts | Custom Flutter painters for mileage and spending trends |
| Validation | Flutter widget tests and release APK build |

The code is intentionally organized around the vehicle domain:

```text
lib/
  main.dart      UI, forms, dashboards, charts, and feature flows
  models.dart    Vehicle, FuelRecord, VehicleDocument, and ServiceItem models
  store.dart     Local persistence and document file management
assets/
  ride_metrics_logo.png
```

## Run locally

Requirements:

- Flutter SDK with Dart 3.13.5 or newer
- Android Studio or an Android SDK for Android builds

```bash
flutter pub get
flutter test
flutter run
```

## Download the APK

The latest installable Android build is available from the repository's dedicated APK branch:

[Download the latest Ride Metrics APK](https://github.com/Akhilbendi/ride-metrics/raw/refs/heads/release-apk/ride_metrics.apk)

The APK is kept on a separate branch so the main source branch remains lightweight while still providing a direct download for demos and interviews.

## Build the Android APK

```bash
flutter build apk --release
```

The generated APK is written to:

```text
build/app/outputs/flutter-apk/app-release.apk
```


