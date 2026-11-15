import 'dart:convert';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:metra_mobile/core/api/metra_api_client.dart';
import 'package:metra_mobile/core/auth/metra_auth.dart';
import 'package:metra_mobile/features/stations/station_directory_screen.dart';
import 'package:metra_mobile/features/forecast_centres/forecast_centre_screen.dart';
import 'package:metra_mobile/core/widgets/metra_adaptive_navigation.dart';
import 'package:metra_mobile/features/records/records_review_workspace_screen.dart';
import 'package:metra_mobile/features/climatol/climatol_workspace_screen.dart';
import 'package:metra_mobile/features/ai/ai_workspace_screen.dart';

void main() {
  testWidgets('configuration screen explains missing secure environment values', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MetraConfigurationScreen()));
    expect(find.textContaining('إعداد تطبيق METRA 2027'), findsOneWidget);
    expect(find.textContaining('METRA_API_BASE_URL'), findsOneWidget);
    expect(find.textContaining('METRA_SUPABASE_URL'), findsOneWidget);
    expect(find.textContaining('service_role'), findsOneWidget);
  });

  testWidgets('station directory remains fail-closed until greenfield API is ready', (tester) async {
    var requests = 0;
    final api = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'test-token',
      client: MockClient((_) async {
        requests++;
        return http.Response('[]', 200);
      }),
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StationDirectoryScreen(api: api),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('تعذر تحميل دليل المحطات'), findsOneWidget);
    expect(find.textContaining('قاعدة البيانات الجديدة'), findsOneWidget);
    expect(requests, 0);
    api.close();
  });

  testWidgets('login exposes password recovery and validates email before request', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MetraLoginScreen()));
    expect(find.text('نسيت كلمة المرور؟'), findsOneWidget);
    await tester.tap(find.text('نسيت كلمة المرور؟'));
    await tester.pump();
    expect(find.text('أدخل البريد الإلكتروني أولاً لاستلام رابط الاستعادة.'), findsOneWidget);
  });


  testWidgets('shared navigation adapts between compact and wide layouts', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const destinations = [
      NavigationDestination(icon: Icon(Icons.home_outlined), label: 'الرئيسية'),
      NavigationDestination(icon: Icon(Icons.map_outlined), label: 'المحطات'),
    ];

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 800);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MetraAdaptiveNavigation(
          selectedIndex: 0,
          destinations: destinations,
          onDestinationSelected: (_) {},
          child: const Center(child: Text('محتوى الصفحة')),
        ),
      ),
    ));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    tester.view.physicalSize = const Size(400, 800);
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });


  testWidgets('forecast centre stays visible but does not call legacy station API', (tester) async {
    var requests = 0;
    final api = MetraApiClient(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: () async => 'test-token',
      client: MockClient((_) async {
        requests++;
        return http.Response('[]', 200);
      }),
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ForecastCentreScreen(api: api)),
    ));
    await tester.pumpAndSettle();
    expect(find.text('مراكز التنبؤ الجوي'), findsOneWidget);
    expect(find.text('دليل المحطات غير مفعّل بعد'), findsOneWidget);
    expect(find.text('الرصدات اللحظية والنشرات غير متصلة'), findsOneWidget);
    expect(requests, 0);
    api.close();
  });

  testWidgets('records workspace exposes archive, image review and triple comparison', (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: RecordsReviewWorkspaceScreen()),
    ));
    expect(find.text('أرشيف السجلات وتدقيق الصور'), findsOneWidget);
    expect(find.text('تعريف سجل جديد'), findsOneWidget);
    await tester.tap(find.text('مراجعة الصور'));
    await tester.pumpAndSettle();
    expect(find.text('مسار معالجة الصورة'), findsOneWidget);
    await tester.tap(find.text('المقارنة الثلاثية'));
    await tester.pumpAndSettle();
    expect(find.textContaining('السجل الورقي'), findsOneWidget);
    expect(find.textContaining('المسجل الميكانيكي'), findsOneWidget);
    expect(find.textContaining('الرصد الإلكتروني'), findsOneWidget);
  });

  testWidgets('CLIMATOL workspace exposes series, breakpoints and reports', (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: ClimatolWorkspaceScreen()),
    ));
    expect(find.text('التجانس المناخي وCLIMATOL'), findsOneWidget);
    expect(find.text('إعداد مهمة جديدة'), findsOneWidget);
    await tester.ensureVisible(find.text('السلاسل الزمنية'));
    await tester.tap(find.text('السلاسل الزمنية'));
    await tester.pumpAndSettle();
    expect(find.text('مستكشف السلاسل الزمنية'), findsOneWidget);
    await tester.ensureVisible(find.text('الانقطاعات والمرجعيات'));
    await tester.tap(find.text('الانقطاعات والمرجعيات'));
    await tester.pumpAndSettle();
    expect(find.text('كشف نقاط الانقطاع'), findsOneWidget);
    await tester.ensureVisible(find.text('المراجعة والتقارير'));
    await tester.tap(find.text('المراجعة والتقارير'));
    await tester.pumpAndSettle();
    expect(find.text('التقارير المناخية'), findsOneWidget);
  });

  testWidgets('AI workspace exposes dataset, training, model registry and governance', (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: AiWorkspaceScreen()),
    ));
    expect(find.text('مختبر الذكاء الاصطناعي'), findsOneWidget);
    expect(find.text('مستودع مجموعات البيانات'), findsOneWidget);
    await tester.ensureVisible(find.text('التقسيم والتدريب'));
    await tester.tap(find.text('التقسيم والتدريب'));
    await tester.pumpAndSettle();
    expect(find.text('إعداد تجربة تدريب'), findsOneWidget);
    await tester.ensureVisible(find.text('التقييم والنماذج'));
    await tester.tap(find.text('التقييم والنماذج'));
    await tester.pumpAndSettle();
    expect(find.text('سجل النماذج والإصدارات'), findsOneWidget);
    await tester.ensureVisible(find.text('الاعتماد والمراقبة'));
    await tester.tap(find.text('الاعتماد والمراقبة'));
    await tester.pumpAndSettle();
    expect(find.text('بوابة اعتماد النموذج'), findsOneWidget);
  });

}
