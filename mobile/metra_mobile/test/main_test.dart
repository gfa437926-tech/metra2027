import 'package:flutter_test/flutter.dart';
import 'package:metra_mobile/main.dart';

void main() {
  testWidgets('home exposes Arabic navigation and session refresh', (tester) async {
    await tester.pumpWidget(const MetraMobileApp());
    await tester.pumpAndSettle();

    expect(find.text('نظام إدارة البيانات الجوية'), findsOneWidget);
    expect(find.text('الرئيسية'), findsOneWidget);
    expect(find.text('السجلات'), findsOneWidget);
    expect(find.text('المحطة'), findsOneWidget);
    expect(find.text('حسابي'), findsOneWidget);
    expect(find.byTooltip('تحديث حالة الجلسة'), findsOneWidget);
  });

  testWidgets('hourly record screen is reachable from dashboard', (tester) async {
    await tester.pumpWidget(const MetraMobileApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('السجلات الساعية'));
    await tester.pumpAndSettle();

    expect(find.text('السجلات الساعية'), findsWidgets);
  });

  testWidgets('account tab shows session details instead of placeholder',
      (tester) async {
    await tester.pumpWidget(const MetraMobileApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('حسابي'));
    await tester.pumpAndSettle();

    expect(find.text('حالة الجلسة'), findsOneWidget);
    expect(find.text('نسخة معاينة — المصادقة غير مهيأة'), findsWidgets);
    expect(
      find.text(
        'المصادقة غير مهيأة في نسخة المعاينة. لا يمكن عرض بيانات حساب حقيقية.',
      ),
      findsOneWidget,
    );
  });
}
