import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:metra_mobile/features/settings/system_settings_screen.dart';

void main() {
  testWidgets('system settings shows account, version, and connection sections',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SystemSettingsScreen(
          userEmail: 'operator@metra.example',
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('إعدادات النظام والحساب'), findsOneWidget);
    expect(find.text('operator@metra.example'), findsOneWidget);
    expect(find.textContaining('إصدار التطبيق'), findsOneWidget);
    expect(find.text(SystemSettingsScreen.appVersionLabel), findsOneWidget);
    expect(find.textContaining('اتصال واجهة البرمجة'), findsOneWidget);
    expect(find.textContaining('مصادقة Supabase'), findsOneWidget);
    expect(find.textContaining('حماية الجلسة'), findsOneWidget);

    // ListView builds children lazily; scroll to the sign-out action first.
    await tester.drag(find.byType(ListView), const Offset(0, -1000));
    await tester.pumpAndSettle();
    expect(find.text('تسجيل الخروج'), findsOneWidget);
  });

  testWidgets('system settings handles missing email safely', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SystemSettingsScreen(
          userEmail: null,
          onSignOut: null,
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('بيانات الحساب غير متاحة'), findsOneWidget);
    // Sign-out is below the fold in the lazy ListView.
    await tester.drag(find.byType(ListView), const Offset(0, -1000));
    await tester.pumpAndSettle();
    final logout = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'تسجيل الخروج'),
    );
    expect(logout.onPressed, isNull);
  });

  testWidgets('sign out asks for confirmation before calling callback',
      (tester) async {
    var signedOut = false;
    await tester.pumpWidget(
      MaterialApp(
        home: SystemSettingsScreen(
          userEmail: 'operator@metra.example',
          onSignOut: () async {
            signedOut = true;
          },
        ),
      ),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -1000));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تسجيل الخروج'));
    await tester.pumpAndSettle();
    expect(find.text('تأكيد تسجيل الخروج'), findsOneWidget);
    expect(signedOut, isFalse);
    await tester.tap(find.widgetWithText(FilledButton, 'تسجيل الخروج').last);
    await tester.pumpAndSettle();
    expect(signedOut, isTrue);
  });
}
