import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra_mobile/features/stations/assigned_stations_screen.dart';
import 'package:metra_mobile/models/current_user_context.dart';
import 'package:metra_mobile/services/current_user_context_client.dart';

void main() {
  testWidgets('shows only the station assignments from the user context',
      (tester) async {
    final context = CurrentUserContext(
      userId: 'user-1',
      profile: const CurrentUserProfile(
        firstName: 'راصد',
        fatherName: null,
        lastName: 'تجريبي',
        email: null,
        phone: null,
      ),
      accountState: 'active',
      assignments: [
        CurrentUserStationAssignment(
          stationId: 'station-01',
          stationName: 'محطة اختبار',
          roleCode: 'station_manager',
          validFrom: DateTime(2026, 1, 1),
          validTo: null,
          isActive: true,
        ),
      ],
      permissions: const [],
    );

    await tester.pumpWidget(MaterialApp(
      home: AssignedStationsScreen(
        sessionState: CurrentUserSessionState.active,
        userContext: context,
      ),
    ));

    expect(find.text('محطة اختبار'), findsOneWidget);
    expect(find.text('station-01'), findsOneWidget);
    expect(find.text('رئيس محطة'), findsOneWidget);
    expect(find.text('2026-01-01'), findsOneWidget);
    expect(find.text('1'), findsWidgets);
  });

  testWidgets('does not invent station data when identity is unconfigured',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: AssignedStationsScreen(
        sessionState: CurrentUserSessionState.unconfigured,
        userContext: null,
      ),
    ));

    expect(find.text('خدمة الهوية غير مهيأة'), findsOneWidget);
    expect(find.text('لن نعرض محطات افتراضية أو بيانات غير موثقة.'),
        findsOneWidget);
  });
}
