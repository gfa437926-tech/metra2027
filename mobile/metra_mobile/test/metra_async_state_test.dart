import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:metra_mobile/core/widgets/metra_async_state.dart';

void main() {
  testWidgets('loading panel shows Arabic loading message', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MetraAsyncStatePanel.loading(message: 'جاري التحميل التجريبي…'),
        ),
      ),
    );
    expect(find.text('جاري التحميل التجريبي…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('error panel exposes retry action', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MetraAsyncStatePanel.error(
            title: 'تعذر التحميل',
            subtitle: 'تحقق من الشبكة',
            onRetry: () => retried = true,
          ),
        ),
      ),
    );
    expect(find.text('تعذر التحميل'), findsOneWidget);
    expect(find.text('تحقق من الشبكة'), findsOneWidget);
    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pump();
    expect(retried, isTrue);
  });

  testWidgets('empty panel renders title and optional action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MetraAsyncStatePanel.empty(
            title: 'لا توجد بيانات',
            subtitle: 'حاول لاحقاً',
            action: TextButton(onPressed: () {}, child: const Text('تحديث')),
          ),
        ),
      ),
    );
    expect(find.text('لا توجد بيانات'), findsOneWidget);
    expect(find.text('تحديث'), findsOneWidget);
  });
}
