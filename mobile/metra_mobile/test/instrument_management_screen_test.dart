import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra_mobile/features/instruments/instrument_management_screen.dart';

void main() {
  testWidgets('instrument form validates and creates a local-only draft', (tester) async {
    tester.view.physicalSize = const Size(1000, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: InstrumentManagementScreen()),
    ));

    await tester.ensureVisible(find.byKey(const Key('save-instrument-draft')));
    await tester.tap(find.byKey(const Key('save-instrument-draft')));
    await tester.pumpAndSettle();
    expect(find.text('معرف الجهاز مطلوب'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('instrument-id')));
    await tester.enterText(find.byKey(const Key('instrument-id')), '33333333-3333-4333-8333-333333333333');
    await tester.tap(find.byKey(const Key('instrument-kind')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thermograph').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('instrument-serial')));
    await tester.enterText(find.byKey(const Key('instrument-serial')), 'TH-0001');
    await tester.ensureVisible(find.byKey(const Key('save-instrument-draft')));
    await tester.tap(find.byKey(const Key('save-instrument-draft')));
    await tester.pumpAndSettle();

    expect(find.textContaining('أُعدّت مسودة جهاز Thermograph محلياً'), findsOneWidget);
    expect(find.textContaining('لم تُحفظ في الخادم'), findsOneWidget);
  });

  testWidgets('instrument workspace exposes deployments calibration and maintenance', (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: InstrumentManagementScreen()),
    ));
    await tester.ensureVisible(find.text('التوزيع بالمحطات'));
    await tester.tap(find.text('التوزيع بالمحطات'));
    await tester.pumpAndSettle();
    expect(find.text('ربط الجهاز بمحطة'), findsOneWidget);
    await tester.ensureVisible(find.text('المعايرة'));
    await tester.tap(find.text('المعايرة'));
    await tester.pumpAndSettle();
    expect(find.text('سجل المعايرة'), findsOneWidget);
    await tester.ensureVisible(find.text('الصيانة'));
    await tester.tap(find.text('الصيانة'));
    await tester.pumpAndSettle();
    expect(find.text('طلبات الصيانة'), findsOneWidget);
  });
}
