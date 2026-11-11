import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra_mobile/features/auth/password_update_screen.dart';

void main() {
  testWidgets('password update validates length and confirmation before provider call',
      (tester) async {
    String? submitted;
    await tester.pumpWidget(MaterialApp(
      home: MetraPasswordUpdateScreen(
        updatePassword: (value) async => submitted = value,
        onCancel: () async {},
      ),
    ));

    await tester.enterText(find.byType(TextFormField).at(0), 'short');
    await tester.enterText(find.byType(TextFormField).at(1), 'different');
    await tester.tap(find.text('حفظ كلمة المرور'));
    await tester.pump();
    expect(find.text('كلمة المرور يجب أن تكون 8 محارف على الأقل'), findsOneWidget);
    expect(find.text('كلمتا المرور غير متطابقتين'), findsOneWidget);
    expect(submitted, isNull);

    await tester.enterText(find.byType(TextFormField).at(0), 'StrongPass2026!');
    await tester.enterText(find.byType(TextFormField).at(1), 'StrongPass2026!');
    await tester.tap(find.text('حفظ كلمة المرور'));
    await tester.pumpAndSettle();
    expect(submitted, 'StrongPass2026!');
    expect(find.textContaining('تم تحديث كلمة المرور'), findsOneWidget);
  });

  testWidgets('password update hides provider error details', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MetraPasswordUpdateScreen(
        updatePassword: (_) async => throw Exception('provider private detail'),
        onCancel: () async {},
      ),
    ));
    await tester.enterText(find.byType(TextFormField).at(0), 'StrongPass2026!');
    await tester.enterText(find.byType(TextFormField).at(1), 'StrongPass2026!');
    await tester.tap(find.text('حفظ كلمة المرور'));
    await tester.pumpAndSettle();

    expect(find.textContaining('تعذر تحديث كلمة المرور'), findsOneWidget);
    expect(find.textContaining('provider private detail'), findsNothing);
  });
}
