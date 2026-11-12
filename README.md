# WSU Bus Transport

A university Flutter project by Yandisa Mbentsula exploring student
transport management through student, driver and manager portals.

## Features

- Firebase Authentication with registration, sign-in and password reset.
- Role-based student, driver and manager interfaces.
- Student funding-status display.
- Shared active and completed trips stored in Cloud Firestore.
- Driver trip creation and completion.
- QR scanning and manual student-number boarding.
- Duplicate-boarding prevention and per-trip boarding limits.
- Bus location sharing and map display.
- Manager fleet overview and boarding records.

## Technologies

Flutter, Dart, Firebase Authentication, Cloud Firestore,
flutter_map and OpenStreetMap.

## Current limitations

- Boarding eligibility currently uses sample student records rather than
  a university funding-system integration.
- Location sharing currently requires the driver map page to remain open
  with the app in the foreground.
- Boarding counts represent accepted boardings, not current occupancy:
  passengers getting off are not tracked.
- Some legacy local-storage code remains in the source.
- Full end-to-end acceptance testing is still pending.
- This is an academic prototype, not an official university service.

## Setup

1. Install Flutter and the tooling for your target platform.
2. Run `flutter pub get`.
3. Configure your own Firebase project using FlutterFire.
4. Enable Email/Password authentication and create a Firestore database.
5. Configure the required Firestore security rules and indexes.
6. Provision authorised driver and manager profiles.
7. Run `flutter run -d chrome`, or select a connected Android device.

Firebase client configuration alone does not grant database access.
Never include service-account private keys or test-account passwords
in the repository.

## Validation

`flutter analyze` completed with no issues during development.
The application has been launched in Chrome and on Android.
This does not mean every feature has passed acceptance testing.

## Maps

Map data is provided by OpenStreetMap contributors.
Tile usage must comply with the selected provider's usage policy.
