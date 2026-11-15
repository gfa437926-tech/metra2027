import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra_mobile/features/records/records_review_workspace_screen.dart';

void main() {
  const stationId = '11111111-1111-4111-8111-111111111111';
  const instrumentId = '22222222-2222-4222-8222-222222222222';

  Future<void> enterValidCapture(WidgetTester tester) async {
    await tester.enterText(find.byKey(const Key('capture-station-id')), stationId);
    await tester.enterText(find.byKey(const Key('capture-instrument-id')), instrumentId);
    await tester.tap(find.byKey(const Key('capture-recorder-kind')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Barograph').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('capture-start')), '2026-01-01T00:00:00Z');
    await tester.enterText(find.byKey(const Key('capture-end')), '2026-01-02T00:00:00Z');
    await tester.enterText(find.byKey(const Key('capture-timezone')), 'Asia/Damascus');
    await tester.enterText(find.byKey(const Key('capture-chart-type')), 'daily');
  }

  testWidgets('capture form validates required UUID and positive time interval', (tester) async {
    await tester.view.setPhysicalSize(const Size(1000, 1100));
    await tester.view.setDevicePixelRatio(1);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: RecordsReviewWorkspaceScreen())));

    await tester.tap(find.byKey(const Key('prepare-capture-draft')));
    await tester.pumpAndSettle();
    expect(find.text('هذا المعرف مطلوب'), findsNWidgets(2));

    await enterValidCapture(tester);
    await tester.enterText(find.byKey(const Key('capture-station-id')), 'not-a-uuid');
    await tester.enterText(find.byKey(const Key('capture-end')), '2025-12-31T00:00:00Z');
    await tester.tap(find.byKey(const Key('prepare-capture-draft')));
    await tester.pumpAndSettle();
    expect(find.text('أدخل UUID صالحاً'), findsOneWidget);
    expect(find.text('يجب أن تكون النهاية بعد البداية'), findsOneWidget);
    expect(find.textContaining('لم تُرسل إلى الخادم'), findsNothing);
  });

  testWidgets('valid capture creates an explicitly local-only typed draft', (tester) async {
    await tester.view.setPhysicalSize(const Size(1000, 1200));
    await tester.view.setDevicePixelRatio(1);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: RecordsReviewWorkspaceScreen())));

    await enterValidCapture(tester);
    await tester.tap(find.byKey(const Key('prepare-capture-draft')));
    await tester.pumpAndSettle();

    expect(find.textContaining('أُعدّت مسودة محلية فقط'), findsOneWidget);
    expect(find.textContaining(stationId), findsOneWidget);
    expect(find.textContaining('لم تُرسل إلى الخادم'), findsOneWidget);
  });
}
