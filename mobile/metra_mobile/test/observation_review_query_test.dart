import 'package:flutter_test/flutter_test.dart';
import 'package:metra_mobile/core/api/metra_api_client.dart';
import 'package:metra_mobile/features/observations/observation_review_screen.dart';

ObservationQueueItem _item({
  String id = 'obs-1',
  String type = 'hourly',
  String status = 'pending_review',
  DateTime? observedAt,
  Map<String, dynamic> payload = const {'temp': 12},
}) =>
    ObservationQueueItem(
      id: id,
      stationId: 'station-a',
      observationType: type,
      status: status,
      observedAt: observedAt ?? DateTime.utc(2026, 11, 20, 6),
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

  test('type labels cover known observation kinds', () {
    expect(observationQueueTypeLabel('hourly'), contains('ساعية'));
    expect(observationQueueTypeLabel('daily'), contains('يومية'));
    expect(observationQueueTypeLabel('phenomenon'), contains('ظاهرة'));
    expect(observationQueueTypeLabel('other'), contains('other'));
  });

  test('build list entries groups by type with headers when unfiltered', () {
    final rows = [
      _item(id: 'h1', type: 'hourly', observedAt: DateTime.utc(2026, 11, 21)),
      _item(id: 'd1', type: 'daily', observedAt: DateTime.utc(2026, 11, 22)),
      _item(id: 'h2', type: 'hourly', observedAt: DateTime.utc(2026, 11, 20)),
    ];
    final entries = buildObservationReviewListEntries(rows);
    // Newest overall is daily (22) so daily group first, then hourly.
    expect(entries.whereType<ObservationReviewSectionHeader>().length, 2);
    expect(entries.whereType<ObservationReviewRowEntry>().length, 3);
    final firstHeader = entries.first as ObservationReviewSectionHeader;
    expect(firstHeader.observationType, 'daily');
    expect(firstHeader.count, 1);
    final hourlyHeader = entries
        .whereType<ObservationReviewSectionHeader>()
        .firstWhere((h) => h.observationType == 'hourly');
    expect(hourlyHeader.count, 2);
  });

  test('build list entries omits headers when type filter is active', () {
    final rows = [
      _item(id: 'h1', type: 'hourly'),
      _item(id: 'h2', type: 'hourly'),
    ];
    final entries =
        buildObservationReviewListEntries(rows, typeFilter: 'hourly');
    expect(entries.whereType<ObservationReviewSectionHeader>(), isEmpty);
    expect(entries.whereType<ObservationReviewRowEntry>().length, 2);
  });
}
