# METRA 2027

METRA 2027 is organized as three independently runnable applications:

| Application | Technology | Folder | Local development |
|---|---|---|---|
| Web | Angular 20 | `angular-app/` | http://localhost:4200 |
| Mobile | Flutter | `mobile/metra_mobile/` | Android / iOS device or emulator |
| Backend API | ASP.NET Core 10 / C# | `backend/Metra.Api/` | http://localhost:5000 |

## Independent operation

Each application has its own project files, dependencies, startup command, and development lifecycle. You can run and develop any one without starting the other two.

The Angular and Flutter clients will use the ASP.NET Core API when API integration is implemented. The API is a separate service. The current client scaffolds can launch in UI-only mode without it.

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

Generate native platform runner folders once:

```bash
cd mobile/metra_mobile
flutter create --platforms=android,ios .
flutter pub get
flutter run
```

On Windows or Linux, generate Android only with `flutter create --platforms=android .`. iOS builds require macOS and Xcode.

## Run only the backend API

Requirements: .NET 10 SDK.

```bash
cd backend/Metra.Api
dotnet restore
dotnet run
```

The launch profile listens on http://localhost:5000. Health endpoint: `GET http://localhost:5000/api/v1/health`. OpenAPI is available in Development at `/openapi/v1.json`.

## Configuration and data

- Browser CORS origins are configured in `backend/Metra.Api/appsettings.json`.
- Flutter's API base URL can be overridden with `--dart-define=METRA_API_BASE_URL=http://10.0.2.2:5000/api/v1` on the Android emulator.
- Do not commit credentials, signing keys, database passwords, or production secrets.
- ASP.NET Core is the intended and only application backend. No database schema or Supabase project/access policy is changed by this scaffold.

## Current scope

The repository contains independent application entry points and starter interfaces. Full climate-record workflows, authentication, API integration, and persistence are subsequent implementation tasks and are not represented as completed.
