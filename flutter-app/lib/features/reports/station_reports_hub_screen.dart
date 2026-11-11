import 'package:flutter/material.dart';

import '../../core/api/metra_api_client.dart';
import 'observation_status_screen.dart';
import 'observation_history_screen.dart';
import '../admin/manual_archive_screen.dart';
import '../admin/station_audit_log_screen.dart';

/// Hub for station-scoped reports that exist against live APIs, plus honest unbound shells.
class StationReportsHubScreen extends StatelessWidget {
  const StationReportsHubScreen({
    super.key,
    required this.api,
    required this.stationId,
  });

  final MetraApiClient api;
  final String stationId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تقارير المحطة')),
      body: ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        const Card(
          color: Color(0xFFEEF6FA),
          child: ListTile(
            title: Text('التقارير'),
            subtitle: Text(
              'يُعرض فقط ما له مصدر خادمي. لا مجاميع مناخية مخترعة.',
            ),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.fact_check_outlined),
            title: const Text('حالة نشرات المحطة'),
            subtitle: const Text('طابور المراجعة والمُرجَع من API'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ObservationStatusScreen(
                    api: api,
                    stationId: stationId,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.history_edu_outlined),
            title: const Text('سجل النشرات المتاح'),
            subtitle: const Text('مرشحات النوع والفترة UTC وتفاصيل السجلات من الطوابير الحالية'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ObservationHistoryScreen(
                    api: api,
                    stationId: stationId,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.archive_outlined),
            title: const Text('التقرير الشهري الإداري'),
            subtitle: const Text('ملخص تأكيدات أرشفة Excel فقط'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ManualArchiveScreen(
                    api: api,
                    stationId: stationId,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.history),
            title: const Text('سجل تدقيق المحطة والتعيينات'),
            subtitle: const Text('الأحداث والصلاحيات والتغييرات المسجلة من الخادم'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => StationAuditLogScreen(
                    api: api,
                    stationId: stationId,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        const Card(
          color: Color(0xFFFFF7E8),
          child: ListTile(
            title: Text('مناخي / سنوي / مطري'),
            subtitle: Text(
              'التقارير الشهرية والسنوية والمناخية والمطرية والزراعية وحرارة التربة لا تملك حالياً عقود قراءة وتجميع معتمدة في Backend. كما أن الحقول والوحدات والمعادلات وحدود الفترات تحتاج اعتماداً؛ لذلك لا تُعرض مجاميع أو رسوم افتراضية.',
            ),
          ),
        ),
      ],
    ),
    );
  }
}
