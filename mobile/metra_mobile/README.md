# METRA 2027 — Mobile (Flutter)

This is the independent native mobile client for Android and iOS. It does not depend on the Angular web application.

## Requirements
- Flutter stable SDK (Dart 3.6+)
- Android Studio / Android SDK for Android
- Xcode on macOS for iOS builds

## Generate native platform runners (first setup)
The repository currently contains the Flutter source and package configuration. From this directory run:
```bash
flutter create --platforms=android,ios .
```
This generates Android and iOS runner projects using the installed Flutter SDK.

## Run independently
```bash
flutter pub get
flutter run
```

## Build
```bash
flutter build apk
flutter build appbundle
# On macOS:
flutter build ios
```

## API endpoint
Override the API address at run/build time:
```bash
flutter run --dart-define=METRA_API_BASE_URL=https://your-api-host/api/v1
```
The default development address uses Android emulator host `10.0.2.2`; for a physical phone, pass a reachable LAN or HTTPS address.

## Independence
- No Node.js or Angular CLI is required.
- No .NET SDK is required to run the mobile UI.
- The Flutter app owns its dependencies and native platform runners.
- Mobile code calls the backend API; it must not connect directly to PostgreSQL/Supabase.
