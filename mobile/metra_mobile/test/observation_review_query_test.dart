import 'package:flutter_test/flutter_test.dart';
import 'package:metra_mobile/core/api/metra_api_client.dart';
import 'package:metra_mobile/features/observations/observation_review_screen.dart';

ObservationQueueItem _item({
  String id = 'obs-1',
  String type = 'hourly',
  String status = 'pending_review',
  Map<String, dynamic> payload = const {'temp': 12},
}) =>
    ObservationQueueItem(
      id: id,
      stationId: 'station-a',
      observationType: type,
      status: status,
      observedAt: DateTime.utc(2026, 11, 20, 6),
      payload: payload,
    );

void main() {
  test('empty query matches every row', () {
    expect(observationQueueItemMatchesQuery(_item(), ''), isTrue);
    expect(observationQueueItemMatchesQuery(_item(), '   '), isTrue);
  });

  test('matches id, type, status, and payload values', () {
    final item = _item(
      id: 'abc-uuid',
      type: 'daily',
      status: 'returned',
      payload: {'rain': 3.2, 'note': 'ساحل'},
    );
    expect(observationQueueItemMatchesQuery(item, 'abc'), isTrue);
    expect(observationQueueItemMatchesQuery(item, 'DAILY'), isTrue);
    expect(observationQueueItemMatchesQuery(item, 'returned'), isTrue);
    expect(observationQueueItemMatchesQuery(item, '3.2'), isTrue);
    expect(observationQueueItemMatchesQuery(item, 'ساحل'), isTrue);
    expect(observationQueueItemMatchesQuery(item, 'missing-token'), isFalse);
  });
}
