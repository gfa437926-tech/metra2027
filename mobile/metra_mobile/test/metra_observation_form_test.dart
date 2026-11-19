import 'dart:async';

import 'package:material_ui/material_ui.dart';
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

  testWidgets('rejects non-finite decimal values such as NaN', (tester) async {
    var submitted = false;
    await tester.pumpWidget(MaterialApp(
      home: MetraObservationForm(
        title: 'اختبار الرصد',
        fields: fields,
        onSubmit: (_) async => submitted = true,
      ),
    ));
    await tester.enterText(find.byType(TextFormField).at(0), '18');
    await tester.enterText(find.byType(TextFormField).at(1), 'NaN');
    await tester.tap(find.text('حفظ وإرسال'));
    await tester.pumpAndSettle();
    expect(find.text('أدخل رقماً منتهياً وصالحاً'), findsOneWidget);
    expect(submitted, isFalse);
  });

  testWidgets('rejects infinite decimal values', (tester) async {
    var submitted = false;
    await tester.pumpWidget(MaterialApp(
      home: MetraObservationForm(
        title: 'اختبار الرصد',
        fields: fields,
        onSubmit: (_) async => submitted = true,
      ),
    ));
    await tester.enterText(find.byType(TextFormField).at(0), '18');
    await tester.enterText(find.byType(TextFormField).at(1), 'Infinity');
    await tester.tap(find.text('حفظ وإرسال'));
    await tester.pumpAndSettle();
    expect(find.text('أدخل رقماً منتهياً وصالحاً'), findsOneWidget);
    expect(submitted, isFalse);
  });

  testWidgets('ignores stale initial values not in approved choices', (tester) async {
    const choiceFields = [
      MetraObservationField(
        id: 'visibility',
        label: 'مدى الرؤية',
        kind: MetraFieldKind.choice,
        required: true,
        choices: ['clear', 'reduced'],
      ),
    ];
    await tester.pumpWidget(MaterialApp(
      home: MetraObservationForm(
        title: 'اختبار الرصد',
        fields: choiceFields,
        initialValues: const {'visibility': 'obsolete-value'},
        onSubmit: (_) async {},
      ),
    ));
    expect(tester.takeException(), isNull);
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
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

  testWidgets('rejects invalid calendar date before network submit', (tester) async {
    var submitted = false;
    const dateFields = [
      MetraObservationField(
        id: 'phenomenonDate',
        label: 'تاريخ الظاهرة',
        kind: MetraFieldKind.date,
        required: true,
      ),
    ];
    await tester.pumpWidget(MaterialApp(
      home: MetraObservationForm(
        title: 'اختبار التاريخ',
        fields: dateFields,
        onSubmit: (_) async => submitted = true,
      ),
    ));
    await tester.enterText(find.byType(TextFormField), '17/11/2026');
    await tester.tap(find.text('حفظ وإرسال'));
    await tester.pumpAndSettle();
    expect(find.text('التاريخ يجب أن يكون بالتنسيق yyyy-MM-dd'), findsOneWidget);
    expect(submitted, isFalse);
  });

  testWidgets('accepts yyyy-MM-dd and HH:mm for phenomenon-style fields',
      (tester) async {
    Map<String, Object?>? submitted;
    const scheduleFields = [
      MetraObservationField(
        id: 'phenomenonDate',
        label: 'تاريخ الظاهرة',
        kind: MetraFieldKind.date,
        required: true,
      ),
      MetraObservationField(
        id: 'startTime',
        label: 'وقت البدء',
        kind: MetraFieldKind.time,
        required: true,
        unit: 'HH:mm:ss',
      ),
    ];
    await tester.pumpWidget(MaterialApp(
      home: MetraObservationForm(
        title: 'اختبار الموعد',
        fields: scheduleFields,
        onSubmit: (values) async => submitted = values,
      ),
    ));
    await tester.enterText(find.byType(TextFormField).at(0), '2026-11-17');
    await tester.enterText(find.byType(TextFormField).at(1), '09:30');
    await tester.tap(find.text('حفظ وإرسال'));
    await tester.pumpAndSettle();
    expect(submitted, isNotNull);
    expect(submitted!['phenomenonDate'], '2026-11-17');
    expect(submitted!['startTime'], '09:30');
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

  testWidgets('concurrent submit disables button and invokes onSubmit once', (tester) async {
    final gate = Completer<void>();
    var submitCount = 0;
    const fields = [
      MetraObservationField(
        id: 'note',
        label: 'ملاحظة',
        kind: MetraFieldKind.text,
        required: true,
      ),
    ];
    await tester.pumpWidget(MaterialApp(
      home: MetraObservationForm(
        title: 'اختبار التزامن',
        fields: fields,
        submitLabel: 'إرسال الاختبار',
        onSubmit: (_) async {
          submitCount++;
          await gate.future;
        },
      ),
    ));
    await tester.enterText(find.byType(TextFormField), 'قيمة');
    await tester.tap(find.text('إرسال الاختبار'));
    await tester.pump();
    expect(find.text('جارٍ الإرسال...'), findsOneWidget);
    await tester.tap(find.text('جارٍ الإرسال...'), warnIfMissed: false);
    await tester.pump();
    expect(submitCount, 1);
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('إرسال الاختبار'), findsOneWidget);
    expect(submitCount, 1);
  });
}
