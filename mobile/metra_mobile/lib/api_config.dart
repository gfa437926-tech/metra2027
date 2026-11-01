/// API configuration for the standalone Flutter client.
///
/// Override at run/build time with:
/// flutter run --dart-define=METRA_API_BASE_URL=https://api.example.com/api/v1
class ApiConfig {
  ApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'METRA_API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5000/api/v1',
  );
}
