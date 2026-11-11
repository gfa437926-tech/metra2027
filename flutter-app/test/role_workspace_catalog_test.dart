import 'package:flutter_test/flutter_test.dart';
import 'package:metra_mobile/features/roles/role_workspace_catalog.dart';

void main() {
  test('role catalog includes station head, forecaster, aftn, climatol', () {
    final codes = kRoleWorkspaces.map((r) => r.code).toSet();
    expect(codes.contains('station_head'), isTrue);
    expect(codes.contains('forecaster'), isTrue);
    expect(codes.contains('aftn_recipient'), isTrue);
    expect(codes.contains('climatol_officer'), isTrue);
    expect(codes.contains('system_manager'), isTrue);
    expect(codes.contains('communications_head'), isTrue);
    expect(codes.contains('networks_head'), isTrue);
    expect(codes.contains('observation_dept_head'), isTrue);
  });
}
