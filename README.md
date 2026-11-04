# METRA 2027

METRA 2027 is organized as three independently runnable applications:

| Application | Technology | Folder | Local development |
|---|---|---|---|
| Web | Angular 20 | `angular-app/` | http://localhost:4200 |
| Mobile | Flutter | `mobile/metra_mobile/` | Android / iOS device or emulator |
| Backend API | ASP.NET Core 10 / C# | `backend/Metra.Api/` | http://localhost:5000 |

## Architecture and current integration

The web, mobile, and API applications have independent build and startup lifecycles. The ASP.NET Core API is the only intended application backend and owns privileged database access.

The repository currently includes:
- Angular authentication and guards for operational routes.
- Angular daily and hourly report submission through the secured API when runtime configuration is present. Local drafts/previews remain local and are not represented as server submissions.
- Flutter API configuration validation and a configuration gate, plus a combined classic/automatic station map.
- ASP.NET Core JWT authentication, station-scoped authorization, a read-only station directory, observation submission, review queue/decision endpoints, validation, and health/readiness endpoints.
- Supabase migrations for the operational observation workflow.

**Production integration is not yet complete.** The API container is published to GitHub Container Registry, but it still needs a production host, valid server-side Supabase service-role configuration, allowed client origins, and client runtime configuration. The deployed Pages UI must not be assumed to have live API connectivity until these settings and real requests are verified. Some weather and workflow values in the clients remain demo/sample data and are not live meteorological observations.

## Run only the web application

Requirements: Node.js compatible with Angular 20 and npm.

```bash
cd angular-app
npm install
npm start
```

Open http://localhost:4200. Production build: `npm run build`.

## Run only the mobile application

Requirements: Flutter stable SDK, Android Studio / Android SDK for Android, and Xcode on macOS for iOS.

Generate native platform runner folders once if they are not present:

```bash
cd mobile/metra_mobile
flutter create --platforms=android,ios .
flutter pub get
flutter run
```

On Windows or Linux, generate Android only with `flutter create --platforms=android .`. iOS builds require macOS and Xcode.

Supply the API origin at build/run time (scheme + host, optional port; do not append `/api/v1`). The current Flutter client intentionally accepts HTTPS only, including during development. Use an HTTPS development endpoint or reverse proxy reachable from the device:

```bash
flutter run --dart-define=METRA_API_BASE_URL=https://your-development-api.example.test
```

The API client appends `/api/v1` automatically. Do not use `localhost` from a physical device, and do not weaken the production HTTPS validation for emulator convenience.

## Run only the backend API

Requirements: .NET 10 SDK.

```bash
cd backend/Metra.Api
dotnet restore
dotnet run
```

The launch profile listens on http://localhost:5000. Health endpoint: `GET http://localhost:5000/api/v1/health`. Readiness endpoint: `GET http://localhost:5000/api/v1/ready`. OpenAPI is available in Development at `/openapi/v1.json`.

For deployment, required environment variables, container details, and verification steps, see [Backend deployment guide](backend/DEPLOYMENT.md).

## Station data quality

A read-only audit of station coordinates is maintained in [Station coordinate completeness audit](docs/data-quality/station-coordinate-audit.md). It identifies catalogue records that remain visible in the directory but cannot yet be plotted because verified coordinates are missing.

## Data protection and configuration

- The new Supabase project is the intended target: `https://tbdnklyxjvbrilvnwgmq.supabase.co`.
- Never place the Supabase service-role key in Angular, Flutter, browser runtime configuration, source control, or client build arguments. It belongs only in the API host's secret store.
- Browser origins are configured with `Cors:AllowedOrigins` on the API host.
- Angular Pages runtime configuration is injected by the deployment workflow from GitHub Actions secrets. Empty or missing secrets leave the client unconfigured.
- Flutter uses `METRA_API_BASE_URL` via `--dart-define`; Supabase client configuration must use a publishable/anon key only.
- The legacy database is not a deployment target and must remain unchanged. Do not run destructive migrations or data changes against it.

## Verification status

Latest backend CI run: [Backend build #766](https://github.com/gfa437926-tech/metra2027/actions/runs/41778894826) passed on commit `0f0cc07e037d9828ade09ed0ab3c887abf73396d`. It verified the authority access lifecycle contract (including scheduled approved access), built the API, passed domain/API tests, and built the production container image. Client CI and GitHub Pages deployment have also passed on a prior main commit; rerun them after relevant client changes.

A successful CI run or container publish is not the same as a live API deployment. Production readiness requires a deployed HTTPS API, configured secrets and CORS, successful `/health` and `/ready` checks, and authenticated end-to-end tests. Real identity and authority-access tests, administrator onboarding, and verified missing station coordinates remain outstanding.
