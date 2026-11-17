import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:metra_mobile/core/catalog/observation_field_catalogs.dart';
import 'package:metra_mobile/features/observations/catalog_observation_screen.dart';

void main() {
  testWidgets('agricultural catalogue shows local-only banner and field count', (tester) async {
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

    final submit = find.byKey(const Key('metra-observation-submit'));
    expect(submit, findsOneWidget);
    await tester.tap(submit);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.textContaining('غير متاح لعدم وجود عقد API'), findsWidgets);
  });
}
