import 'package:flutter/material.dart';

import '../../core/api/metra_api_client.dart';

class StationAuditLogScreen extends StatefulWidget {
  const StationAuditLogScreen({
    super.key,
    required this.api,
    required this.stationId,
  });

  final MetraApiClient api;
  final String stationId;

  @override
  State<StationAuditLogScreen> createState() => _StationAuditLogScreenState();
}

class _StationAuditLogScreenState extends State<StationAuditLogScreen> {
  late Future<List<Map<String, dynamic>>> _events;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _events = widget.api.getStationAuditLog(widget.stationId);
  }

  String _utc(Object? value) {
    if (value is! String) return 'غير متوفر';
    final parsed = DateTime.tryParse(value);
    return parsed == null ? 'غير متوفر' : '${parsed.toUtc().toIso8601String()} UTC';
  }

  String _shortId(Object? value) {
    final id = value?.toString() ?? '';
    if (id.isEmpty) return 'غير متوفر';
    return id.length > 14 ? '${id.substring(0, 10)}…' : id;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('سجل تدقيق المحطة والتعيينات'),
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
                      const Icon(Icons.lock_outline, size: 40),
                      const SizedBox(height: 10),
                      const Text('تعذر تحميل سجل التدقيق أو لا توجد صلاحية للمحطة.'),
                      TextButton(
                        onPressed: () => setState(_load),
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                ),
              );
            }
            final rows = snapshot.data ?? const <Map<String, dynamic>>[];
            if (rows.isEmpty) {
              return const Center(child: Text('لا توجد أحداث تدقيق مسجلة لهذه المحطة.'));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final row = rows[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '${row['entity_type'] ?? 'كيان'} · ${row['action'] ?? 'حدث'}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text('الوقت: ${_utc(row['occurred_at'])}'),
                        Text('المنفذ: ${_shortId(row['actor_id'])}'),
                        Text('المستخدم المستهدف: ${_shortId(row['target_user_id'])}'),
                        Text('الدور: ${row['role_code'] ?? 'غير متوفر'}'),
                        Text('الحالة السابقة: ${row['previous_status'] ?? 'غير متوفرة'}'),
                        Text('الحالة الناتجة: ${row['resulting_status'] ?? 'غير متوفرة'}'),
                        Text('بداية السريان: ${_utc(row['valid_from'])}'),
                        Text('نهاية السريان: ${row['valid_to'] == null ? 'مفتوح' : _utc(row['valid_to'])}'),
                        if ((row['reason']?.toString() ?? '').trim().isNotEmpty) ...[
                          const Divider(),
                          Text('السبب: ${row['reason']}'),
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
