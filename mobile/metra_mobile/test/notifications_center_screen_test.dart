import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:metra_mobile/core/preferences/notification_preferences_store.dart';
import 'package:metra_mobile/features/notifications/notifications_center_screen.dart';

void main() {
  setUp(() {
    NotificationPreferencesStore.instance.reset();
  });

  testWidgets('shows offline banner and no synthetic feed rows', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: NotificationsCenterScreen())),
    );
    await tester.pump();

    expect(find.text('مركز الإشعارات'), findsOneWidget);
    expect(find.textContaining('وضع عدم الاتصال بالخدمة'), findsOneWidget);
    expect(find.text('لا توجد إشعارات'), findsOneWidget);
    // No fake notification body text.
    expect(find.textContaining('بلاغ تجريبي'), findsNothing);
  });

  testWidgets('local preference toggles update the store', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: NotificationsCenterScreen())),
    );
    await tester.pump();

    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();

    final obsSwitch = find.widgetWithText(SwitchListTile, 'تنبيهات الرصد');
    expect(obsSwitch, findsOneWidget);
    await tester.tap(obsSwitch);
    await tester.pump();

    expect(
      NotificationPreferencesStore.instance.current.observationAlerts,
      isTrue,
    );
  });

  testWidgets('filter chips change empty-state copy without inventing rows', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: NotificationsCenterScreen())),
    );
    await tester.pump();

    await tester.tap(find.text('غير مقروء'));
    await tester.pump();
    expect(find.textContaining('لا يوجد غير مقروء'), findsOneWidget);

    await tester.tap(find.text('مقروء'));
    await tester.pump();
    expect(find.textContaining('لا يوجد مقروء'), findsOneWidget);
  });
}
