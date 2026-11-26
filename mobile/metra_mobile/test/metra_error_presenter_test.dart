import 'package:flutter_test/flutter_test.dart';
import 'package:metra_mobile/core/api/metra_api_client.dart';
import 'package:metra_mobile/core/errors/metra_error_presenter.dart';

void main() {
  test('maps MetraApiException network code via displayMessage path', () {
    const error = MetraApiException(503, 'network_unavailable');
    expect(MetraErrorPresenter.messageFor(error), contains('الاتصال'));
  });

  test('status mapping for 400 401 403 404 409 422 429 500', () {
    expect(
      MetraErrorPresenter.forApiException(
        const MetraApiException(400, 'request_failed'),
      ),
      contains('غير صالحة'),
    );
    expect(
      MetraErrorPresenter.forApiException(
        const MetraApiException(401, 'request_failed'),
      ),
      contains('الدخول'),
    );
    expect(
      MetraErrorPresenter.forApiException(
        const MetraApiException(403, 'request_failed'),
      ),
      contains('صلاحية'),
    );
    expect(
      MetraErrorPresenter.forApiException(
        const MetraApiException(404, 'request_failed'),
      ),
      contains('غير موجود'),
    );
    expect(
      MetraErrorPresenter.forApiException(
        const MetraApiException(409, 'request_failed'),
      ),
      contains('تعارض'),
    );
    expect(
      MetraErrorPresenter.forApiException(
        const MetraApiException(422, 'request_failed'),
      ),
      contains('غير صالحة'),
    );
    expect(
      MetraErrorPresenter.forApiException(
        const MetraApiException(429, 'request_failed'),
      ),
      contains('حد الطلبات'),
    );
    expect(
      MetraErrorPresenter.forApiException(
        const MetraApiException(500, 'request_failed'),
      ),
      contains('الخادم'),
    );
  });

  test('review decision messages for 401 403 409', () {
    expect(
      MetraErrorPresenter.reviewDecisionMessage(
        const MetraApiException(401, 'request_failed'),
      ),
      contains('الجلسة'),
    );
    expect(
      MetraErrorPresenter.reviewDecisionMessage(
        const MetraApiException(403, 'request_failed'),
      ),
      'ليست لديك صلاحية تنفيذ هذا القرار',
    );
    expect(
      MetraErrorPresenter.reviewDecisionMessage(
        const MetraApiException(409, 'request_failed'),
      ),
      contains('مسبقاً'),
    );
  });

  test('submit and queue load messages stay operator-safe', () {
    expect(
      MetraErrorPresenter.submitMessage(
        const MetraApiException(403, 'request_failed'),
      ),
      contains('إرسال'),
    );
    expect(
      MetraErrorPresenter.queueLoadMessage(
        const MetraApiException(403, 'request_failed'),
      ),
      contains('مراجعة'),
    );
  });

  test('registration decision messages for 403 409 503', () {
    expect(
      MetraErrorPresenter.registrationDecisionMessage(
        const MetraApiException(403, 'request_failed'),
      ),
      contains('صلاحية'),
    );
    expect(
      MetraErrorPresenter.registrationDecisionMessage(
        const MetraApiException(409, 'request_failed'),
      ),
      contains('مسبقاً'),
    );
    expect(
      MetraErrorPresenter.registrationDecisionMessage(
        const MetraApiException(503, 'request_failed'),
      ),
      contains('غير متاحة'),
    );
  });

  test('timeout and connection refused map to network guidance', () {
    expect(
      MetraErrorPresenter.messageFor(Exception('Connection timed out')),
      contains('مهلة'),
    );
    expect(
      MetraErrorPresenter.messageFor(Exception('Connection refused')),
      contains('الاتصال'),
    );
  });

  test('does not leak exception type names for unknown errors', () {
    final message = MetraErrorPresenter.messageFor(StateError('secret-token'));
    expect(message.toLowerCase(), isNot(contains('stateerror')));
    expect(message.toLowerCase(), isNot(contains('secret-token')));
  });

  test('assignment messages map role and permission failures', () {
    expect(
      MetraErrorPresenter.assignmentMessage(
        const MetraApiException(400, 'assignment_role_unavailable'),
      ),
      contains('الدور'),
    );
    expect(
      MetraErrorPresenter.assignmentMessage(
        const MetraApiException(403, 'request_failed'),
      ),
      contains('صلاحية'),
    );
    expect(
      MetraErrorPresenter.assignmentMessage(
        const MetraApiException(503, 'request_failed'),
      ),
      contains('غير متاحة'),
    );
    expect(
      MetraErrorPresenter.assignmentMessage(
        const MetraApiException(409, 'request_failed'),
      ),
      contains('تعارض'),
    );
  });
}
