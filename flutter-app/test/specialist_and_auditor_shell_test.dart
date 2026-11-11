import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra_mobile/features/electronic_auditor/electronic_auditor_screen.dart';
import 'package:metra_mobile/features/aftn/aftn_console_shell_screen.dart';
import 'package:metra_mobile/features/specialist/specialist_unit_shell_screen.dart';

void main() {
  testWidgets('electronic auditor scaffold states no OCR', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ElectronicAuditorScreen()));
    expect(find.textContaining('هيكلية فقط'), findsOneWidget);
    expect(find.textContaining('التدقيق الإلكتروني'), findsWidgets);
  });

  testWidgets('specialist shell forbids fake totals messaging', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SpecialistUnitShellScreen(
          title: 'الأمطار والهطول',
          unitCode: 'rainfall',
          description: 'اختبار',
          requiredBeforeBinding: ['عقد'],
        ),
      ),
    );
    expect(find.textContaining('بيانات حقيقية'), findsOneWidget);
    expect(find.text('عقد'), findsOneWidget);
  });
  testWidgets('AFTN console provides inbox outbox and a local-only composer',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: AftnConsoleShellScreen()));
    expect(find.text('وحدة AFTN'), findsOneWidget);
    await tester.tap(find.text('إنشاء رسالة'));
    await tester.pumpAndSettle();
    expect(find.text('بيانات التوجيه'), findsOneWidget);
    expect(find.text('إرسال الرسالة غير متاح حتى اعتماد القناة الخادمية'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), 'ORIGIN');
    await tester.enterText(find.byType(TextField).at(1), 'DESTINATION');
    await tester.enterText(find.byType(TextField).at(3), 'TEST MESSAGE');
    await tester.pumpAndSettle();
    await tester.tap(find.text('معاينة محلية'));
    await tester.pumpAndSettle();
    expect(find.text('معاينة محلية — غير مرسلة'), findsOneWidget);
  });

}
