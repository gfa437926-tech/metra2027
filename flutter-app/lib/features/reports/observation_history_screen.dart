import 'package:flutter/material.dart';

import '../../core/api/metra_api_client.dart';
import '../observations/observation_detail_sheet.dart';

/// History view of the records exposed by the existing review and returned queues.
/// It deliberately does not claim to be a complete archive of approved/rejected records.
class ObservationHistoryScreen extends StatefulWidget {
  const ObservationHistoryScreen({
    super.key,
    required this.api,
    required this.stationId,
  });

  final MetraApiClient api;
  final String stationId;

  @override
  State<ObservationHistoryScreen> createState() => _ObservationHistoryScreenState();
}

class _ObservationHistoryScreenState extends State<ObservationHistoryScreen> {
  late Future<List<ObservationQueueItem>> _records;
  String _typeFilter = 'all';
  DateTimeRange? _utcRange;

  @override
  void initState() {
    super.initState();
    _records = _load();
  }

  Future<List<ObservationQueueItem>> _load() async {
    final results = await Future.wait<List<ObservationQueueItem>>(<Future<List<ObservationQueueItem>>>[
      widget.api.getReviewQueue(widget.stationId, limit: 50),
      widget.api.getReturnedObservations(widget.stationId, limit: 50),
    ]);
    final records = <ObservationQueueItem>[...results[0], ...results[1]];
    records.sort((a, b) => b.observedAt.toUtc().compareTo(a.observedAt.toUtc()));
    return records;
  }

  Future<void> _refresh() async {
    setState(() => _records = _load());
    await _records;
  }

  bool _matchesType(ObservationQueueItem item) {
    if (_typeFilter == 'all') return true;
    final type = item.observationType.toLowerCase();
    return switch (_typeFilter) {
      'hourly' => type.contains('hour'),
      'daily' => type.contains('day'),
      'phenomenon' => type.contains('phenom'),
      _ => true,
    };
  }

  bool _matchesUtcRange(ObservationQueueItem item) {
    final range = _utcRange;
    if (range == null) return true;
    final observed = item.observedAt.toUtc();
    final start = DateTime.utc(range.start.year, range.start.month, range.start.day);
    final endExclusive = DateTime.utc(range.end.year, range.end.month, range.end.day + 1);
    return !observed.isBefore(start) && observed.isBefore(endExclusive);
  }

  Future<void> _chooseUtcRange() async {
    final now = DateTime.now().toUtc();
    final DateTimeRange? selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
      initialDateRange: _utcRange == null
          ? null
          : DateTimeRange(
              start: DateTime(_utcRange!.start.year, _utcRange!.start.month, _utcRange!.start.day),
              end: DateTime(_utcRange!.end.year, _utcRange!.end.month, _utcRange!.end.day),
            ),
      helpText: 'تصفية فترة الرصد بالتاريخ UTC',
      saveText: 'تطبيق',
    );
    if (selected == null || !mounted) return;
    setState(() {
      _utcRange = DateTimeRange(
        start: DateTime.utc(selected.start.year, selected.start.month, selected.start.day),
        end: DateTime.utc(selected.end.year, selected.end.month, selected.end.day),
      );
    });
  }

  String _date(DateTime value) {
    final utc = value.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${utc.year}-${two(utc.month)}-${two(utc.day)}';
  }

  String _formatUtc(DateTime value) {
    final utc = value.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${_date(utc)} ${two(utc.hour)}:${two(utc.minute)}:${two(utc.second)} UTC';
  }

  String _typeLabel(String type) {
    final value = type.toLowerCase();
    if (value.contains('hour')) return 'نشرة ساعية';
    if (value.contains('day')) return 'نشرة يومية';
    if (value.contains('phenom')) return 'بلاغ ظاهرة جوية';
    return 'نشرة: $type';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('سجل النشرات المتاح'),
          actions: <Widget>[
            IconButton(
              tooltip: 'تحديث',
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: FutureBuilder<List<ObservationQueueItem>>(
          future: _records,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              final error = snapshot.error;
              final message = error is MetraApiException && error.statusCode == 401
                  ? 'انتهت الجلسة. سجّل الدخول مجدداً.'
                  : error is MetraApiException && error.statusCode == 403
                      ? 'لا تملك صلاحية قراءة طوابير هذه المحطة.'
                      : 'تعذر تحميل سجل النشرات من الخادم.';
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(message, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _refresh,
                        icon: const Icon(Icons.refresh),
                        label: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final all = snapshot.data ?? const <ObservationQueueItem>[];
            final filtered = all.where(_matchesType).where(_matchesUtcRange).toList();
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: <Widget>[
                  const Card(
                    child: ListTile(
                      leading: Icon(Icons.info_outline),
                      title: Text('نطاق السجل'),
                      subtitle: Text(
                        'يعرض حتى 50 عنصراً من طابور المراجعة المصرح للمحطة، وحتى 50 نشرة مُرجَعة تخص المستخدم الحالي. لا يتضمن السجل الكامل للنشرات المعتمدة أو المرفوضة أو المؤرشفة؛ لا يوجد لها endpoint تاريخي معتمد حالياً.',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      for (final entry in <(String, String)>[
                        ('all', 'الكل'),
                        ('hourly', 'ساعي'),
                        ('daily', 'يومي'),
                        ('phenomenon', 'ظواهر'),
                      ])
                        FilterChip(
                          label: Text(entry.$2),
                          selected: _typeFilter == entry.$1,
                          onSelected: (_) => setState(() => _typeFilter = entry.$1),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: <Widget>[
                      OutlinedButton.icon(
                        onPressed: _chooseUtcRange,
                        icon: const Icon(Icons.date_range),
                        label: Text(_utcRange == null
                            ? 'تحديد فترة UTC'
                            : '${_date(_utcRange!.start)} — ${_date(_utcRange!.end)} UTC'),
                      ),
                      if (_utcRange != null)
                        TextButton(
                          onPressed: () => setState(() => _utcRange = null),
                          child: const Text('مسح الفترة'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'السجلات المطابقة: ${filtered.length} من ${all.length} سجلاً محمّلاً',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (filtered.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('لا توجد سجلات مطابقة للمرشحات الحالية.')),
                    )
                  else
                    ...filtered.map((item) => Card(
                          child: ListTile(
                            leading: const Icon(Icons.description_outlined),
                            title: Text(_typeLabel(item.observationType)),
                            subtitle: Text(
                              '${_formatUtc(item.observedAt)} · ${item.status}'
                              '${item.reviewNote == null || item.reviewNote!.isEmpty ? '' : '\nملاحظة: ${item.reviewNote}'}',
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: const Icon(Icons.chevron_left),
                            onTap: () => showObservationDetailSheet(
                              context: context,
                              item: item,
                            ),
                          ),
                        )),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
