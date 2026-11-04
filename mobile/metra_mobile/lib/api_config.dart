/// API configuration for the standalone Flutter client.
///
/// Supply the deployed HTTPS API origin at build/run time:
/// flutter run --dart-define=METRA_API_BASE_URL=https://api.your-domain.example
///
/// The value is intentionally empty by default. Never ship an emulator-only or
/// plaintext HTTP endpoint in a production build.
class ApiConfig {
  ApiConfig._();

  static const String baseUrl = String.fromEnvironment('METRA_API_BASE_URL');

  static bool get isConfigured => isValidUrl(baseUrl);

  static bool isValidUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    return uri != null &&
        uri.isAbsolute &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        !uri.hasQuery &&
        !uri.hasFragment;
  }
}
