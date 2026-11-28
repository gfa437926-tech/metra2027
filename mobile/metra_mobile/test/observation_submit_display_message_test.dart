import 'package:flutter_test/flutter_test.dart';
import 'package:metra_mobile/core/api/metra_api_client.dart';

void main() {
  test('displayMessage covers auth, permission, conflict, server, network', () {
    final cases = <MetraApiException, List<String>>{
      const MetraApiException(401, 'request_failed'): [
        'جلسة',
        'صلاحية',
        'الدخول',
      ],
      const MetraApiException(403, 'request_failed'): [
        'جلسة',
        'صلاحية',
        'الدخول',
      ],
      const MetraApiException(409, 'request_failed'): [
        'تعارض',
        'مُرسلة',
        'مسبقاً',
      ],
      const MetraApiException(503, 'request_failed'): [
        'الخادم',
        'لاحقاً',
        'الدعم',
      ],
      const MetraApiException(503, 'api_not_configured'): [
        'METRA',
        'مضبوط',
        'الاتصال',
      ],
      const MetraApiException(0, 'network_unavailable'): ['الاتصال', 'الشبكة'],
      const MetraApiException(0, 'timeout'): ['مهلة', 'الاتصال'],
      const MetraApiException(401, 'authentication_required'): [
        'جلسة',
        'الدخول',
      ],
    };

    for (final entry in cases.entries) {
      final message = entry.key.displayMessage;
      expect(message, isNot(contains('Exception')));
      expect(message, isNot(contains('Stack')));
      expect(message, isNot(contains('null')));
      expect(
        entry.value.any(message.contains),
        isTrue,
        reason:
            'code=${entry.key.code} status=${entry.key.statusCode} message=$message',
      );
    }
  });

  test(
    'status-only fallback does not expose raw technical codes to operators',
    () {
      const error = MetraApiException(500, 'request_failed');
      expect(error.displayMessage, isNot(contains('request_failed')));
      expect(error.displayMessage, isNotEmpty);
    },
  );
}
