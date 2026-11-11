import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra_mobile/features/account/account_profile_screen.dart';

void main() {
  testWidgets('account profile shows identity and does not invent roles',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: MetraAccountProfileScreen(email: 'observer@example.test'),
    ));

    expect(find.text('observer@example.test'), findsOneWidget);
    expect(find.text('مصدر الهوية'), findsOneWidget);
    expect(find.text('الأدوار والصلاحيات'), findsOneWidget);
    expect(find.textContaining('تُحدد الصلاحيات من الخادم'), findsOneWidget);
    expect(find.text('تسجيل الخروج'), findsNothing);
  });


  testWidgets('account profile displays authoritative account and registration state',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MetraAccountProfileScreen(
        email: 'pending@example.test',
        loadAccountStatus: () async => {
          'account_state': 'active',
          'state_reason': null,
          'request_status': 'pending_system_approval',
          'submitted_at': '2026-11-11T10:15:00Z',
        },
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('الحساب نشط'), findsOneWidget);
    expect(find.text('طلب الانضمام: بانتظار الاعتماد النظامي النهائي'),
        findsOneWidget);
    expect(find.textContaining('2026-11-11T10:15:00.000Z UTC'), findsOneWidget);
    expect(find.textContaining('لا يعرض هذا التطبيق دوراً أو محطة مسندة'),
        findsOneWidget);
  });

  testWidgets('account profile fails closed when account status cannot be loaded',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MetraAccountProfileScreen(
        email: 'observer@example.test',
        loadAccountStatus: () async => throw Exception('private provider detail'),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('تعذر تحميل حالة الحساب'), findsOneWidget);
    expect(find.textContaining('private provider detail'), findsNothing);
  });

  testWidgets('account profile confirms before signing out', (tester) async {
    var signedOut = false;
    await tester.pumpWidget(MaterialApp(
      home: MetraAccountProfileScreen(
        email: 'observer@example.test',
        onSignOut: () async => signedOut = true,
      ),
    ));

    await tester.tap(find.text('تسجيل الخروج'));
    await tester.pumpAndSettle();
    expect(signedOut, isFalse);
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
    expect(signedOut, isFalse);

    await tester.tap(find.text('تسجيل الخروج'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تسجيل الخروج').last);
    await tester.pumpAndSettle();
    expect(signedOut, isTrue);
  });
}
