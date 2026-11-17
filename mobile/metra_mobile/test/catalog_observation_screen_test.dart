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

    final submit = find.byKey(const Key('metra-observation-submit'));
    expect(submit, findsOneWidget);

    // Rainfall required fields: observationDate (date) + responsibilityAgreement
    // (boolean). Fill every TextFormField so required validation cannot block the
    // local-only submit path, then acknowledge responsibility.
    final textFields = find.byType(TextFormField);
    final fieldCount = tester.widgetList(textFields).length;
    expect(fieldCount, greaterThanOrEqualTo(1));

    for (var i = 0; i < fieldCount; i++) {
      final field = textFields.at(i);
      await tester.ensureVisible(field);
      await tester.pump();
      // observationDate is the last text-like control in the rainfall catalogue.
      final value = i == fieldCount - 1 ? '2026-11-17' : '1';
      await tester.enterText(field, value);
      await tester.pump();
    }

    final acknowledgement = find.byType(SwitchListTile);
    expect(acknowledgement, findsOneWidget);
    await tester.ensureVisible(acknowledgement);
    await tester.pump();
    await tester.tap(acknowledgement);
    await tester.pump();

    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();
    // Allow SnackBar to present after the synchronous local callback.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.textContaining('غير متاح لعدم وجود عقد API'),
      findsOneWidget,
    );
  });
}
