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
  late Future<_HistorySnapshot> _records;
  String _typeFilter = 'all';
  String _statusFilter = 'all';
  String _query = '';
  final TextEditingController _searchController = TextEditingController();
  DateTimeRange? _utcRange;

  @override
  void initState() {
    super.initState();
    _records = _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<_QueueResult> _loadQueue(
    Future<List<ObservationQueueItem>> Function() request,
  ) async {
    try {
      return _QueueResult(records: await request());
    } on MetraApiException catch (error) {
      if (error.statusCode == 403) {
        return const _QueueResult(records: <ObservationQueueItem>[], forbidden: true);
      }
      rethrow;
    }
  }

  Future<_HistorySnapshot> _load() async {
    final results = await Future.wait<_QueueResult>(<Future<_QueueResult>>[
      _loadQueue(() => widget.api.getReviewQueue(widget.stationId, limit: 100)),
      _loadQueue(() => widget.api.getReturnedObservations(widget.stationId, limit: 100)),
    ]);
    if (results.every((result) => result.forbidden)) {
      throw const MetraApiException(403, 'history_queues_forbidden');
    }
    final records = <ObservationQueueItem>[...results[0].records, ...results[1].records];
    records.sort((a, b) => b.observedAt.toUtc().compareTo(a.observedAt.toUtc()));
    return _HistorySnapshot(
      records: records,
      reviewForbidden: results[0].forbidden,
      returnedForbidden: results[1].forbidden,
    );
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
      'daily' => type.contains('day') || type.contains('daily'),
      'phenomenon' => type.contains('phenom'),
      _ => true,
    };
  }

  bool _matchesStatus(ObservationQueueItem item) {
    if (_statusFilter == 'all') return true;
    return item.status.toLowerCase() == _statusFilter;
  }

  bool _matchesQuery(ObservationQueueItem item) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return true;
    return item.id.toLowerCase().contains(query) ||
        item.observationType.toLowerCase().contains(query) ||
        item.status.toLowerCase().contains(query) ||
        (item.reviewNote?.toLowerCase().contains(query) ?? false) ||
        item.payload.toString().toLowerCase().contains(query);
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

  String _statusLabel(String status) => switch (status.toLowerCase()) {
        'submitted' => 'بانتظار المراجعة',
        'returned' => 'مُرجَعة للتصحيح',
        'approved' => 'معتمدة',
        'rejected' => 'مرفوضة',
        'draft' => 'مسودة',
        _ => status,
      };

  String _typeLabel(String type) {
    final value = type.toLowerCase();
    if (value.contains('hour')) return 'نشرة ساعية';
    if (value.contains('day') || value.contains('daily')) return 'نشرة يومية';
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
        body: FutureBuilder<_HistorySnapshot>(
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

            final history = snapshot.data!;
            final all = history.records;
            final filtered = all
                .where(_matchesType)
                .where(_matchesStatus)
                .where(_matchesUtcRange)
                .where(_matchesQuery)
                .toList();
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: <Widget>[
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: Text('نطاق السجل'),
                      subtitle: Text(<String>[
                        'يعرض حتى 100 عنصر من طابور المراجعة المصرح للمحطة، وحتى 100 نشرة مُرجَعة تخص المستخدم الحالي. لا يتضمن السجل الكامل للنشرات المعتمدة أو المرفوضة أو المؤرشفة؛ لا يوجد لها endpoint تاريخي معتمد حالياً.',
                        if (history.reviewForbidden)
                          'تعذر تحميل طابور المراجعة بسبب نطاق الصلاحية الحالي.',
                        if (history.returnedForbidden)
                          'تعذر تحميل طابور المُرجَعات بسبب نطاق الصلاحية الحالي.',
                      ].join(' • ')),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'بحث في السجل',
                      hintText: 'نوع النشرة أو الحالة أو الملاحظة أو المعرّف',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => setState(() => _query = value),
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
                    runSpacing: 8,
                    children: <Widget>[
                      for (final entry in <(String, String)>[
                        ('all', 'كل الحالات'),
                        ('submitted', 'بانتظار المراجعة'),
                        ('returned', 'مُرجَعة'),
                      ])
                        FilterChip(
                          label: Text(entry.$2),
                          selected: _statusFilter == entry.$1,
                          onSelected: (_) => setState(() => _statusFilter = entry.$1),
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
                      if (_query.isNotEmpty || _typeFilter != 'all' ||
                          _statusFilter != 'all' || _utcRange != null)
                        TextButton.icon(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                            _query = '';
                            _typeFilter = 'all';
                            _statusFilter = 'all';
                            _utcRange = null;
                            });
                          },
                          icon: const Icon(Icons.filter_alt_off),
                          label: const Text('مسح كل المرشحات'),
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
                              '${_formatUtc(item.observedAt)} · ${_statusLabel(item.status)}'
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

class _QueueResult {
  const _QueueResult({
    required this.records,
    this.forbidden = false,
  });

  final List<ObservationQueueItem> records;
  final bool forbidden;
}

class _HistorySnapshot {
  const _HistorySnapshot({
    required this.records,
    required this.reviewForbidden,
    required this.returnedForbidden,
  });

  final List<ObservationQueueItem> records;
  final bool reviewForbidden;
  final bool returnedForbidden;
}
