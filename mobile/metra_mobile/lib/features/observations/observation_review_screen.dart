import 'package:flutter/material.dart';
import '../../core/api/metra_api_client.dart';
import 'returned_observation_editor.dart';

/// Host app supplies an authenticated API client and an authorized station UUID.
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

class _ObservationReviewScreenState extends State<ObservationReviewScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late Future<List<ObservationQueueItem>> _queue;
  late Future<List<ObservationQueueItem>> _returned;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _queue = widget.api.getReviewQueue(widget.stationId);
    _returned = widget.api.getReturnedObservations(widget.stationId);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _refreshReview() async {
    setState(() => _queue = widget.api.getReviewQueue(widget.stationId));
    await _queue;
  }

  Future<void> _refreshReturned() async {
    setState(
        () => _returned = widget.api.getReturnedObservations(widget.stationId));
    await _returned;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('مراجعة النشرات'),
          bottom: TabBar(
            controller: _tabs,
            tabs: const [
              Tab(text: 'طابور المراجعة'),
              Tab(text: 'مُرجَعة لإعادة التقديم'),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'تحديث',
              onPressed: () async {
                if (_tabs.index == 0) {
                  await _refreshReview();
                } else {
                  await _refreshReturned();
                }
              },
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: TabBarView(
          controller: _tabs,
          children: [
            _QueueBody(
              future: _queue,
              onRefresh: _refreshReview,
              emptyText: 'لا توجد نشرات بانتظار المراجعة',
              itemBuilder: (item) => _ReviewActions(
                item: item,
                onDecide: _decide,
              ),
            ),
            _QueueBody(
              future: _returned,
              onRefresh: _refreshReturned,
              emptyText: 'لا توجد نشرات مُرجَعة لك في هذه المحطة',
              itemBuilder: (item) => _ReturnedActions(
                item: item,
                onResubmit: _resubmit,
              ),
            ),
          ],
        ),
      );

  Future<void> _decide(ObservationQueueItem item, String decision) async {
    String? note;
    if (decision == 'return_for_correction') {
      final controller = TextEditingController();
      note = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
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
                if (value.isNotEmpty) Navigator.pop(dialogContext, value);
              },
              child: const Text('تأكيد الإرجاع'),
            ),
          ],
        ),
      );
      controller.dispose();
      if (note == null || note.isEmpty) return;
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
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
      );
      if (confirmed != true) return;
    }

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
      await _refreshReview();
    } on MetraApiException catch (error) {
      if (!mounted) return;
      final message = switch (error.statusCode) {
        403 => 'ليست لديك صلاحية تنفيذ هذا القرار',
        409 => 'لا يمكن اعتماد نشرتك بنفسك أو تغيّرت حالة النشرة',
        _ => 'تعذر تنفيذ القرار. حاول مجدداً',
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _resubmit(ObservationQueueItem item) async {
    final edited = await showReturnedObservationEditor(
      context: context,
      item: item,
    );
    if (edited == null) return;

    try {
      await widget.api.resubmitObservation(
        stationId: widget.stationId,
        observationId: item.id,
        payload: edited,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أُعيد تقديم النشرة للمراجعة')),
      );
      await _refreshReturned();
      await _refreshReview();
    } on MetraApiException catch (error) {
      if (!mounted) return;
      final message = switch (error.statusCode) {
        403 => 'ليست لديك صلاحية إعادة التقديم أو لست مالك النشرة',
        409 => 'النشرة ليست في حالة مُرجَعة',
        _ => 'تعذر إعادة التقديم. حاول مجدداً',
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }
}

class _QueueBody extends StatelessWidget {
  const _QueueBody({
    required this.future,
    required this.onRefresh,
    required this.emptyText,
    required this.itemBuilder,
  });

  final Future<List<ObservationQueueItem>> future;
  final Future<void> Function() onRefresh;
  final String emptyText;
  final Widget Function(ObservationQueueItem item) itemBuilder;

  @override
  Widget build(BuildContext context) => FutureBuilder<List<ObservationQueueItem>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final error = snapshot.error;
            final message = error is MetraApiException && error.statusCode == 401
                ? 'يرجى تسجيل الدخول أولاً'
                : error is MetraApiException && error.statusCode == 403
                    ? 'ليس لديك صلاحية الوصول إلى نشرات هذه المحطة'
                    : 'تعذر تحميل النشرات. تحقق من الاتصال والإعدادات ثم أعد المحاولة.';
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
                      onPressed: onRefresh,
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
            return Center(child: Text(emptyText));
          }
          return RefreshIndicator(
            onRefresh: onRefresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = rows[index];
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
                            [
                              item.observedAt.toLocal().toString(),
                              item.status,
                              if (item.reviewNote != null &&
                                  item.reviewNote!.isNotEmpty)
                                'ملاحظة: ${item.reviewNote}',
                            ].join(' • '),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        itemBuilder(item),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      );

  static String _typeLabel(String type) => switch (type) {
        'daily' => 'نشرة يومية',
        'hourly' => 'نشرة ساعية',
        'phenomenon' => 'بلاغ ظاهرة جوية',
        _ => 'نشرة: $type',
      };
}

class _ReviewActions extends StatelessWidget {
  const _ReviewActions({required this.item, required this.onDecide});

  final ObservationQueueItem item;
  final Future<void> Function(ObservationQueueItem item, String decision) onDecide;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => onDecide(item, 'return_for_correction'),
                icon: const Icon(Icons.replay),
                label: const Text('إرجاع للتصحيح'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => onDecide(item, 'approve'),
                icon: const Icon(Icons.check),
                label: const Text('اعتماد'),
              ),
            ),
          ],
        ),
      );
}

class _ReturnedActions extends StatelessWidget {
  const _ReturnedActions({required this.item, required this.onResubmit});

  final ObservationQueueItem item;
  final Future<void> Function(ObservationQueueItem item) onResubmit;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => onResubmit(item),
            icon: const Icon(Icons.upload),
            label: const Text('تصحيح وإعادة التقديم'),
          ),
        ),
      );
}
