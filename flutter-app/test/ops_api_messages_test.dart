import 'package:flutter_test/flutter_test.dart';
import 'package:metra_mobile/features/ops/ops_api_messages.dart';

void main() {
  test('ops submit and transition map 403 and 409', () {
    expect(
      opsSubmitErrorMessage(403, resourceAr: 'بلاغ العطل'),
      contains('صلاحية'),
    );
    expect(
      opsTransitionErrorMessage(409, resourceAr: 'بلاغ الدعم'),
      contains('الانتقال'),
    );
    expect(
      opsDetailErrorMessage(404, resourceAr: 'بلاغ العطل'),
      contains('غير موجود'),
    );
  });
}
