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

## Secure integration status

The Flutter client is API-only. It must never contain a Supabase secret or service-role key and must not connect directly to protected database tables.

Implemented foundations:

- Arabic-first Material 3 shell and current-user context presentation.
- Typed station catalogue models preserving source-qualified classic/automatic identity.
- Paged station catalogue HTTP client with strict response validation, cursor checks, coordinate-pair validation and explicit unauthenticated/forbidden/unavailable states.
- Mocked tests for disabled integration, token absence, mixed source types, pagination, malformed data and authorization failures.

All integration remains disabled by default:

- `METRA_IDENTITY_CONTEXT_ENABLED=false`
- `METRA_STATION_CATALOGUE_ENABLED=false`

Keep the station catalogue gate disabled until the ASP.NET Core API has a trusted PostgreSQL read adapter, the owner approves an explicit station-catalogue read permission and station-scope semantics, and the mobile app has a real identity provider integration that supplies short-lived access tokens through `AccessTokenProvider` using platform-secure storage. Do not infer read permission from a role or station assignment. The current API deliberately returns unavailable while its authorization-aware read store is not registered.

Example configuration after those gates are met:

```bash
flutter run \
  --dart-define=METRA_API_BASE_URL=https://<approved-api-host>/api/v1 \
  --dart-define=METRA_IDENTITY_CONTEXT_ENABLED=true \
  --dart-define=METRA_STATION_CATALOGUE_ENABLED=true
```

No real host, credential, token or key is committed. The Flutter CI workflow pins its SDK version, resolves dependencies, checks Dart formatting, runs static analysis and executes unit tests. A short-lived artifact preserves the generated `pubspec.lock` so it can be committed for reproducible builds.
