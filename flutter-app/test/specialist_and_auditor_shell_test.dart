import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra_mobile/features/electronic_auditor/electronic_auditor_screen.dart';
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
}
