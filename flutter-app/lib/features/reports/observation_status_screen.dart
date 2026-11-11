import 'package:flutter/material.dart';

import '../../core/api/metra_api_client.dart';
import '../observations/observation_detail_sheet.dart';
import '../observations/observation_review_screen.dart';

/// Live review/returned observation status for a station (UTC display only).
class ObservationStatusScreen extends StatefulWidget {
  const ObservationStatusScreen({
    super.key,
    required this.api,
    required this.stationId,
  });

  final MetraApiClient api;
  final String stationId;

  @override
  State<ObservationStatusScreen> createState() =>
      _ObservationStatusScreenState();
}

class _ObservationStatusScreenState extends State<ObservationStatusScreen> {
  late Future<_StatusSnapshot> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_StatusSnapshot> _load() async {
    final List<ObservationQueueItem> review =
        await widget.api.getReviewQueue(widget.stationId, limit: 100);
    final List<ObservationQueueItem> returned =
        await widget.api.getReturnedObservations(widget.stationId, limit: 100);
    int hourlyReview = 0;
    int dailyReview = 0;
    int phenomenonReview = 0;
    for (final ObservationQueueItem item in review) {
      final String type = item.observationType.toLowerCase();
      if (type.contains('hour')) {
        hourlyReview++;
      } else if (type.contains('day') || type.contains('daily')) {
        dailyReview++;
      } else if (type.contains('phenom')) {
        phenomenonReview++;
      }
    }
    return _StatusSnapshot(
      review: review,
      returned: returned,
      hourlyReview: hourlyReview,
      dailyReview: dailyReview,
      phenomenonReview: phenomenonReview,
    );
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  void _openReview() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ObservationReviewScreen(
          api: widget.api,
          stationId: widget.stationId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('حالة نشرات المحطة'),
        actions: <Widget>[
          IconButton(
            tooltip: 'تحديث',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<_StatusSnapshot>(
        future: _future,
        builder:
            (BuildContext context, AsyncSnapshot<_StatusSnapshot> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final Object? err = snapshot.error;
            final String message = err is MetraApiException && err.statusCode == 403
                ? 'ليست لديك صلاحية قراءة نشرات هذه المحطة.'
                : err is MetraApiException && err.statusCode == 401
                    ? 'انتهت الجلسة. سجّل الدخول مجدداً.'
                    : 'تعذر التحميل. تحقق من الاتصال وصلاحية المحطة.';
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(message, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh),
                    label: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            );
          }
          final _StatusSnapshot data = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              const Text(
                'الأوقات بالتوقيت العالمي UTC فقط. تعرض هذه الشاشة طوابير العمل الحالية من الخادم، لا أرشيفاً تاريخياً شاملاً: طابور المراجعة حسب صلاحية المحطة، والمُرجَعات الخاصة بالمستخدم الحالي.',
              ),
              const SizedBox(height: 12),
              _tile('بانتظار المراجعة', '${data.review.length}'),
              _tile('مُرجَعة للتصحيح', '${data.returned.length}'),
              _tile('ساعي في طابور المراجعة', '${data.hourlyReview}'),
              _tile('يومي في طابور المراجعة', '${data.dailyReview}'),
              _tile('ظواهر في طابور المراجعة', '${data.phenomenonReview}'),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _openReview,
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('فتح شاشة المراجعة'),
              ),
              const SizedBox(height: 16),
              const Text(
                'عناصر طابور المراجعة المحمّلة (حتى 100 من الخادم)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (data.review.isEmpty)
                const Text('لا توجد نشرات بانتظار المراجعة.')
              else
                ...data.review.map(_itemCard),
              const SizedBox(height: 16),
              const Text(
                'النشرات المُرجَعة المحمّلة (حتى 100 من الخادم، للمستخدم الحالي)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (data.returned.isEmpty)
                const Text('لا توجد نشرات مُرجَعة.')
              else
                ...data.returned.map(_itemCard),
            ],
          );
        },
      ),
    );
  }

  Widget _tile(String title, String value) {
    return Card(
      child: ListTile(
        title: Text(title),
        trailing: Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
    );
  }

  Widget _itemCard(ObservationQueueItem item) {
    return Card(
      child: ListTile(
        title: Text(_typeLabel(item.observationType)),
        subtitle: Text(
          [
            _formatUtc(item.observedAt),
            _statusLabel(item.status),
            if (item.reviewNote != null && item.reviewNote!.isNotEmpty)
              'ملاحظة: ${item.reviewNote}',
          ].join(' • '),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.info_outline),
        onTap: () => showObservationDetailSheet(context: context, item: item),
      ),
    );
  }

  static String _statusLabel(String status) => switch (status.toLowerCase()) {
        'submitted' => 'بانتظار المراجعة',
        'returned' => 'مُرجَعة للتصحيح',
        'approved' => 'معتمدة',
        'rejected' => 'مرفوضة',
        'draft' => 'مسودة',
        _ => status,
      };

  static String _typeLabel(String type) {
    final String t = type.toLowerCase();
    if (t.contains('hour')) return 'نشرة ساعية';
    if (t.contains('day') || t.contains('daily')) return 'نشرة يومية';
    if (t.contains('phenom')) return 'بلاغ ظاهرة';
    return 'نشرة: $type';
  }

  /// Always render UTC; never convert to device local timezone.
  static String _formatUtc(DateTime value) {
    final DateTime utc = value.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${utc.year}-${two(utc.month)}-${two(utc.day)} '
        '${two(utc.hour)}:${two(utc.minute)}:${two(utc.second)} UTC';
  }
}

class _StatusSnapshot {
  const _StatusSnapshot({
    required this.review,
    required this.returned,
    required this.hourlyReview,
    required this.dailyReview,
    required this.phenomenonReview,
  });

  final List<ObservationQueueItem> review;
  final List<ObservationQueueItem> returned;
  final int hourlyReview;
  final int dailyReview;
  final int phenomenonReview;
}
