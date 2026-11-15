import 'package:flutter_test/flutter_test.dart';
import 'package:metra_mobile/features/records/record_capture_request.dart';

void main() {
  group('RecordCaptureRequest', () {
    test('serializes metadata without actor or storage fields', () {
      final request = RecordCaptureRequest(
        stationId: 'station-uuid',
        instrumentId: 'instrument-uuid',
        recorderKind: MetraRecorderKind.barograph,
        captureStart: DateTime.parse('2026-01-01T03:00:00+03:00'),
        captureEnd: DateTime.parse('2026-01-02T03:00:00+03:00'),
        paperTimeZoneId: 'Asia/Damascus',
        chartType: 'weekly',
        chartScale: const {'majorInterval': 10},
      );

      final json = request.toJson();
      expect(json['recorderKind'], 'barograph');
      expect(json['captureStart'], '2026-01-01T00:00:00.000Z');
      expect(json['captureEnd'], '2026-01-02T00:00:00.000Z');
      expect(json['paperTimeZoneId'], 'Asia/Damascus');
      expect(json['chartScale'], {'majorInterval': 10});
      expect(json.containsKey('actorUserId'), isFalse);
      expect(json.containsKey('authorityId'), isFalse);
      expect(json.containsKey('storageObjectKey'), isFalse);
      expect(json.containsKey('uploadUrl'), isFalse);
    });

    test('exposes invalid capture interval', () {
      final request = RecordCaptureRequest(
        stationId: 'station-uuid',
        instrumentId: 'instrument-uuid',
        recorderKind: MetraRecorderKind.thermograph,
        captureStart: DateTime.parse('2026-01-02T00:00:00Z'),
        captureEnd: DateTime.parse('2026-01-01T00:00:00Z'),
        paperTimeZoneId: 'UTC',
        chartType: 'daily',
      );
      expect(request.hasValidInterval, isFalse);
    });

    test('supports the four approved recorder kinds', () {
      expect(MetraRecorderKind.values.map((kind) => kind.name).toList(),
          ['thermograph', 'hygrograph', 'barograph', 'pluviograph']);
    });
  });
}
