# METRA 2027 — Mobile (Flutter)

Independent Flutter client for Android and iOS.

## Requirements
- Flutter stable SDK (Dart 3.6+)
- Android Studio / Android SDK for Android
- Xcode on macOS for iOS builds

## Generate native platform runners (first setup)
The repository currently contains the Flutter source and package configuration. From this directory run:
```bash
flutter create --platforms=android,ios .
```

## Run and test
```bash
flutter pub get
flutter analyze
flutter test
flutter run --dart-define=METRA_API_BASE_URL=https://your-api-host
```

## Build
```bash
flutter build apk --dart-define=METRA_API_BASE_URL=https://your-api-host
flutter build appbundle --dart-define=METRA_API_BASE_URL=https://your-api-host
# On macOS:
flutter build ios --dart-define=METRA_API_BASE_URL=https://your-api-host
```

## API, authentication and operational boundaries

The API client is in `lib/core/api/metra_api_client.dart`. Configure the HTTPS API **origin** (without `/api/v1`) using `METRA_API_BASE_URL`. The client requires an access-token provider supplied by the authentication layer, sends a Bearer token, and never embeds a Supabase service-role key.

Implemented client capabilities:
- Read a station's submitted observation review queue.
- Submit an observation with an idempotency key.
- Approve or return a submitted observation, requiring a correction reason for returns.
- Review screen with loading, empty, error, confirmation and refresh states.

Not yet connected end-to-end:
- Supabase sign-in, persisted session and secure token refresh.
- Authorized station discovery/selection and role-aware navigation.
- Live weather feed, complete station map, alerts and reports.

The app deliberately shows explicit unavailable/connection states instead of sample temperatures, invented station coordinates, or fake operational records. Do not bypass authorization by inserting a fixed station ID or token.

## Independence and security
- No Node.js or Angular CLI is required.
- No .NET SDK is required to run the mobile shell.
- Mobile code calls the backend API; it must not connect directly to PostgreSQL/Supabase operational tables.
- The Supabase service-role key belongs only in server-side API configuration.
