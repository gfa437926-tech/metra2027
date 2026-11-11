// ignore: deprecated_member_use
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../../core/api/metra_api_client.dart';

class StationAuditLogScreen extends StatefulWidget {
  const StationAuditLogScreen({
    super.key,
    required this.api,
    required this.stationId,
    this.stationName,
  });

  final MetraApiClient api;
  final String stationId;
  final String? stationName;

  @override
  State<StationAuditLogScreen> createState() => _StationAuditLogScreenState();
}

class _StationAuditLogScreenState extends State<StationAuditLogScreen> {
  late Future<List<StationAuditEvent>> _eventsFuture;

  @override
  void initState() {
    super.initState();
    _eventsFuture = widget.api.getStationAuditLog(widget.stationId);
  }

  void _reload() {
    setState(() {
      _eventsFuture = widget.api.getStationAuditLog(widget.stationId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: FutureBuilder<List<StationAuditEvent>>(
        future: _eventsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final error = snapshot.error;
            final message = error is MetraApiException && error.statusCode == 403
                ? 'لا تملك صلاحية عرض سجل هذه المحطة.'
                : error is MetraApiException && error.statusCode == 503
                    ? 'خدمة سجل التدقيق غير متاحة حالياً. حاول لاحقاً.'
                    : 'تعذر تحميل سجل التدقيق. تحقق من الاتصال ثم أعد المحاولة.';
            return _emptyState(
              icon: Icons.lock_clock_outlined,
              title: 'تعذر عرض السجل',
              message: message,
              action: FilledButton.tonalIcon(
                onPressed: _reload,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            );
          }

          final events = snapshot.data ?? const <StationAuditEvent>[];
          if (events.isEmpty) {
            return _emptyState(
              icon: Icons.history,
              title: 'لا توجد أحداث مسجلة',
              message: 'لم يُرجع الخادم أحداث تدقيق لهذه المحطة ضمن النطاق المتاح.',
              action: TextButton.icon(
                onPressed: _reload,
                icon: const Icon(Icons.refresh),
                label: const Text('تحديث السجل'),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.history, color: Color(0xFF087CF0)),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'سجل تدقيق المحطة',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(widget.stationName ?? widget.stationId),
                      const SizedBox(height: 8),
                      const Text(
                        'سجل للعمليات المتعلقة ببيانات المحطة وتعييناتها. لا يمثل هذا أرشيف النشرات أو تاريخ الرصدات الجوية.',
                        style: TextStyle(height: 1.45, color: Color(0xFF64748B)),
                      ),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: TextButton.icon(
                          onPressed: _reload,
                          icon: const Icon(Icons.refresh),
                          label: const Text('تحديث'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              ...events.map(_eventCard),
              const SizedBox(height: 12),
              const Text(
                'عرض للقراءة فقط. لا يوفر هذا المسار تعديل أحداث التدقيق أو حذفها.',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _eventCard(StationAuditEvent event) {
    final previous = event.previousStatus;
    final resulting = event.resultingStatus;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.verified_user_outlined, color: Color(0xFF087CF0)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _actionLabel(event.action),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  event.occurredAt.toUtc().toIso8601String(),
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
            const Divider(),
            _field('نوع العنصر', _entityLabel(event.entityType)),
            _field('معرّف العنصر', event.entityId),
            _field('المنفذ', event.actorId),
            if (event.targetUserId != null) _field('المستخدم المعني', event.targetUserId!),
            if (event.roleCode != null) _field('رمز الدور', event.roleCode!),
            if (previous != null || resulting != null)
              _field('حالة الاعتماد', '${previous ?? 'غير محددة'} → ${resulting ?? 'غير محددة'}'),
            if (event.validFrom != null) _field('صالح اعتباراً من', event.validFrom!),
            if (event.validTo != null) _field('صالح حتى', event.validTo!),
            if (event.reason != null && event.reason!.trim().isNotEmpty)
              _field('السبب', event.reason!),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 112,
              child: Text(label, style: const TextStyle(color: Color(0xFF64748B))),
            ),
            Expanded(child: SelectableText(value)),
          ],
        ),
      );

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String message,
    Widget? action,
  }) =>
      Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 42, color: const Color(0xFF64748B)),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              if (action != null) ...[const SizedBox(height: 12), action],
            ],
          ),
        ),
      );

  String _actionLabel(String action) => switch (action) {
        'insert' => 'إنشاء سجل',
        'update' => 'تحديث سجل',
        'delete' => 'حذف سجل',
        'approve' => 'اعتماد',
        'return' => 'إرجاع',
        'assign' => 'تعيين',
        'revoke' => 'إلغاء تعيين',
        _ => action,
      };

  String _entityLabel(String entityType) => switch (entityType) {
        'station' => 'المحطة',
        'station_assignment' => 'تعيين محطة',
        _ => entityType,
      };
}
