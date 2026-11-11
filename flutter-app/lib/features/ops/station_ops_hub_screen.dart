import 'package:flutter/material.dart';
import '../../core/api/metra_api_client.dart';
import '../maintenance/equipment_fault_screen.dart';
import '../support/support_incident_screen.dart';
import 'station_ops_summary_screen.dart';
import '../admin/manual_archive_screen.dart';
import '../admin/registration_review_screen.dart';
import '../admin/station_assignment_screen.dart';
import '../reports/station_reports_hub_screen.dart';

/// Hub that opens station-scoped equipment faults and support incidents.
class StationOpsHubScreen extends StatelessWidget {
  const StationOpsHubScreen({
    super.key,
    required this.api,
    required this.stationId,
  });

  final MetraApiClient api;
  final String stationId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('عمليات المحطة'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        const Card(
          color: Color(0xFFEEF6FA),
          child: ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('نطاق المحطة المحددة فقط'),
            subtitle: Text(
              'كل البلاغات والتقارير أدناه تُطلب من الخادم بمعرّف المحطة. لا وصول عبر الواجهة إلى محطة أخرى.',
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.assessment_outlined),
            title: const Text('التقارير'),
            subtitle: const Text('حالة النشرات والأرشفة الإدارية — بدون مجاميع مخترعة'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => StationReportsHubScreen(
                    api: api,
                    stationId: stationId,
                  ),
                ),
              );
            },
          ),
        ),
Card(
          child: ListTile(
            leading: const Icon(Icons.analytics_outlined),
            title: const Text('ملخص التشغيل'),
            subtitle: const Text('أعداد النشرات والأعطال والدعم من الخادم فقط'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => StationOpsSummaryScreen(
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
            leading: const Icon(Icons.person_add_alt_1_outlined),
            title: const Text('مراجعة التسجيل'),
            subtitle: const Text('اعتماد أو رفض طلبات التسجيل ضمن المحطة'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => RegistrationReviewScreen(
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
            leading: const Icon(Icons.badge_outlined),
            title: const Text('تعيينات المحطة'),
            subtitle: const Text('طلب أدوار والمحطات وإدارتها عبر API'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => StationAssignmentScreen(
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
            leading: const Icon(Icons.build_circle_outlined),
            title: const Text('أعطال المعدات'),
            subtitle: const Text('تسجيل ومتابعة دورة حياة بلاغ العطل على الخادم'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => EquipmentFaultScreen(
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
            title: const Text('تأكيد أرشفة Excel'),
            subtitle: const Text('سجل إداري يدوي ضمن نطاق المحطة — بدون ترحيل أرصاد'),
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
            leading: const Icon(Icons.support_agent_outlined),
            title: const Text('بلاغات الدعم'),
            subtitle: const Text('تقنية المعلومات والاتصالات ضمن نطاق المحطة'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SupportIncidentScreen(
                    api: api,
                    stationId: stationId,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ),
    );
  }
}