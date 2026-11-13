// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import '../../core/api/metra_api_client.dart';
import '../../core/widgets/metra_ui.dart';

/// Independent electronic meteorological-record audit module (read-only UI).
/// Records are protected from edit/delete from the interface.
/// Full provenance and backend audit contracts remain to be fully wired.
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

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        const MetraPageHeader(
          title: 'التدقيق الإلكتروني',
          subtitle:
              'وحدة مستقلة لعرض السجلات المدققة والقيم الأصلية والمعدلة. السجلات محمية من التعديل أو الحذف من الواجهة.',
        ),
        const SizedBox(height: 8),
        const MetraStatusBanner(
          tone: MetraBannerTone.info,
          message:
              'هذه الشاشة جاهزة للعرض والقراءة فقط. ربط مصدر التدقيق الإنتاجي وعقود الصلاحيات يتم عند توفر API المعتمد. لا تُعدّل سجلات التدقيق من العميل.',
        ),
        const SizedBox(height: 14),
        MetraSectionCard(
          title: 'البحث والتصفية',
          child: Column(
            children: [
              TextField(
                controller: _search,
                decoration: const InputDecoration(
                  labelText: 'بحث في رقم الرصدة أو نوع العملية أو المنفذ',
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
                    ('review', 'مراجعة'),
                    ('correction', 'تصحيح'),
                  ])
                    FilterChip(
                      label: Text(item.$2),
                      selected: _filter == item.$1,
                      onSelected: (_) => setState(() => _filter = item.$1),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const MetraSectionCard(
          title: 'سجلات التدقيق (قراءة فقط)',
          trailing: const MetraStatusBadge(
            label: 'محمي',
            tone: MetraBannerTone.success,
          ),
          child: const Column(
            children: [
              _AuditRow(
                operation: 'مراجعة',
                original: 'قيمة أصلية محفوظة',
                modified: 'لا يوجد تعديل',
                actor: 'مراجع مخوّل',
                when: '—',
                reason: 'اعتماد روتيني',
              ),
              const Divider(height: 24),
              const MetraEmptyState(
                icon: Icons.shield_outlined,
                title: 'لا توجد سجلات تدقيق معروضة حالياً',
                message:
                    'عند ربط عقد التدقيق الإلكتروني المعتمد ستظهر هنا القيم الأصلية والمعدلة والفروقات ووقت التعديل وهوية المنفذ وسبب العملية. لا يمكن تعديل أو حذف هذه السجلات من الواجهة.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AuditRow extends StatelessWidget {
  const _AuditRow({
    required this.operation,
    required this.original,
    required this.modified,
    required this.actor,
    required this.when,
    required this.reason,
  });

  final String operation;
  final String original;
  final String modified;
  final String actor;
  final String when;
  final String reason;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const MetraStatusBadge(label: 'قراءة فقط', tone: MetraBannerTone.info),
            const SizedBox(width: 8),
            Text(operation, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 8),
        Text('الأصلية: $original', style: const TextStyle(color: metraMuted)),
        Text('المعدلة: $modified', style: const TextStyle(color: metraMuted)),
        Text('المنفذ: $actor · $when', style: const TextStyle(color: metraMuted)),
        Text('السبب: $reason', style: const TextStyle(color: metraMuted)),
      ],
    );
  }
}
