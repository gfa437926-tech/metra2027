import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra_mobile/features/reports/reports_hub_screen.dart';

void main() {
  testWidgets('reports hub clearly marks unimplemented API-backed capabilities without fake data', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ReportsHubScreen(onOpenArchive: () {})),
      ),
    );

    expect(find.text('التقارير والتحليلات'), findsOneWidget);
    expect(find.text('الأرشيف التاريخي للرصدات'), findsOneWidget);
    expect(find.text('التقارير الساعية واليومية'), findsOneWidget);
    expect(find.text('التقارير الشهرية والسنوية'), findsOneWidget);
    expect(find.text('التحليل المناخي والتجانس'), findsOneWidget);
    expect(find.text('التصدير والطباعة'), findsOneWidget);
    expect(find.text('بانتظار عقد API'), findsNWidgets(4));
    expect(find.text('فتح الأرشيف'), findsOneWidget);
    expect(find.text('متاح للأرشيف التاريخي'), findsOneWidget);
    expect(find.textContaining('لن تظهر أرقام أو رسوم'), findsOneWidget);
    expect(find.textContaining('قائمة مراجعة الرصدات وسجل تدقيق المحطة وظيفتان منفصلتان'), findsOneWidget);
  });
}
