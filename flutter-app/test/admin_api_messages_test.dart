import 'package:flutter_test/flutter_test.dart';
import 'package:metra_mobile/features/admin/admin_api_messages.dart';

void main() {
  test('admin registration and assignment messages map 403/409', () {
    expect(adminRegistrationDecisionError(403), contains('صلاحية'));
    expect(adminAssignmentRequestError(409), contains('تعارض'));
    expect(adminArchiveError(403), contains('أرشفة'));
  });
}
