import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:metra_mobile/core/widgets/metra_observation_form.dart';

void main() {
  List<MetraObservationField> longCatalogue(int count) {
    return List<MetraObservationField>.generate(
      count,
      (index) => MetraObservationField(
        id: 'field_$index',
        label: 'حقل رقم $index',
        kind: MetraFieldKind.text,
        required: index == 0,
      ),
    );
  }

  Future<void> pumpForm(
    WidgetTester tester, {
    required Size size,
    required List<MetraObservationField> fields,
    Future<void> Function(Map<String, Object?> values)? onSubmit,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var submitted = false;
    await tester.pumpWidget(
      MaterialApp(
        home: MetraObservationForm(
          title: 'نموذج اختبار',
          fields: fields,
          submitLabel: 'حفظ وإرسال',
          onSubmit: (values) async {
            submitted = true;
            if (onSubmit != null) await onSubmit(values);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(submitted, isFalse);
  }

  testWidgets('submit is built and visible on a small phone viewport', (tester) async {
    await pumpForm(
      tester,
      size: const Size(320, 568),
      fields: longCatalogue(40),
    );

    final submit = find.byKey(const Key('metra-observation-submit'));
    expect(submit, findsOneWidget);
    expect(find.text('حفظ وإرسال'), findsOneWidget);

    // Pinned button must be hit-testable without scrolling the catalogue.
    await tester.tap(submit);
    await tester.pump();
    // Empty required field blocks submit; button still received the tap path.
    expect(find.text('هذا الحقل مطلوب'), findsWidgets);
  });

  testWidgets('submit stays visible on a large desktop viewport', (tester) async {
    await pumpForm(
      tester,
      size: const Size(1280, 800),
      fields: longCatalogue(40),
    );

    expect(find.byKey(const Key('metra-observation-submit')), findsOneWidget);
    expect(find.text('حفظ وإرسال'), findsOneWidget);
  });

  testWidgets('long catalogue remains scrollable and does not hide submit', (tester) async {
    await pumpForm(
      tester,
      size: const Size(390, 700),
      fields: longCatalogue(50),
    );

    final submit = find.byKey(const Key('metra-observation-submit'));
    expect(submit, findsOneWidget);

    // Scroll the field list; pinned submit must still be present.
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(submit, findsOneWidget);
    expect(find.text('حفظ وإرسال'), findsOneWidget);

    // First field label may be off-stage after scroll, but submit stays.
    final submitRect = tester.getRect(submit);
    expect(submitRect.bottom, lessThanOrEqualTo(700));
    expect(submitRect.height, greaterThan(0));
  });

  testWidgets('empty form does not invoke onSubmit callback', (tester) async {
    var calls = 0;
    await tester.binding.setSurfaceSize(const Size(390, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: MetraObservationForm(
          title: 'نموذج اختبار',
          fields: longCatalogue(5),
          submitLabel: 'حفظ وإرسال',
          onSubmit: (_) async {
            calls++;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('metra-observation-submit')));
    await tester.pumpAndSettle();

    expect(calls, 0);
    expect(find.text('هذا الحقل مطلوب'), findsWidgets);
  });
}
