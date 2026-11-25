import 'package:flutter_test/flutter_test.dart';
import 'package:metra_mobile/features/admin/station_administration_screen.dart';

void main() {
  test('empty query matches all admin records', () {
    expect(
      stationAdminRecordMatchesQuery({'email': 'a@b.c'}, ''),
      isTrue,
    );
  });

  test('matches name, role, status, phone, and email', () {
    final record = {
      'first_name': 'أحمد',
      'last_name': 'علي',
      'role_code': 'observer',
      'status': 'active',
      'phone': '0912345678',
      'email': 'ahmad@example.com',
    };
    expect(stationAdminRecordMatchesQuery(record, 'أحمد'), isTrue);
    expect(stationAdminRecordMatchesQuery(record, 'observer'), isTrue);
    expect(stationAdminRecordMatchesQuery(record, 'ACTIVE'), isTrue);
    expect(stationAdminRecordMatchesQuery(record, '0912'), isTrue);
    expect(stationAdminRecordMatchesQuery(record, 'example.com'), isTrue);
    expect(stationAdminRecordMatchesQuery(record, 'missing'), isFalse);
  });

  test('person name falls back to email when names absent', () {
    expect(
      stationAdminPersonName({'email': 'solo@metra.local'}),
      'solo@metra.local',
    );
  });
}
