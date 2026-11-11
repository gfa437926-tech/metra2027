import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra_mobile/features/account/account_state_gate.dart';

void main() {
  testWidgets('active account opens operational workspace only after server status', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MetraAccountStateGate(
        statusFuture: Future.value({'account_state': 'active'}),
        activeChild: const Text('مساحة العمل المعتمدة'),
        pendingChild: const Text('متابعة طلب الانضمام'),
        onRetry: () {},
        onSignOut: () async {},
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('مساحة العمل المعتمدة'), findsOneWidget);
    expect(find.text('متابعة طلب الانضمام'), findsNothing);
  });

  testWidgets('pending account is routed to registration status instead of operations', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MetraAccountStateGate(
        statusFuture: Future.value({
          'account_state': 'pending',
          'request_status': 'pending_station_approval',
        }),
        activeChild: const Text('المساحة التشغيلية'),
        pendingChild: const Text('طلبك قيد الاعتماد'),
        onRetry: () {},
        onSignOut: () async {},
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('طلبك قيد الاعتماد'), findsOneWidget);
    expect(find.text('المساحة التشغيلية'), findsNothing);
  });

  testWidgets('disabled account cannot open operational workspace', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MetraAccountStateGate(
        statusFuture: Future.value({
          'account_state': 'disabled',
          'state_reason': 'تعطيل إداري',
        }),
        activeChild: const Text('المساحة التشغيلية'),
        pendingChild: const Text('طلب الانضمام'),
        onRetry: () {},
        onSignOut: () async {},
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('الحساب معطل'), findsOneWidget);
    expect(find.text('المساحة التشغيلية'), findsNothing);
    expect(find.textContaining('تعطيل إداري'), findsOneWidget);
  });

  testWidgets('status service failure fails closed and offers retry', (tester) async {
    var retried = false;
    await tester.pumpWidget(MaterialApp(
      home: MetraAccountStateGate(
        statusFuture: Future.error(Exception('provider detail')),
        activeChild: const Text('المساحة التشغيلية'),
        pendingChild: const Text('طلب الانضمام'),
        onRetry: () => retried = true,
        onSignOut: () async {},
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('تعذر التحقق من حالة الحساب'), findsOneWidget);
    expect(find.text('المساحة التشغيلية'), findsNothing);
    expect(find.textContaining('provider detail'), findsNothing);
    await tester.tap(find.text('إعادة التحقق'));
    expect(retried, isTrue);
  });
}
