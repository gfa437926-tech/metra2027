import 'package:flutter_test/flutter_test.dart';
import 'package:metra_mobile/features/account/registration_request_screen.dart';

void main() {
  test('registrationStatusLabel maps known codes', () {
    expect(registrationStatusLabel('pending'), contains('بانتظار'));
    expect(registrationStatusLabel('pending_station_approval'), contains('بانتظار'));
    expect(registrationStatusLabel('approved'), 'معتمد');
    expect(registrationStatusLabel('active'), 'معتمد');
    expect(registrationStatusLabel('rejected'), 'مرفوض');
    expect(registrationStatusLabel('denied'), 'مرفوض');
    expect(registrationStatusLabel(null), 'غير محدد');
    expect(registrationStatusLabel(''), 'غير محدد');
    expect(registrationStatusLabel('custom_code'), 'custom_code');
  });
}
