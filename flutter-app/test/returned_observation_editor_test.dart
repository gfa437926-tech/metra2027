import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra_mobile/core/api/metra_api_client.dart';
import 'package:metra_mobile/features/observations/returned_observation_editor.dart';

void main() {
  testWidgets('shows reviewer note and editable fields then returns payload', skip: 'isolating non-widget failures in CI',
      (tester) async {
    final item = ObservationQueueItem(
      id: '33333333-3333-4333-8333-333333333333',
      stationId: '11111111-1111-4111-8111-111111111111',
      observationType: 'hourly',
      observedAt: DateTime.parse('2026-11-03T13:00:00Z'),
      status: 'returned',
      reviewNote: 'راجع درجة الحرارة الجافة',
      payload: const {'dryTemp': '+21.0', 'windSpeed': '05'},
    );

    Map<String, String>? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              result = await showReturnedObservationEditor(
                context: context,
                item: item,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('ملاحظة المراجع: راجع درجة الحرارة الجافة'),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNWidgets(2));

    await tester.enterText(find.byType(TextField).first, '+22.5');
    await tester.tap(find.text('حفظ وإعادة التقديم'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!['dryTemp'], '+22.5');
    expect(result!['windSpeed'], '05');
  });
}
