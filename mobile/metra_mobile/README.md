# METRA 2027 Mobile (Flutter)

This is the standalone native mobile application. It does not require the Angular web application or the .NET API to launch.

## Requirements

- Flutter stable SDK
- Android Studio and Android SDK for Android
- macOS and Xcode for iOS

## Generate native platform projects

Native runner folders are generated with Flutter tooling:

```bash
flutter create --platforms=android,ios .
```

On Windows/Linux, use `flutter create --platforms=android .`. iOS builds require macOS.

## Install and run

```bash
flutter pub get
flutter run
```

## Build

```bash
flutter build apk
```

For iOS (on macOS): `flutter build ios`.

## API configuration

The future API client will read `METRA_API_BASE_URL` from a Dart compile-time define. Example:

```bash
flutter run --dart-define=METRA_API_BASE_URL=http://10.0.2.2:5000
```

Android emulator uses `10.0.2.2` to reach the host machine. A physical phone must use the computer's reachable LAN address. The current starter screens do not require an API connection.
