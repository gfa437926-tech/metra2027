/// API configuration for the standalone Flutter client.
///
/// Override at run/build time with:
/// flutter run --dart-define=METRA_API_BASE_URL=https://api.example.com/api/v1
class ApiConfig {
  ApiConfig._();

  /// Enable only after the approved identity provider and API endpoint are deployed.
  static const bool identityContextEnabled = bool.fromEnvironment(
    'METRA_IDENTITY_CONTEXT_ENABLED',
    defaultValue: false,
  );

  static const String baseUrl = String.fromEnvironment(
    'METRA_API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5000/api/v1',
  );
}
