import 'package:flutter/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra_mobile/core/catalog/observation_field_catalogs.dart';
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

  testWidgets('rejects decimal input in integer fields', (tester) async {
    var submitted = false;
    await tester.pumpWidget(MaterialApp(
      home: MetraObservationForm(
        title: 'اختبار الرصد',
        fields: fields,
        onSubmit: (_) async => submitted = true,
      ),
    ));
    await tester.enterText(find.byType(TextFormField).first, '18.5');
    await tester.tap(find.text('حفظ وإرسال'));
    await tester.pumpAndSettle();
    expect(find.text('أدخل قيمة رقمية صحيحة'), findsOneWidget);
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

  test('hourly and daily catalog field counts match approved reference', () {
    expect(ObservationFieldCatalogs.hourly, hasLength(36));
    expect(ObservationFieldCatalogs.daily, hasLength(32));
    expect(
      ObservationFieldCatalogs.hourly.map((field) => field.catalogId).toSet(),
      hasLength(36),
    );
    expect(
      ObservationFieldCatalogs.daily.map((field) => field.catalogId).toSet(),
      hasLength(32),
    );
  });

  test('daily temperature and humidity limits match proven bounds', () {
    final minTemp = ObservationFieldCatalogs.daily.firstWhere((f) => f.id == 'minTemp');
    final maxTemp = ObservationFieldCatalogs.daily.firstWhere((f) => f.id == 'maxTemp');
    final maxHumidity = ObservationFieldCatalogs.daily.firstWhere((f) => f.id == 'maxHumidity');
    expect([minTemp.minimum, minTemp.maximum], [-20, 50]);
    expect([maxTemp.minimum, maxTemp.maximum], [-20, 50]);
    expect([maxHumidity.minimum, maxHumidity.maximum], [0, 100]);
  });
}
