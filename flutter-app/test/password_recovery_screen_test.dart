import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra_mobile/features/auth/password_recovery_screen.dart';

void main() {
  testWidgets('password recovery validates email and gives privacy-safe confirmation',
      (tester) async {
    String? submittedEmail;
    await tester.pumpWidget(MaterialApp(
      home: MetraPasswordRecoveryScreen(
        sendRecovery: (email) async {
          submittedEmail = email;
        },
      ),
    ));

    await tester.tap(find.text('إرسال تعليمات الاستعادة'));
    await tester.pump();
    expect(find.text('أدخل بريداً إلكترونياً صحيحاً'), findsOneWidget);
    expect(submittedEmail, isNull);

    await tester.enterText(find.byType(TextFormField), ' observer@example.test ');
    await tester.tap(find.text('إرسال تعليمات الاستعادة'));
    await tester.pumpAndSettle();

    expect(submittedEmail, 'observer@example.test');
    expect(
      find.textContaining('إذا كان البريد مرتبطاً بحساب قابل للاستعادة'),
      findsOneWidget,
    );
  });

  testWidgets('password recovery shows a safe error when provider fails',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MetraPasswordRecoveryScreen(
        sendRecovery: (_) async => throw Exception('provider detail'),
      ),
    ));

    await tester.enterText(
      find.byType(TextFormField),
      'observer@example.test',
    );
    await tester.tap(find.text('إرسال تعليمات الاستعادة'));
    await tester.pumpAndSettle();

    expect(find.textContaining('تعذر إرسال الطلب حالياً'), findsOneWidget);
    expect(find.textContaining('provider detail'), findsNothing);
  });
}
