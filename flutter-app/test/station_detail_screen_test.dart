import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metra_mobile/core/api/metra_api_client.dart';
import 'package:metra_mobile/features/stations/station_detail_screen.dart';

void main() {
  testWidgets('station detail shows catalogue facts and labels missing data honestly',
      (tester) async {
    const station = StationDirectoryItem(
      id: 'station-1',
      localCode: 'SY-001',
      nameArabic: 'محطة اختبار',
      nameEnglish: 'Test station',
      stationType: 'classic',
      operationalStatus: 'active',
      approvalStatus: 'approved',
      isDemo: false,
      latitude: 35.5,
      longitude: 36.2,
      elevationM: 412,
      wmoStationId: null,
      coordinateSource: 'surveyed',
      coordinateAccuracyM: 3.2,
    );

    await tester.pumpWidget(const MaterialApp(
      home: StationDetailScreen(station: station),
    ));

    expect(find.text('محطة اختبار'), findsOneWidget);
    expect(find.textContaining('رمز المحطة: SY-001'), findsOneWidget);
    expect(find.text('كلاسيكية'), findsOneWidget);
    expect(find.text('فعالة'), findsOneWidget);
    expect(find.textContaining('35.50000, 36.20000'), findsOneWidget);
    expect(find.text('412.0 متر'), findsOneWidget);
    expect(find.text('surveyed'), findsOneWidget);
    expect(find.text('3.2 متر'), findsOneWidget);
    expect(find.text('غير متوفر'), findsOneWidget);
    final sourceNote = find.textContaining('لا تمثل قياسات جوية لحظية');
    await tester.scrollUntilVisible(sourceNote, 240,
        scrollable: find.byType(Scrollable).first);
    expect(sourceNote, findsOneWidget);
  });
}
