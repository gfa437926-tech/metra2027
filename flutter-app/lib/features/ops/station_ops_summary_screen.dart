import 'package:flutter/material.dart';
import '../../core/api/metra_api_client.dart';

/// Read-only operational summary for a station from live API (not local cache).
class StationOpsSummaryScreen extends StatefulWidget {
  const StationOpsSummaryScreen({
    super.key,
    required this.api,
    required this.stationId,
  });

  final MetraApiClient api;
  final String stationId;

  @override
  State<StationOpsSummaryScreen> createState() => _StationOpsSummaryScreenState();
}

class _StationOpsSummaryScreenState extends State<StationOpsSummaryScreen> {
  bool _loading = true;
  String? _error;
  int _reviewCount = 0;
  int _returnedCount = 0;
  int _faultCount = 0;
  int _supportCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final review = await widget.api.getReviewQueue(widget.stationId, limit: 100);
      final returned = await widget.api.getReturnedObservations(widget.stationId, limit: 100);
      final faults = await widget.api.listEquipmentFaults(widget.stationId, limit: 100);
      final support = await widget.api.listSupportIncidents(widget.stationId, limit: 100);
      if (!mounted) return;
      setState(() {
        _reviewCount = review.length;
        _returnedCount = returned.length;
        _faultCount = faults.length;
        _supportCount = support.length;
        _loading = false;
      });
    } on MetraApiException catch (e) {
      if (!mounted) return;
      final message = switch (e.statusCode) {
        401 => 'انتهت الجلسة أو يلزم تسجيل الدخول.',
        403 => 'ليست لديك صلاحية قراءة ملخص هذه المحطة.',
        503 => 'إحدى خدمات التشغيل غير متاحة حالياً.',
        _ => 'تعذر تحميل الملخص (${e.statusCode}).',
      };
      setState(() {
        _error = message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر تحميل الملخص من الخادم.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ملخص تشغيل المحطة'),
          actions: [
            IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh)),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('تعذر التحميل من الخادم:\n$_error'),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const Text(
                        'الأرقام من واجهة API مباشرة ضمن صلاحية المحطة. لا تُعرض بيانات محطة أخرى.',
                        style: TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 16),
                      _tile('نشرات بانتظار المراجعة', '$_reviewCount', Icons.fact_check_outlined),
                      _tile('نشرات مُرجَعة', '$_returnedCount', Icons.undo),
                      _tile('أعطال معدات مفتوحة/مسجّلة', '$_faultCount', Icons.build_outlined),
                      _tile('بلاغات دعم', '$_supportCount', Icons.support_agent),
                    ],
                  ),
      ),
    );
  }

  Widget _tile(String title, String value, IconData icon) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
