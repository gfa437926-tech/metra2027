# Flutter runtime configuration

The standalone Flutter app reads its API base URL from the compile-time
environment variable `METRA_API_BASE_URL` through `String.fromEnvironment`.
The value must be the HTTPS API origin (scheme and host, with an optional port),
not the website URL and not a Supabase URL. The Flutter API client appends
`/api/v1` to this origin automatically; do not include that path in the define.

## Run against a deployed API

```powershell
cd mobile/metra_mobile
flutter pub get
flutter run --dart-define=METRA_API_BASE_URL=https://api.example.gov.sy
```

Replace the example with the approved environment endpoint. Do not commit real
production hostnames if they are classified/internal, tokens, service-role keys,
or credentials. Use a separate endpoint for development, test, and production.

## Local and LAN development

The current Flutter URL validator intentionally accepts HTTPS only. For local
development, use an HTTPS reverse proxy or configure a dedicated development
build policy; do not weaken the production validator or ship a plaintext
endpoint. Android emulator `localhost` is the emulator itself, not the host PC;
a physical device needs the reachable LAN address of the API host and firewall
access. Keep the API's CORS policy restricted to the actual web origins; CORS
does not replace API authentication.

## Release checklist

- [ ] Confirm the API is reachable and `GET /api/v1/health` succeeds.
- [ ] Confirm `GET /api/v1/ready` succeeds only after server-side Supabase and
      authentication settings are configured.
- [ ] Use the correct environment's HTTPS API base for the API origin (without `/api/v1`).
- [ ] Never put the Supabase service-role key in Flutter compile-time defines.
- [ ] Test login, authenticated API calls, logout, and expired-session behavior
      on the target device before distributing a release.

The app's API configuration is intentionally empty by default. A successful
Flutter build does not mean the API is configured or deployed.
