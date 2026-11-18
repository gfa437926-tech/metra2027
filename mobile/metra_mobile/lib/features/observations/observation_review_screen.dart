import 'package:material_ui/material_ui.dart';
import '../../core/api/metra_api_client.dart';
import '../../core/errors/metra_error_presenter.dart';

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

  @override
  void initState() {
    super.initState();
    _queue = widget.api.getReviewQueue(widget.stationId);
  }

  @override
  void didUpdateWidget(covariant ObservationReviewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stationId != widget.stationId) {
      _processingIds.clear();
      _queue = widget.api.getReviewQueue(widget.stationId);
    }
  }

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

  String _formatObservedAt(DateTime value) {
    final local = value.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  String _statusLabel(String status) => switch (status) {
        'submitted' => 'بانتظار المراجعة',
        'approved' => 'معتمدة',
        'returned' => 'مُرجَعة للتصحيح',
        'return_for_correction' => 'مُرجَعة للتصحيح',
        _ => status,
      };

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
          Expanded(
            child: FutureBuilder<List<ObservationQueueItem>>(
              future: _queue,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  final error = snapshot.error;
                  final message = error == null
                      ? 'تعذر تحميل النشرات. تحقق من الاتصال والإعدادات ثم أعد المحاولة.'
                      : MetraErrorPresenter.queueLoadMessage(error);
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cloud_off_outlined, size: 42),
                          const SizedBox(height: 12),
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
                final rows = snapshot.data ?? const <ObservationQueueItem>[];
                if (rows.isEmpty) {
                  return const Center(
                    child: Text('لا توجد نشرات بانتظار المراجعة'),
                  );
                }
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = rows[index];
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
                              Padding(
                                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                                child: Row(
                                  children: [
                                    Expanded(
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
                                    const SizedBox(width: 8),
                                    Expanded(
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

    if (!mounted || _processingIds.contains(item.id)) return;
    setState(() => _processingIds.add(item.id));
    try {
      await widget.api.decideObservation(
        stationId: widget.stationId,
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

  String _typeLabel(String type) => switch (type) {
        'daily' => 'نشرة يومية',
        'hourly' => 'نشرة ساعية',
        'phenomenon' => 'بلاغ ظاهرة جوية',
        _ => 'نشرة: $type',
      };
}
