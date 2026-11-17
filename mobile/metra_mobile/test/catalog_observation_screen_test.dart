import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:metra_mobile/core/catalog/observation_field_catalogs.dart';
import 'package:metra_mobile/features/observations/catalog_observation_screen.dart';

void main() {
  testWidgets('agricultural catalogue shows local-only banner and field count',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CatalogObservationScreen(
            title: 'الرصد الزراعي',
            fields: ObservationFieldCatalogs.agricultural,
            formCode: 'agricultural',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('تحقق محلي فقط'), findsOneWidget);
    expect(find.textContaining('agricultural'), findsOneWidget);
    expect(
      find.textContaining('${ObservationFieldCatalogs.agricultural.length}'),
      findsWidgets,
    );
    expect(find.text('تحقق محلياً'), findsOneWidget);
  });

  testWidgets('local validate does not claim server persistence', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CatalogObservationScreen(
            title: 'رصد الأمطار',
            fields: ObservationFieldCatalogs.rainfall,
            formCode: 'rainfall',
          ),
        ),
      ),
    );
    await tester.pump();

    // Banner and submit label already declare local-only behaviour.
    expect(find.textContaining('تحقق محلي فقط'), findsOneWidget);
    expect(find.textContaining('لا حفظ على الخادم'), findsOneWidget);
    expect(find.text('تحقق محلياً'), findsOneWidget);

    final submit = find.byKey(const Key('metra-observation-submit'));
    expect(submit, findsOneWidget);

    // Empty submit must stay on the client: required-field validation fires and
    // no snackbar claims a server write.
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('هذا الحقل مطلوب'), findsWidgets);
    expect(find.textContaining('أُرسل'), findsNothing);
    expect(find.textContaining('تم الحفظ على الخادم'), findsNothing);
    expect(find.textContaining('غير متاح لعدم وجود عقد API'), findsNothing);
  });
}
