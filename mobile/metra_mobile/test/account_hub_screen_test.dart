import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:metra_mobile/features/account/account_hub_screen.dart';

void main() {
  testWidgets('shows email and rejects short password locally', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AccountHubScreen(userEmail: 'operator@metra.example'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('الحساب الشخصي'), findsOneWidget);
    expect(find.text('operator@metra.example'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'كلمة المرور الجديدة'),
      'short',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'تأكيد كلمة المرور'),
      'short',
    );
    await tester.tap(find.text('تحديث كلمة المرور'));
    await tester.pump();

    expect(
      find.textContaining('يجب ألا تقل عن 8 أحرف'),
      findsOneWidget,
    );
  });

  testWidgets('rejects mismatched password confirmation', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AccountHubScreen(userEmail: 'operator@metra.example'),
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(
      find.widgetWithText(TextField, 'كلمة المرور الجديدة'),
      'longenough1',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'تأكيد كلمة المرور'),
      'longenough2',
    );
    await tester.tap(find.text('تحديث كلمة المرور'));
    await tester.pump();

    expect(find.textContaining('غير متطابق'), findsOneWidget);
  });
}
