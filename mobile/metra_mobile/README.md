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
flutter run \\
  --dart-define=METRA_API_BASE_URL=https://your-api-host \\
  --dart-define=METRA_SUPABASE_URL=https://your-project.supabase.co \\
  --dart-define=METRA_SUPABASE_PUBLISHABLE_KEY=your-publishable-key
```

## Build
```bash
flutter build apk \\
  --dart-define=METRA_API_BASE_URL=https://your-api-host \\
  --dart-define=METRA_SUPABASE_URL=https://your-project.supabase.co \\
  --dart-define=METRA_SUPABASE_PUBLISHABLE_KEY=your-publishable-key
flutter build appbundle \\
  --dart-define=METRA_API_BASE_URL=https://your-api-host \\
  --dart-define=METRA_SUPABASE_URL=https://your-project.supabase.co \\
  --dart-define=METRA_SUPABASE_PUBLISHABLE_KEY=your-publishable-key
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
- Supabase email/password sign-in, persisted session restoration and SDK-managed token refresh.
- Station selection in the mobile shell. The API remains the authority for station-level permissions; selecting a catalogue record does not grant review rights.
- Live weather feed, alerts and operational reports remain pending.

The app initializes Supabase only when both Supabase compile-time values are present. The login screen uses the existing account flow; it does not create users. The Supabase session is stored through flutter_secure_storage (Android encrypted storage / iOS Keychain), restored on startup, refreshed by the SDK, and removed on sign-out. The PKCE verifier storage remains managed by Supabase's Flutter adapter. The API token provider reads the current access token at request time. Configure the API origin separately with METRA_API_BASE_URL. Only a Supabase publishable key belongs in the mobile binary; never pass a service-role or secret key to Flutter.

The app deliberately shows explicit unavailable/connection states instead of sample temperatures, invented station coordinates, or fake operational records. Do not bypass authorization by inserting a fixed station ID or token.

## Independence and security
- No Node.js or Angular CLI is required.
- No .NET SDK is required to run the mobile shell.
- Mobile code calls the backend API; it must not connect directly to PostgreSQL/Supabase operational tables.
- The Supabase service-role key belongs only in server-side API configuration.


## Station map
The station directory defaults to a geographic map with separate symbols for classic and automatic stations, plus a list view and type filters. It fetches the paginated station catalogue (up to the API client's explicit 10,000-row safety ceiling), plots only validated catalogue coordinates, and reports records without coordinates rather than fabricating positions. Map tiles use OpenStreetMap; production deployments must follow the tile provider's usage policy and attribution requirements.
