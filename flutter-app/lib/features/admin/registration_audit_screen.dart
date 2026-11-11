import 'package:flutter/material.dart';

import '../../core/api/metra_api_client.dart';

class RegistrationAuditScreen extends StatefulWidget {
  const RegistrationAuditScreen({
    super.key,
    required this.api,
    required this.stationId,
    this.systemStage = false,
  });

  final MetraApiClient api;
  final String stationId;
  final bool systemStage;

  @override
  State<RegistrationAuditScreen> createState() =>
      _RegistrationAuditScreenState();
}

class _RegistrationAuditScreenState extends State<RegistrationAuditScreen> {
  late Future<List<Map<String, dynamic>>> _events;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _events = widget.api.listRegistrationAudit(
      widget.stationId,
      systemStage: widget.systemStage,
    );
  }

  String _eventLabel(Object? value) => switch (value) {
        'submitted' => 'تقديم طلب',
        'approved' => 'اعتماد',
        'rejected' => 'رفض',
        'returned' => 'إعادة للمراجعة',
        'station_approved' => 'اعتماد المحطة',
        'system_approved' => 'الاعتماد النظامي',
        _ => value?.toString() ?? 'حدث غير محدد',
      };

  String _utc(Object? value) {
    if (value is! String) return 'وقت UTC غير متوفر';
    final parsed = DateTime.tryParse(value);
    return parsed == null
        ? 'وقت UTC غير صالح'
        : '${parsed.toUtc().toIso8601String()} UTC';
  }

  String _shortId(Object? value) {
    final id = value?.toString() ?? '';
    if (id.isEmpty) return 'غير متوفر';
    return id.length > 12 ? '${id.substring(0, 8)}…' : id;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.systemStage
              ? 'سجل تدقيق الاعتماد النظامي'
              : 'سجل تدقيق طلبات المحطة'),
          actions: [
            IconButton(
              tooltip: 'تحديث السجل',
              onPressed: () => setState(_load),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _events,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_off_outlined, size: 40),
                      const SizedBox(height: 10),
                      const Text('تعذر تحميل سجل التدقيق أو لا توجد صلاحية.'),
                      TextButton(
                        onPressed: () => setState(_load),
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                ),
              );
            }
            final events = snapshot.data ?? const <Map<String, dynamic>>[];
            if (events.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('لا توجد أحداث تدقيق مسجلة لهذه المرحلة والمحطة.'),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: events.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final event = events[index];
                final note = event['decision_note']?.toString();
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _eventLabel(event['event_type']),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text('وقت الحدث: ${_utc(event['occurred_at'])}'),
                        Text('معرّف الطلب: ${_shortId(event['request_id'])}'),
                        Text('صاحب الطلب: ${_shortId(event['user_id'])}'),
                        Text('المنفذ: ${_shortId(event['actor_user_id'])}'),
                        if (event['terms_version'] != null)
                          Text('إصدار الشروط: ${event['terms_version']}'),
                        if (note != null && note.trim().isNotEmpty) ...[
                          const Divider(),
                          Text('ملاحظة القرار: $note'),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
