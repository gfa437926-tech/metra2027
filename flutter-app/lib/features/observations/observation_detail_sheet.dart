import 'package:flutter/material.dart';

import '../../core/api/metra_api_client.dart';
import 'observation_field_labels.dart';

/// Read-only detail for a station-scoped observation queue item (UTC only).
void showObservationDetailSheet({
  required BuildContext context,
  required ObservationQueueItem item,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, controller) {
        final Map<String, dynamic> fields = _flattenPayload(item.payload);
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: ListView(
              controller: controller,
              children: [
                Text(
                  _typeLabel(item.observationType),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 6),
                Text('الحالة: ${item.status}',
                    style: const TextStyle(color: Color(0xFF64748B))),
                Text('وقت الرصد: ${_formatUtc(item.observedAt)}',
                    style: const TextStyle(color: Color(0xFF64748B))),
                Text('المعرّف: ${item.id}',
                    style: const TextStyle(
                        color: Color(0xFF94A3B8), fontSize: 12)),
                if (item.reviewNote != null &&
                    item.reviewNote!.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Card(
                    color: const Color(0xFFFFF7ED),
                    child: ListTile(
                      title: const Text('ملاحظة المراجع'),
                      subtitle: Text(item.reviewNote!),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                const Text(
                  'حقول الحمولة (كما أعادها الخادم)',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                if (fields.isEmpty)
                  const Text('لا توجد حقول في الحمولة.')
                else
                  ...fields.entries.map((e) {
                    final label = observationFieldLabels[e.key] ?? e.key;
                    return Card(
                      child: ListTile(
                        title: Text(
                          label == e.key ? e.key : '$label (${e.key})',
                        ),
                        subtitle: Text('${e.value}'),
                      ),
                    );
                  }),
              ],
            ),
          ),
        );
      },
    ),
  );
}

Map<String, dynamic> _flattenPayload(Map<String, dynamic> payload) {
  final values = payload['values'];
  if (values is Map) {
    return Map<String, dynamic>.from(values);
  }
  return Map<String, dynamic>.from(payload)
    ..removeWhere((key, value) => value is Map || value is List);
}

String _typeLabel(String type) {
  final t = type.toLowerCase();
  if (t.contains('hour')) return 'نشرة ساعية';
  if (t.contains('day') || t.contains('daily')) return 'نشرة يومية';
  if (t.contains('phenom')) return 'بلاغ ظاهرة';
  return 'نشرة: $type';
}

String _formatUtc(DateTime value) {
  final utc = value.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${utc.year}-${two(utc.month)}-${two(utc.day)} '
      '${two(utc.hour)}:${two(utc.minute)}:${two(utc.second)} UTC';
}
