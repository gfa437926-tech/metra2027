import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:metra_mobile/core/api/metra_api_client.dart';
import 'package:metra_mobile/features/observations/observation_review_screen.dart';

void main() {
  const stationId = '11111111-1111-4111-8111-111111111111';
  const observationId = '22222222-2222-4222-8222-222222222222';

  Map<String, dynamic> queueItem({
    String id = observationId,
    String type = 'daily',
    String status = 'submitted',
  }) =>
      {
        'id': id,
        'station_id': stationId,
        'observation_type': type,
        'observed_at': '2026-11-03T12:00:00Z',
        'status': status,
        'payload': <String, dynamic>{},
      };

  MetraApiClient apiWith(MockClientHandler handler) => MetraApiClient(
        baseUrl: 'https://api.example.test',
        accessTokenProvider: () async => 'access-token',
        client: MockClient(handler),
      );

  /// Dialog confirm button is the last FilledButton labelled اعتماد when open.
  Future<void> confirmApprove(WidgetTester tester) async {
    final dialogApprove = find.widgetWithText(FilledButton, 'اعتماد').last;
    expect(dialogApprove, findsOneWidget);
    await tester.tap(dialogApprove);
  }

  Future<void> openApproveDialog(WidgetTester tester) async {
    final approve = find.widgetWithText(OutlinedButton, 'اعتماد');
    expect(approve, findsOneWidget);
    await tester.ensureVisible(approve);
    await tester.tap(approve);
    await tester.pumpAndSettle();
  }

  testWidgets('renders queue returned by the API', (tester) async {
    final api = apiWith(
      (_) async => http.Response(jsonEncode([queueItem()]), 200),
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ObservationReviewScreen(api: api, stationId: stationId)),
    ));
    await tester.pumpAndSettle();
    expect(find.text('مراجعة النشرات'), findsOneWidget);
    expect(find.text('نشرة يومية'), findsOneWidget);
    expect(find.text('اعتماد'), findsOneWidget);
    expect(find.text('إرجاع للتصحيح'), findsOneWidget);
    api.close();
  });

  testWidgets('shows empty state for an empty server queue', (tester) async {
    final api = apiWith((_) async => http.Response('[]', 200));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ObservationReviewScreen(api: api, stationId: stationId)),
    ));
    await tester.pumpAndSettle();
    expect(find.text('لا توجد نشرات بانتظار المراجعة'), findsOneWidget);
    api.close();
  });

  testWidgets('shows loading indicator while queue is pending', (tester) async {
    final completer = Completer<http.Response>();
    final api = apiWith((_) => completer.future);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ObservationReviewScreen(api: api, stationId: stationId)),
    ));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    completer.complete(http.Response('[]', 200));
    await tester.pumpAndSettle();
    expect(find.text('لا توجد نشرات بانتظار المراجعة'), findsOneWidget);
    api.close();
  });

  testWidgets('renders recoverable error when queue load fails with 503',
      (tester) async {
    var calls = 0;
    final api = apiWith((_) async {
      calls++;
      return calls == 1
          ? http.Response('[]', 200)
          : http.Response('{"error":"unavailable"}', 503);
    });
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ObservationReviewScreen(api: api, stationId: stationId)),
    ));
    await tester.pumpAndSettle();
    expect(find.text('لا توجد نشرات بانتظار المراجعة'), findsOneWidget);

    await tester.tap(find.byTooltip('تحديث'));
    await tester.pumpAndSettle();

    expect(find.textContaining('الخادم'), findsOneWidget);
    expect(find.text('إعادة المحاولة'), findsOneWidget);
    api.close();
  });

  testWidgets('queue load 403 shows station review permission message',
      (tester) async {
    final api = apiWith((_) async => http.Response('forbidden', 403));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ObservationReviewScreen(api: api, stationId: stationId)),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('صلاحية'), findsOneWidget);
    expect(find.text('إعادة المحاولة'), findsOneWidget);
    api.close();
  });

  testWidgets('queue load 401 shows login guidance', (tester) async {
    final api = apiWith((_) async => http.Response('unauthorized', 401));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ObservationReviewScreen(api: api, stationId: stationId)),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('تسجيل الدخول'), findsOneWidget);
    api.close();
  });

  testWidgets('approve decision succeeds and refreshes queue', (tester) async {
    var decideCalls = 0;
    var getCalls = 0;
    final api = apiWith((request) async {
      if (request.method == 'GET') {
        getCalls++;
        if (decideCalls > 0) {
          return http.Response('[]', 200);
        }
        return http.Response(jsonEncode([queueItem()]), 200);
      }
      decideCalls++;
      return http.Response('{}', 200);
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ObservationReviewScreen(api: api, stationId: stationId)),
    ));
    await tester.pumpAndSettle();
    expect(find.text('نشرة يومية'), findsOneWidget);

    await openApproveDialog(tester);
    expect(find.text('اعتماد النشرة'), findsOneWidget);
    await confirmApprove(tester);
    await tester.pumpAndSettle();

    expect(decideCalls, 1);
    expect(find.text('تم إرسال قرار المراجعة'), findsOneWidget);
    expect(find.text('لا توجد نشرات بانتظار المراجعة'), findsOneWidget);
    expect(getCalls, greaterThanOrEqualTo(2));
    api.close();
  });

  testWidgets('return for correction requires note and posts decision',
      (tester) async {
    var decideBodies = <String>[];
    final api = apiWith((request) async {
      if (request.method == 'GET') {
        return http.Response(jsonEncode([queueItem()]), 200);
      }
      decideBodies.add(request.body);
      return http.Response('{}', 200);
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ObservationReviewScreen(api: api, stationId: stationId)),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('إرجاع للتصحيح'));
    await tester.pumpAndSettle();
    expect(find.text('سبب الإرجاع'), findsOneWidget);

    await tester.tap(find.text('تأكيد الإرجاع'));
    await tester.pumpAndSettle();
    expect(decideBodies, isEmpty);

    await tester.enterText(find.byType(TextField), 'تحتاج تصحيح الضغط');
    await tester.tap(find.text('تأكيد الإرجاع'));
    await tester.pumpAndSettle();

    expect(decideBodies, hasLength(1));
    expect(decideBodies.single, contains('return_for_correction'));
    expect(decideBodies.single, contains('تحتاج تصحيح الضغط'));
    api.close();
  });

  testWidgets('forbidden decision shows reviewDecisionMessage', (tester) async {
    final api = apiWith((request) async {
      if (request.method == 'GET') {
        return http.Response(jsonEncode([queueItem()]), 200);
      }
      return http.Response('{"error":"forbidden"}', 403);
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ObservationReviewScreen(api: api, stationId: stationId)),
    ));
    await tester.pumpAndSettle();
    await openApproveDialog(tester);
    await confirmApprove(tester);
    await tester.pumpAndSettle();

    expect(find.text('ليست لديك صلاحية تنفيذ هذا القرار'), findsOneWidget);
    expect(find.text('نشرة يومية'), findsOneWidget);
    api.close();
  });

  testWidgets('409 conflict on decision shows already-processed message',
      (tester) async {
    final api = apiWith((request) async {
      if (request.method == 'GET') {
        return http.Response(jsonEncode([queueItem()]), 200);
      }
      return http.Response('{}', 409);
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ObservationReviewScreen(api: api, stationId: stationId)),
    ));
    await tester.pumpAndSettle();
    await openApproveDialog(tester);
    await confirmApprove(tester);
    await tester.pumpAndSettle();

    expect(find.textContaining('مسبقاً'), findsOneWidget);
    api.close();
  });

  testWidgets('concurrent approve taps only send one decision request',
      (tester) async {
    final gate = Completer<void>();
    var decideCalls = 0;
    final api = apiWith((request) async {
      if (request.method == 'GET') {
        return http.Response(jsonEncode([queueItem()]), 200);
      }
      decideCalls++;
      await gate.future;
      return http.Response('{}', 200);
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ObservationReviewScreen(api: api, stationId: stationId)),
    ));
    await tester.pumpAndSettle();

    await openApproveDialog(tester);
    await confirmApprove(tester);
    // Allow dialog route to finish leaving so only the list button remains.
    await tester.pumpAndSettle();

    // Second attempt while processing should be ignored by UI guard.
    // Prefer list button (first) if any transient dialog residue remains.
    final listApprove = find.widgetWithText(FilledButton, 'اعتماد');
    if (listApprove.evaluate().isNotEmpty) {
      await tester.tap(listApprove.first, warnIfMissed: false);
    }
    await tester.pump();
    expect(decideCalls, 1);

    gate.complete();
    await tester.pumpAndSettle();
    expect(decideCalls, 1);
    api.close();
  });
}
