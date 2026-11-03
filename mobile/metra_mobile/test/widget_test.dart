import 'package:flutter_test/flutter_test.dart';
import 'package:metra_mobile/main.dart';

void main() {
  testWidgets('METRA mobile shell shows honest connection states', (tester) async {
    await tester.pumpWidget(const MetraApp());

    expect(find.text('METRA 2027'), findsOneWidget);
    expect(find.text('الطقس المباشر غير متصل'), findsOneWidget);
    expect(find.text('ذكاء الأرصاد يبدأ من بيانات موثوقة'), findsOneWidget);
    expect(find.text('29°'), findsNothing);
  });

  testWidgets('bottom navigation opens station directory state', (tester) async {
    await tester.pumpWidget(const MetraApp());

    await tester.tap(find.text('المحطات'));
    await tester.pumpAndSettle();

    expect(find.text('دليل المحطات'), findsOneWidget);
    expect(find.textContaining('لم تتم إضافة محطات أو إحداثيات افتراضية'), findsOneWidget);
  });

  testWidgets('review tab explains required authentication boundary', (tester) async {
    await tester.pumpWidget(const MetraApp());

    await tester.tap(find.text('الرصد'));
    await tester.pumpAndSettle();

    expect(find.text('مراجعة الرصدات'), findsOneWidget);
    expect(find.textContaining('جلسة Supabase'), findsOneWidget);
  });
}
