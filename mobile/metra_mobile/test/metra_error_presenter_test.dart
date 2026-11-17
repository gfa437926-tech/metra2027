import 'package:flutter_test/flutter_test.dart';
import 'package:metra_mobile/core/api/metra_api_client.dart';
import 'package:metra_mobile/core/errors/metra_error_presenter.dart';

void main() {
  test('maps MetraApiException via displayMessage', () {
    const error = MetraApiException(503, 'network_unavailable');
    expect(
      MetraErrorPresenter.messageFor(error),
      contains('الاتصال'),
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

  test('does not leak exception type names for unknown errors', () {
    final message = MetraErrorPresenter.messageFor(StateError('secret-token'));
    expect(message.toLowerCase(), isNot(contains('stateerror')));
    expect(message.toLowerCase(), isNot(contains('secret-token')));
  });
}
