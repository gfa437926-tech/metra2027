import 'package:flutter_test/flutter_test.dart';
import 'package:metra_mobile/main.dart';

void main() {
  testWidgets('METRA weather dashboard renders its primary sections', (tester) async {
    await tester.pumpWidget(const MetraApp());

    expect(find.text('METRA'), findsOneWidget);
    expect(find.text('الطقس الحالي'), findsOneWidget);
    expect(find.text('توقعات الساعات القادمة'), findsOneWidget);
  });
}
