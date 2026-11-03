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
              return Card(child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.assignment_outlined)),
                title: Text(_typeLabel(item.observationType)),
                subtitle: Text(item.observedAt.toLocal().toString() + ' • ' + item.status,
                  maxLines: 2, overflow: TextOverflow.ellipsis),
                trailing: const Icon(Icons.chevron_left),
              ));
            },
          ));
      },
    ),
  );

  String _typeLabel(String type) => switch (type) {
    'daily' => 'نشرة يومية',
    'hourly' => 'نشرة ساعية',
    'phenomenon' => 'بلاغ ظاهرة جوية',
    _ => 'نشرة: ' + type,
  };
}
