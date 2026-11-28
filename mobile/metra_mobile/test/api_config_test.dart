import 'package:flutter_test/flutter_test.dart';
import 'package:metra_mobile/api_config.dart';

void main() {
  group('ApiConfig.isValidUrl', () {
    test('accepts HTTPS origins with an optional port', () {
      expect(ApiConfig.isValidUrl('https://api.metra.example'), isTrue);
      expect(ApiConfig.isValidUrl('https://api.metra.example:8443'), isTrue);
      expect(ApiConfig.isValidUrl('https://api.metra.example/'), isTrue);
    });

    test('rejects plaintext HTTP and non-HTTP schemes', () {
      expect(ApiConfig.isValidUrl('http://api.metra.example'), isFalse);
      expect(ApiConfig.isValidUrl('ftp://api.metra.example'), isFalse);
    });

    test('rejects API paths, query strings, and fragments', () {
      expect(ApiConfig.isValidUrl('https://api.metra.example/api/v1'), isFalse);
      expect(
        ApiConfig.isValidUrl('https://api.metra.example?token=x'),
        isFalse,
      );
      expect(
        ApiConfig.isValidUrl('https://api.metra.example#section'),
        isFalse,
      );
    });

    test('rejects embedded credentials and missing hosts', () {
      expect(
        ApiConfig.isValidUrl('https://user:pass@api.metra.example'),
        isFalse,
      );
      expect(ApiConfig.isValidUrl('https:///api'), isFalse);
      expect(ApiConfig.isValidUrl(''), isFalse);
    });

    test('trims surrounding whitespace before validation', () {
      expect(ApiConfig.isValidUrl('  https://api.metra.example  '), isTrue);
    });
  });
}
