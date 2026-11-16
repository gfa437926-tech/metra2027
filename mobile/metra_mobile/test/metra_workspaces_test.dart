import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra_mobile/features/workspaces/metra_workspaces.dart';

void main() {
  testWidgets('CLIMATOL workspace exposes analysis filters without claiming execution', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ClimatolWorkspaceScreen(stationId: 'station-1'),
    ));
    expect(find.text('CLIMATOL والتجانس المناخي'), findsOneWidget);
    expect(find.text('رمز العنصر المناخي'), findsOneWidget);
    expect(find.text('محرك التحليل غير متصل'), findsOneWidget);
    final runButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'تشغيل تحليل التجانس'),
    );
    expect(runButton.onPressed, isNull);
  });

  testWidgets('records AI workspace exposes archive, model and comparison tabs', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: RecordsAiWorkspaceScreen(stationId: 'station-1'),
    ));
    expect(find.text('الأرشيف المصور'), findsOneWidget);
    expect(find.text('مختبر الذكاء الاصطناعي'), findsOneWidget);
    expect(find.text('مقارنة النتائج'), findsOneWidget);
    expect(find.text('خدمة الأرشفة غير متصلة'), findsOneWidget);
  });

  testWidgets('operations workspace exposes devices networks and IT tabs', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: OperationsWorkspaceScreen(stationId: 'station-1'),
    ));
    expect(find.text('الأجهزة والصيانة'), findsOneWidget);
    expect(find.text('الشبكات والاتصالات'), findsOneWidget);
    expect(find.text('تقنية المعلومات'), findsOneWidget);
    expect(find.text('الوحدة غير متصلة بالخادم'), findsOneWidget);
  });

  testWidgets('reports workspace keeps generation disabled without a report API', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ReportsWorkspaceScreen(stationId: 'station-1'),
    ));
    expect(find.text('التقارير والإحصائيات'), findsOneWidget);
    final generate = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'إنشاء التقرير'),
    );
    expect(generate.onPressed, isNull);
  });
}
