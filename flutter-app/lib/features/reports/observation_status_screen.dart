import 'package:flutter/material.dart';

import '../../core/api/metra_api_client.dart';

/// Live review/returned observation counts for a station (UTC display).
class ObservationStatusScreen extends StatefulWidget {
  const ObservationStatusScreen({
    super.key,
    required this.api,
    required this.stationId,
  });

  final MetraApiClient api;
  final String stationId;

  @override
  State<ObservationStatusScreen> createState() => _ObservationStatusScreenState();
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
        await widget.api.getReviewQueue(widget.stationId);
    final List<ObservationQueueItem> returned =
        await widget.api.getReturnedObservations(widget.stationId);
    int hourlyReview = 0;
    int dailyReview = 0;
    for (final ObservationQueueItem item in review) {
      final String type = item.observationType.toLowerCase();
      if (type.contains('hour')) {
        hourlyReview++;
      } else if (type.contains('day') || type.contains('daily')) {
        dailyReview++;
      }
    }
    return _StatusSnapshot(
      reviewCount: review.length,
      returnedCount: returned.length,
      hourlyReview: hourlyReview,
      dailyReview: dailyReview,
    );
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('حالة نشرات المحطة'),
        actions: <Widget>[
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: FutureBuilder<_StatusSnapshot>(
        future: _future,
        builder: (BuildContext context, AsyncSnapshot<_StatusSnapshot> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Text('تعذر التحميل أو لا صلاحية لهذه المحطة.'),
            );
          }
          final _StatusSnapshot data = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              const Text(
                'الأوقات التشغيلية UTC. المصدر: طوابير المراجعة والإرجاع فقط.',
              ),
              const SizedBox(height: 12),
              _tile('بانتظار المراجعة', '${data.reviewCount}'),
              _tile('مُرجَعة للتصحيح', '${data.returnedCount}'),
              _tile('ساعي في طابور المراجعة', '${data.hourlyReview}'),
              _tile('يومي في طابور المراجعة', '${data.dailyReview}'),
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
}

class _StatusSnapshot {
  const _StatusSnapshot({
    required this.reviewCount,
    required this.returnedCount,
    required this.hourlyReview,
    required this.dailyReview,
  });

  final int reviewCount;
  final int returnedCount;
  final int hourlyReview;
  final int dailyReview;
}
