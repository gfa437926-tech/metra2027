// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import '../../core/api/metra_api_client.dart';

/// Host app supplies an authenticated API client and an authorized station UUID.
class ObservationReviewScreen extends StatefulWidget {
  const ObservationReviewScreen({super.key, required this.api, required this.stationId});
  final MetraApiClient api;
  final String stationId;

  @override
  State<ObservationReviewScreen> createState() => _ObservationReviewScreenState();
}

class _ObservationReviewScreenState extends State<ObservationReviewScreen> {
  late Future<List<ObservationQueueItem>> _queue;

  @override
  void initState() {
    super.initState();
    _queue = widget.api.getReviewQueue(widget.stationId);
  }

  Future<void> _refresh() async {
    setState(() => _queue = widget.api.getReviewQueue(widget.stationId));
    await _queue;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('مراجعة النشرات'),
      actions: [IconButton(tooltip: 'تحديث', onPressed: _refresh,
        icon: const Icon(Icons.refresh))]),
    body: FutureBuilder<List<ObservationQueueItem>>(
      future: _queue,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          final error = snapshot.error;
          final message = error is MetraApiException && error.statusCode == 401
              ? 'يرجى تسجيل الدخول أولاً'
              : error is MetraApiException && error.statusCode == 403
                  ? 'ليس لديك صلاحية مراجعة نشرات هذه المحطة'
                  : 'تعذر تحميل النشرات. تحقق من الاتصال والإعدادات ثم أعد المحاولة.';
          return Center(child: Padding(padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.cloud_off_outlined, size: 42),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(onPressed: _refresh,
                icon: const Icon(Icons.refresh), label: const Text('إعادة المحاولة')),
            ])));
        }
        final rows = snapshot.data ?? const <ObservationQueueItem>[];
        if (rows.isEmpty) {
          return const Center(child: Text('لا توجد نشرات بانتظار المراجعة'));
        }
        return RefreshIndicator(onRefresh: _refresh,
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = rows[index];
              return Card(child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(children: [
                  ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.assignment_outlined)),
                    title: Text(_typeLabel(item.observationType)),
                    subtitle: Text('${item.observedAt.toLocal()} • ${item.status}',
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: Row(children: [
                      Expanded(child: OutlinedButton.icon(
                        onPressed: () => _decide(item, 'return_for_correction'),
                        icon: const Icon(Icons.replay),
                        label: const Text('إرجاع للتصحيح'),
                      )),
                      const SizedBox(width: 8),
                      Expanded(child: FilledButton.icon(
                        onPressed: () => _decide(item, 'approve'),
                        icon: const Icon(Icons.check),
                        label: const Text('اعتماد'),
                      )),
                    ]),
                  ),
                ]),
              ));
            },
          ));
      },
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
      await _refresh();
    } on MetraApiException catch (error) {
      if (!mounted) return;
      final message = error.statusCode == 403
          ? 'ليست لديك صلاحية تنفيذ هذا القرار'
          : error.statusCode == 409
              ? 'تمت معالجة النشرة مسبقاً أو تغيرت حالتها'
              : 'تعذر تنفيذ القرار. حاول مجدداً';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  String _typeLabel(String type) => switch (type) {
    'daily' => 'نشرة يومية',
    'hourly' => 'نشرة ساعية',
    'phenomenon' => 'بلاغ ظاهرة جوية',
    _ => 'نشرة: $type',
  };
}
