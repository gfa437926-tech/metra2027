// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra_mobile/core/widgets/metra_adaptive_navigation.dart';
import 'package:metra_mobile/features/ai/ai_workspace_screen.dart';
import 'package:metra_mobile/features/climatol/climatol_workspace_screen.dart';
import 'package:metra_mobile/features/records/records_review_workspace_screen.dart';

void main() {
  testWidgets('compact navigation scrolls through all 13 destinations', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 850);
    final destinations = List.generate(
      13,
      (index) => NavigationDestination(
        icon: const Icon(Icons.circle_outlined),
        selectedIcon: const Icon(Icons.circle),
        label: 'وحدة $index',
      ),
    );
    var selected = -1;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MetraAdaptiveNavigation(
          selectedIndex: 0,
          destinations: destinations,
          onDestinationSelected: (value) => selected = value,
          child: const Center(child: Text('محتوى METRA')),
        ),
      ),
    ));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('وحدة 12'));
    await tester.tap(find.text('وحدة 12'));
    await tester.pumpAndSettle();
    expect(selected, 12);
    expect(tester.takeException(), isNull);
  });

  testWidgets('records workspace switches between archive and source comparison', (tester) async {
    await tester.view.setPhysicalSize(const Size(1000, 900));
    await tester.view.setDevicePixelRatio(1);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: RecordsReviewWorkspaceScreen()),
    ));
    expect(find.text('تعريف سجل جديد'), findsOneWidget);
    await tester.tap(find.text('المقارنة الثلاثية'));
    await tester.pumpAndSettle();
    expect(find.textContaining('السجل الورقي'), findsOneWidget);
    expect(find.textContaining('المسجل الميكانيكي'), findsOneWidget);
    expect(find.textContaining('الرصد الإلكتروني'), findsOneWidget);
  });

  testWidgets('CLIMATOL workspace exposes breakpoint and report panels', (tester) async {
    await tester.view.setPhysicalSize(const Size(1000, 900));
    await tester.view.setDevicePixelRatio(1);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: ClimatolWorkspaceScreen()),
    ));
    await tester.tap(find.text('الانقطاعات والمرجعيات'));
    await tester.pumpAndSettle();
    expect(find.text('كشف نقاط الانقطاع'), findsOneWidget);
    await tester.tap(find.text('المراجعة والتقارير'));
    await tester.pumpAndSettle();
    expect(find.text('التقارير المناخية'), findsOneWidget);
  });

  testWidgets('AI workspace exposes dataset and model governance panels', (tester) async {
    await tester.view.setPhysicalSize(const Size(1000, 900));
    await tester.view.setDevicePixelRatio(1);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: AiWorkspaceScreen()),
    ));
    expect(find.text('مستودع مجموعات البيانات'), findsOneWidget);
    await tester.tap(find.text('الاعتماد والمراقبة'));
    await tester.pumpAndSettle();
    expect(find.text('بوابة اعتماد النموذج'), findsOneWidget);
  });
}
