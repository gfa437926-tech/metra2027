import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra_mobile/core/widgets/metra_observation_form.dart';

void main() {
  const fields = [
    MetraObservationField(
      id: 'air_temperature',
      label: 'درجة حرارة الهواء',
      kind: MetraFieldKind.integer,
      required: true,
      minimum: -20,
      maximum: 50,
      unit: '°C',
    ),
    MetraObservationField(
      id: 'wind_speed',
      label: 'سرعة الرياح',
      kind: MetraFieldKind.decimal,
      minimum: 0,
      maximum: 100,
      unit: 'م/ث',
    ),
  ];

  testWidgets('rejects values outside approved numeric bounds', (tester) async {
    var submitted = false;
    await tester.pumpWidget(MaterialApp(
      home: MetraObservationForm(
        title: 'اختبار الرصد',
        fields: fields,
        onSubmit: (_) async => submitted = true,
      ),
    ));

    await tester.enterText(find.byType(TextFormField).first, '51');
    await tester.tap(find.text('حفظ وإرسال'));
    await tester.pumpAndSettle();

    expect(find.text('القيمة أكبر من الحد الأعلى (50)'), findsOneWidget);
    expect(submitted, isFalse);
  });

  testWidgets('submits validated values with numeric types', (tester) async {
    Map<String, Object?>? submitted;
    await tester.pumpWidget(MaterialApp(
      home: MetraObservationForm(
        title: 'اختبار الرصد',
        fields: fields,
        onSubmit: (values) async => submitted = values,
      ),
    ));

    await tester.enterText(find.byType(TextFormField).at(0), '18');
    await tester.enterText(find.byType(TextFormField).at(1), '3.5');
    await tester.tap(find.text('حفظ وإرسال'));
    await tester.pumpAndSettle();

    expect(submitted, isNotNull);
    expect(submitted!['air_temperature'], 18);
    expect(submitted!['wind_speed'], 3.5);
  });

  testWidgets('requires mandatory fields', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MetraObservationForm(
        title: 'اختبار الرصد',
        fields: fields,
        onSubmit: (_) async {},
      ),
    ));

    await tester.tap(find.text('حفظ وإرسال'));
    await tester.pumpAndSettle();

    expect(find.text('هذا الحقل مطلوب'), findsOneWidget);
  });
}
