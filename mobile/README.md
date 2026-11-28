# METRA 2027 Mobile

The native mobile client is built with Flutter and targets Android and iOS.

## Run

```bash
cd mobile/metra_mobile
flutter pub get
flutter run
```

The first scaffold contains Arabic RTL navigation and entry points for daily, hourly, monthly/yearly, agricultural, and soil-temperature records. Forms and API calls will be added as each workflow is approved.

The app will communicate only with the shared ASP.NET Core API; it will not connect directly to PostgreSQL/Supabase.
