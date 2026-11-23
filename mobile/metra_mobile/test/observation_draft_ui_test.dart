import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:metra_mobile/core/drafts/observation_draft_store.dart';
import 'package:metra_mobile/core/drafts/observation_draft_ui.dart';

void main() {
  test('formatSavedAtLocal is stable zero-padded', () {
    final stamp = ObservationDraftUi.formatSavedAtLocal(
      DateTime.utc(2026, 3, 5, 4, 7),
    );
    // Local offset may shift clock; still zero-padded shape yyyy-MM-dd HH:mm
    expect(stamp, matches(RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$')));
  });

  testWidgets('banner is null for empty draft and renders for saved draft',
      (tester) async {
    expect(ObservationDraftUi.banner(null), isNull);
    expect(
      ObservationDraftUi.banner(
        ObservationDraft(
          stationId: 's',
          formType: 'hourly',
          values: const {},
          savedAt: DateTime.utc(2026, 1, 1),
        ),
      ),
      isNull,
    );

    final draft = ObservationDraft(
      stationId: 's',
      formType: 'hourly',
      values: const {'dryTemp': 12},
      savedAt: DateTime.utc(2026, 11, 23, 12, 0),
    );
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: ObservationDraftUi.banner(draft)!)),
    );
    expect(find.textContaining(ObservationDraftUi.bannerPrefix), findsOneWidget);
    expect(find.textContaining('حُفظت'), findsOneWidget);
  });

  testWidgets('confirmDiscard cancels by default and confirms on action',
      (tester) async {
    bool? cancelled;
    bool? confirmed;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: [
                FilledButton(
                  onPressed: () async {
                    cancelled = await ObservationDraftUi.confirmDiscard(context);
                  },
                  child: const Text('open-cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    confirmed = await ObservationDraftUi.confirmDiscard(context);
                  },
                  child: const Text('open-confirm'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open-cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إبقاء المسودة'));
    await tester.pumpAndSettle();
    expect(cancelled, isFalse);

    await tester.tap(find.text('open-confirm'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'تجاهل المسودة'));
    await tester.pumpAndSettle();
    expect(confirmed, isTrue);
  });
}
