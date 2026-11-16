import 'package:flutter_test/flutter_test.dart';
import 'package:metra_mobile/core/api/metra_api_client.dart';

void main() {
  group('MetraApiException.displayMessage', () {
    test('returns Arabic messages for known codes', () {
      expect(
        const MetraApiException(401, 'authentication_required').displayMessage,
        contains('الجلسة'),
      );
      expect(
        const MetraApiException(0, 'network_unavailable').displayMessage,
        contains('الشبكة'),
      );
      expect(
        const MetraApiException(0, 'timeout').displayMessage,
        contains('مهلة'),
      );
      expect(
        const MetraApiException(403, 'request_failed').displayMessage,
        anyOf(contains('صلاحية'), contains('الجلسة')),
      );
      expect(
        const MetraApiException(500, 'request_failed').displayMessage,
        contains('الخادم'),
      );
      expect(
        const MetraApiException(409, 'request_failed').displayMessage,
        anyOf(contains('تعارض'), contains('مسبقاً')),
      );
      expect(
        const MetraApiException(503, 'api_not_configured').displayMessage,
        contains('METRA'),
      );
    });

    test('prefers explicit userMessage when provided', () {
      const error = MetraApiException(
        400,
        'custom',
        userMessage: 'رسالة مخصصة للمستخدم',
      );
      expect(error.displayMessage, 'رسالة مخصصة للمستخدم');
    });

    test('does not expose stack traces or English technical codes to user', () {
      const cases = [
        MetraApiException(401, 'authentication_required'),
        MetraApiException(0, 'network_unavailable'),
        MetraApiException(0, 'timeout'),
        MetraApiException(500, 'request_failed'),
        MetraApiException(403, 'request_failed'),
        MetraApiException(404, 'request_failed'),
        MetraApiException(400, 'invalid_station_id'),
      ];
      for (final error in cases) {
        final message = error.displayMessage;
        expect(message, isNot(contains('Exception')));
        expect(message, isNot(contains('StackTrace')));
        expect(message, isNot(contains('SocketException')));
        expect(message, isNot(contains('null')));
        // Code itself should not appear as the primary user text.
        expect(message, isNot(equals(error.code)));
      }
    });

    test('toString remains technical for logs only', () {
      const error = MetraApiException(401, 'authentication_required');
      expect(error.toString(), contains('MetraApiException'));
      expect(error.toString(), contains('401'));
      expect(error.toString(), contains('authentication_required'));
    });
  });
}
