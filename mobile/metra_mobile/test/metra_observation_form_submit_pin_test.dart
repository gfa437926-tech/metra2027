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
        maxLength: 32,
      ),
    );
  }

  Future<void> pumpForm(
    WidgetTester tester, {
    required Size size,
    required List<MetraObservationField> fields,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: MetraObservationForm(
          title: 'نموذج اختبار',
          fields: fields,
          submitLabel: 'حفظ وإرسال',
          onSubmit: (_) async {},
        ),
      ),
    );
    // Finite pumps only — avoid hang if a ticker remains active.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('submit is built and visible on a small phone viewport', (
    tester,
  ) async {
    await pumpForm(
      tester,
      size: const Size(320, 568),
      fields: longCatalogue(24),
    );

    final submit = find.byKey(const Key('metra-observation-submit'));
    expect(submit, findsOneWidget);
    expect(find.text('حفظ وإرسال'), findsOneWidget);

    await tester.tap(submit);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('هذا الحقل مطلوب'), findsWidgets);
  });

  testWidgets('submit stays visible on a large desktop viewport', (
    tester,
  ) async {
    await pumpForm(
      tester,
      size: const Size(1280, 800),
      fields: longCatalogue(24),
    );

    expect(find.byKey(const Key('metra-observation-submit')), findsOneWidget);
    expect(find.text('حفظ وإرسال'), findsOneWidget);
  });

  testWidgets('long catalogue remains scrollable and does not hide submit', (
    tester,
  ) async {
    await pumpForm(
      tester,
      size: const Size(390, 700),
      fields: longCatalogue(30),
    );

    final submit = find.byKey(const Key('metra-observation-submit'));
    expect(submit, findsOneWidget);

    // Form body is SingleChildScrollView (not ListView) so all required fields
    // stay mounted for validation while remaining scrollable.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(submit, findsOneWidget);
    expect(find.text('حفظ وإرسال'), findsOneWidget);

    final submitRect = tester.getRect(submit);
    expect(submitRect.height, greaterThan(0));
    expect(submitRect.bottom, lessThanOrEqualTo(700.0 + 0.5));
  });

  testWidgets('submit stays below scrolled catalogue content', (tester) async {
    await pumpForm(
      tester,
      size: const Size(390, 700),
      fields: longCatalogue(20),
    );

    final submit = find.byKey(const Key('metra-observation-submit'));
    expect(submit, findsOneWidget);

    // Scroll body without requiring a specific off-stage label to appear.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final submitRect = tester.getRect(submit);
    expect(submitRect.top, greaterThan(400));
    expect(find.text('حفظ وإرسال'), findsOneWidget);
  });

  testWidgets('empty form does not invoke onSubmit callback', (tester) async {
    var calls = 0;
    await tester.binding.setSurfaceSize(const Size(390, 700));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.byKey(const Key('metra-observation-submit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(calls, 0);
    expect(find.text('هذا الحقل مطلوب'), findsWidgets);
  });
}
