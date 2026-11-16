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
    // Sign-out disabled when callback is null.
    final logout = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'تسجيل الخروج'));
    expect(logout.onPressed, isNull);
  });
}
