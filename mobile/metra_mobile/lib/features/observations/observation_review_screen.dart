import 'package:material_ui/material_ui.dart';
import '../../core/api/metra_api_client.dart';
import '../../core/errors/metra_error_presenter.dart';
import '../../core/widgets/metra_async_state.dart';

/// Local filter over an already-loaded review queue page. Does not call the API.
bool observationQueueItemMatchesQuery(ObservationQueueItem item, String rawQuery) {
  final q = rawQuery.trim().toLowerCase();
  if (q.isEmpty) return true;
  if (item.id.toLowerCase().contains(q)) return true;
  if (item.observationType.toLowerCase().contains(q)) return true;
  if (item.status.toLowerCase().contains(q)) return true;
  for (final entry in item.payload.entries) {
    if (entry.key.toLowerCase().contains(q)) return true;
    if ('${entry.value}'.toLowerCase().contains(q)) return true;
  }
  return false;
}

/// Arabic label for known observation queue types (local display only).
String observationQueueTypeLabel(String type) => switch (type) {
      'daily' => 'نشرة يومية',
      'hourly' => 'نشرة ساعية',
      'phenomenon' => 'بلاغ ظاهرة جوية',
      _ => 'نشرة: $type',
    };

String formatObservationQueueObservedAt(DateTime value) {
  final local = value.toLocal();
  final y = local.year.toString().padLeft(4, '0');
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '$y-$m-$d $hh:$mm';
}

String observationQueueStatusLabel(String status) => switch (status) {
      'submitted' => 'بانتظار المراجعة',
      'approved' => 'معتمدة',
      'returned' || 'return_for_correction' => 'مُرجَعة للتصحيح',
      'rejected' => 'مرفوضة',
      _ => status,
    };


/// Local list model: either a type section header or a queue row.
sealed class ObservationReviewListEntry {
  const ObservationReviewListEntry();
}

class ObservationReviewSectionHeader extends ObservationReviewListEntry {
  const ObservationReviewSectionHeader({
    required this.observationType,
    required this.count,
  });

  final String observationType;
  final int count;

  String get label => observationQueueTypeLabel(observationType);
}

class ObservationReviewRowEntry extends ObservationReviewListEntry {
  const ObservationReviewRowEntry(this.item);
  final ObservationQueueItem item;
}

/// Groups filtered rows by observationType while preserving newest-first order
/// within each group. When [typeFilter] is not "all", headers are omitted.
List<ObservationReviewListEntry> buildObservationReviewListEntries(
  List<ObservationQueueItem> rows, {
  String typeFilter = 'all',
}) {
  if (rows.isEmpty) return const [];
  final ordered = List<ObservationQueueItem>.of(rows)
    ..sort((a, b) => b.observedAt.compareTo(a.observedAt));

  if (typeFilter != 'all') {
    return [
      for (final item in ordered) ObservationReviewRowEntry(item),
    ];
  }

  final byType = <String, List<ObservationQueueItem>>{};
  final typeOrder = <String>[];
  for (final item in ordered) {
    final key = item.observationType;
    if (!byType.containsKey(key)) {
      byType[key] = <ObservationQueueItem>[];
      typeOrder.add(key);
    }
    byType[key]!.add(item);
  }

  final entries = <ObservationReviewListEntry>[];
  for (final type in typeOrder) {
    final group = byType[type]!;
    entries.add(
      ObservationReviewSectionHeader(
        observationType: type,
        count: group.length,
      ),
    );
    for (final item in group) {
      entries.add(ObservationReviewRowEntry(item));
    }
  }
  return entries;
}

/// Host app supplies an authenticated API client and an authorized station UUID.
/// Authorization is enforced on the server for queue load and every decision.
class ObservationReviewScreen extends StatefulWidget {
  const ObservationReviewScreen({
    super.key,
    required this.api,
    required this.stationId,
  });

  final MetraApiClient api;
  final String stationId;

  @override
  State<ObservationReviewScreen> createState() =>
      _ObservationReviewScreenState();
}

class _ObservationReviewScreenState extends State<ObservationReviewScreen> {
  late Future<List<ObservationQueueItem>> _queue;
  final Set<String> _processingIds = <String>{};
  final _query = TextEditingController();
  String _typeFilter = 'all';

  @override
  void initState() {
    super.initState();
    _queue = widget.api.getReviewQueue(widget.stationId);
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ObservationReviewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stationId != widget.stationId) {
      _processingIds.clear();
      _query.clear();
      _typeFilter = 'all';
      _queue = widget.api.getReviewQueue(widget.stationId);
    }
  }

  bool _matchesQuery(ObservationQueueItem item) =>
      observationQueueItemMatchesQuery(item, _query.text);

  Future<void> _refresh() async {
    final next = widget.api.getReviewQueue(widget.stationId);
    setState(() {
      _queue = next;
    });
    // FutureBuilder renders request errors; swallowing here prevents an
    // unhandled async error from pull-to-refresh or the toolbar callback.
    try {
      await next;
    } catch (_) {
      // The failed future remains in _queue and is rendered by FutureBuilder.
    }
  }

  String _formatObservedAt(DateTime value) =>
      formatObservationQueueObservedAt(value);

  String _statusLabel(String status) => observationQueueStatusLabel(status);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        children: [
          Material(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'مراجعة النشرات',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF061B4A),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'تحديث',
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Column(
              children: [
                TextField(
                  controller: _query,
                  textDirection: TextDirection.rtl,
                  decoration: InputDecoration(
                    labelText: 'بحث في الطابور المحمّل',
                    hintText: 'النوع أو الحالة أو حقل من الحمولة',
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    border: const OutlineInputBorder(),
                    suffixIcon: _query.text.trim().isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'مسح البحث',
                            onPressed: () => setState(_query.clear),
                            icon: const Icon(Icons.clear),
                          ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final entry in [
                        ('all', 'الكل'),
                        ('hourly', 'ساعي'),
                        ('daily', 'يومي'),
                        ('phenomenon', 'ظاهرة'),
                      ])
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: 8),
                          child: FilterChip(
                            label: Text(entry.$2),
                            selected: _typeFilter == entry.$1,
                            onSelected: (_) =>
                                setState(() => _typeFilter = entry.$1),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<ObservationQueueItem>>(
              future: _queue,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return MetraAsyncStatePanel.loading(
                    message: 'جاري تحميل طابور المراجعة…',
                  );
                }
                if (snapshot.hasError) {
                  final error = snapshot.error;
                  final message = error == null
                      ? 'تعذر تحميل النشرات. تحقق من الاتصال والإعدادات ثم أعد المحاولة.'
                      : MetraErrorPresenter.queueLoadMessage(error);
                  return MetraAsyncStatePanel.error(
                    title: 'تعذر تحميل النشرات',
                    subtitle: message,
                    onRetry: _refresh,
                  );
                }
                var rows = snapshot.data ?? const <ObservationQueueItem>[];
                if (_typeFilter != 'all') {
                  rows = rows
                      .where((r) => r.observationType == _typeFilter)
                      .toList(growable: false);
                }
                rows = rows.where(_matchesQuery).toList(growable: false);
                final entries = buildObservationReviewListEntries(
                  rows,
                  typeFilter: _typeFilter,
                );
                if (entries.isEmpty) {
                  final hasQuery = _query.text.trim().isNotEmpty;
                  return MetraAsyncStatePanel.empty(
                    icon: Icons.fact_check_outlined,
                    title: hasQuery
                        ? 'لا توجد نشرات مطابقة'
                        : 'لا توجد نشرات بانتظار المراجعة',
                    subtitle: hasQuery
                        ? 'البحث محلي على الطابور المحمّل ولم يُستعلم الخادم من جديد.'
                        : 'عند إرسال تقارير من الراصدين ستظهر هنا لاتخاذ قرار الاعتماد أو الإرجاع.',
                    action: TextButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('تحديث'),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      if (entry is ObservationReviewSectionHeader) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 4, bottom: 2),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  entry.label,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF061B4A),
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              Text(
                                '${entry.count}',
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      final item = (entry as ObservationReviewRowEntry).item;
                      final busy = _processingIds.contains(item.id);
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Column(
                            children: [
                              ListTile(
                                leading: const CircleAvatar(
                                  child: Icon(Icons.assignment_outlined),
                                ),
                                title: Text(_typeLabel(item.observationType)),
                                subtitle: Text(
                                  '${_formatObservedAt(item.observedAt)} • ${_statusLabel(item.status)}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (item.payload.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                                  child: Align(
                                    alignment: AlignmentDirectional.centerStart,
                                    child: Text(
                                      item.payload.entries
                                          .take(8)
                                          .map((e) => '${e.key}: ${e.value}')
                                          .join(' · '),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Semantics(
                                        button: true,
                                        enabled: !busy,
                                        label: 'إرجاع النشرة للتصحيح',
                                        child: OutlinedButton.icon(
                                          onPressed: busy
                                              ? null
                                              : () => _decide(
                                                    item,
                                                    'return_for_correction',
                                                  ),
                                          icon: busy
                                              ? const SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                  ),
                                                )
                                              : const Icon(Icons.replay),
                                          label: const Text('إرجاع للتصحيح'),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Semantics(
                                        button: true,
                                        enabled: !busy,
                                        label: 'اعتماد النشرة',
                                        child: FilledButton.icon(
                                          onPressed: busy
                                              ? null
                                              : () => _decide(item, 'approve'),
                                          icon: busy
                                              ? const SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                  ),
                                                )
                                              : const Icon(Icons.check),
                                          label: const Text('اعتماد'),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _decide(ObservationQueueItem item, String decision) async {
    // Bind the decision to the station whose queue produced this item.
    // The user may switch stations while a confirmation dialog is open.
    final stationId = widget.stationId;
    if (item.stationId != stationId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('بيانات النشرة لا تطابق المحطة الحالية. حدّث قائمة المراجعة.'),
        ),
      );
      return;
    }
    String? note;
    if (decision == 'return_for_correction') {
      final controller = TextEditingController();
      try {
        note = await showDialog<String>(
          context: context,
          builder: (dialogContext) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: const Text('سبب الإرجاع'),
              content: TextField(
                controller: controller,
                autofocus: true,
                maxLength: 2000,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'اكتب الملاحظات المطلوبة لاستكمال النشرة',
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  onPressed: () {
                    final value = controller.text.trim();
                    if (value.isNotEmpty) {
                      Navigator.pop(dialogContext, value);
                    }
                  },
                  child: const Text('تأكيد الإرجاع'),
                ),
              ],
            ),
          ),
        );
      } finally {
        // Dispose after the dialog route has finished tearing down so the
        // TextField does not observe a disposed controller during exit animation.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          controller.dispose();
        });
      }
      if (note == null || note.isEmpty) return;
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('اعتماد النشرة'),
            content: const Text('هل تريد اعتماد هذه النشرة؟'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('اعتماد'),
              ),
            ],
          ),
        ),
      );
      if (confirmed != true) return;
    }

    if (!mounted ||
        stationId != widget.stationId ||
        _processingIds.contains(item.id)) {
      return;
    }
    setState(() => _processingIds.add(item.id));
    try {
      await widget.api.decideObservation(
        stationId: stationId,
        observationId: item.id,
        decision: decision,
        note: note,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال قرار المراجعة')),
      );
      await _refresh();
    } on MetraApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(MetraErrorPresenter.reviewDecisionMessage(error)),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(MetraErrorPresenter.messageFor(error))),
      );
    } finally {
      if (mounted) setState(() => _processingIds.remove(item.id));
    }
  }

  String _typeLabel(String type) => observationQueueTypeLabel(type);
}
