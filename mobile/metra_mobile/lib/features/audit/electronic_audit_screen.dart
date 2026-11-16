// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import '../../core/api/metra_api_client.dart';
import '../../core/widgets/metra_ui.dart';

/// Read-only electronic audit module.
///
/// When a station is selected, loads the live station operational audit log
/// from the .NET API (`GET /api/v1/stations/{id}/audit-log`). This is **not**
/// observation payload provenance and does not invent meteorological values.
/// Client UI never offers edit/delete of audit rows.
class ElectronicAuditScreen extends StatefulWidget {
  const ElectronicAuditScreen({
    super.key,
    required this.api,
    this.stationId,
  });

  final MetraApiClient api;
  final String? stationId;

  @override
  State<ElectronicAuditScreen> createState() => _ElectronicAuditScreenState();
}

class _ElectronicAuditScreenState extends State<ElectronicAuditScreen> {
  final _search = TextEditingController();
  String _filter = 'all';
  Future<List<StationAuditEvent>>? _eventsFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant ElectronicAuditScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stationId != widget.stationId) {
      _reload();
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reload() {
    final stationId = widget.stationId;
    setState(() {
      _eventsFuture = (stationId == null || stationId.isEmpty)
          ? null
          : widget.api.getStationAuditLog(stationId);
    });
  }

  List<StationAuditEvent> _applyFilters(List<StationAuditEvent> events) {
    final q = _search.text.trim().toLowerCase();
    return events.where((e) {
      if (_filter != 'all') {
        final action = e.action.toLowerCase();
        if (!action.contains(_filter)) return false;
      }
      if (q.isEmpty) return true;
      final hay = [
        e.action,
        e.entityType,
        e.entityId,
        e.actorId,
        e.reason ?? '',
        e.roleCode ?? '',
        e.previousStatus ?? '',
        e.resultingStatus ?? '',
      ].join(' ').toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final stationId = widget.stationId;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        const MetraPageHeader(
          title: 'التدقيق الإلكتروني',
          subtitle:
              'عرض قراءة فقط لسجل تدقيق المحطة التشغيلي. لا يمكن تعديل السجلات أو حذفها من التطبيق.',
        ),
        const SizedBox(height: 8),
        MetraStatusBanner(
          tone: MetraBannerTone.info,
          message: stationId == null || stationId.isEmpty
              ? 'اختر محطة من دليل المحطات لعرض سجل التدقيق التشغيلي المرتبط بها من الخادم.'
              : 'المصدر: واجهة .NET لسجل تدقيق المحطة. هذا ليس أرشيف قيم الرصد العلمية ولا يعرض بيانات وهمية.',
        ),
        const SizedBox(height: 14),
        MetraSectionCard(
          title: 'البحث والتصفية',
          child: Column(
            children: [
              TextField(
                controller: _search,
                enabled: stationId != null && stationId.isNotEmpty,
                decoration: const InputDecoration(
                  labelText: 'بحث في العملية أو الكيان أو المنفذ',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  for (final item in const [
                    ('all', 'الكل'),
                    ('create', 'إنشاء'),
                    ('update', 'تعديل'),
                    ('approve', 'اعتماد'),
                    ('revoke', 'إلغاء'),
                    ('assign', 'تكليف'),
                  ])
                    FilterChip(
                      label: Text(item.$2),
                      selected: _filter == item.$1,
                      onSelected: stationId == null || stationId.isEmpty
                          ? null
                          : (_) => setState(() => _filter = item.$1),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        MetraSectionCard(
          title: 'سجلات التدقيق (قراءة فقط)',
          trailing: const MetraStatusBadge(
            label: 'محمي',
            tone: MetraBannerTone.success,
          ),
          child: _buildBody(stationId),
        ),
      ],
    );
  }

  Widget _buildBody(String? stationId) {
    if (stationId == null || stationId.isEmpty) {
      return const MetraEmptyState(
        icon: Icons.shield_outlined,
        title: 'لم تُحدد محطة',
        message:
            'بعد اختيار محطة سيُحمَّل سجل التدقيق التشغيلي من الخادم ضمن صلاحياتك.',
      );
    }

    final future = _eventsFuture;
    if (future == null) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return FutureBuilder<List<StationAuditEvent>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          final error = snapshot.error;
          final message = error is MetraApiException && error.statusCode == 403
              ? 'لا تملك صلاحية عرض سجل تدقيق هذه المحطة.'
              : error is MetraApiException && error.statusCode == 503
                  ? 'خدمة سجل التدقيق غير متاحة حالياً.'
                  : 'تعذر تحميل سجل التدقيق. تحقق من الاتصال ثم أعد المحاولة.';
          return Column(
            children: [
              MetraEmptyState(
                icon: Icons.error_outline,
                title: 'تعذر التحميل',
                message: message,
              ),
              TextButton.icon(
                onPressed: _reload,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          );
        }

        final filtered = _applyFilters(snapshot.data ?? const <StationAuditEvent>[]);
        if (filtered.isEmpty) {
          return Column(
            children: [
              const MetraEmptyState(
                icon: Icons.history,
                title: 'لا توجد أحداث ضمن النطاق',
                message:
                    'الخادم لم يُرجع أحداثاً مطابقة للتصفية الحالية، أو لا توجد أحداث لهذه المحطة.',
              ),
              TextButton.icon(
                onPressed: _reload,
                icon: const Icon(Icons.refresh),
                label: const Text('تحديث'),
              ),
            ],
          );
        }

        return Column(
          children: [
            for (var i = 0; i < filtered.length; i++) ...[
              if (i > 0) const Divider(height: 24),
              _LiveAuditRow(event: filtered[i]),
            ],
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                onPressed: _reload,
                icon: const Icon(Icons.refresh),
                label: const Text('تحديث'),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LiveAuditRow extends StatelessWidget {
  const _LiveAuditRow({required this.event});

  final StationAuditEvent event;

  @override
  Widget build(BuildContext context) {
    final when = event.occurredAt.toUtc().toIso8601String();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const MetraStatusBadge(label: 'قراءة فقط', tone: MetraBannerTone.info),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                event.action,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'الكيان: ${event.entityType} / ${event.entityId}',
          style: const TextStyle(color: metraMuted),
        ),
        Text('المنفذ: ${event.actorId}', style: const TextStyle(color: metraMuted)),
        Text('الوقت (UTC): $when', style: const TextStyle(color: metraMuted)),
        if (event.roleCode != null && event.roleCode!.isNotEmpty)
          Text('الدور: ${event.roleCode}', style: const TextStyle(color: metraMuted)),
        if (event.previousStatus != null || event.resultingStatus != null)
          Text(
            'الحالة: ${event.previousStatus ?? '—'} → ${event.resultingStatus ?? '—'}',
            style: const TextStyle(color: metraMuted),
          ),
        if (event.reason != null && event.reason!.isNotEmpty)
          Text('السبب: ${event.reason}', style: const TextStyle(color: metraMuted)),
      ],
    );
  }
}
