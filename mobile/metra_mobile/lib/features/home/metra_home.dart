// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import '../../core/api/metra_api_client.dart';
import '../../core/widgets/metra_adaptive_navigation.dart';
import '../../core/widgets/metra_ui.dart';
import '../admin/user_management_screen.dart';
import '../ai/ai_workspace_screen.dart';
import '../audit/electronic_audit_screen.dart';
import '../climatol/climatol_workspace_screen.dart';
import '../forecast_centres/forecast_centre_screen.dart';
import '../observations/daily_observation_entry_screen.dart';
import '../observations/hourly_observation_entry_screen.dart';
import '../observations/observation_review_screen.dart';
import '../reports/observation_archive_screen.dart';
import '../reports/reports_hub_screen.dart';
import '../stations/station_audit_log_screen.dart';
import '../stations/station_directory_screen.dart';

const _navy = Color(0xFF061B4A);

class MetraHome extends StatefulWidget {
  const MetraHome({
    super.key,
    required this.api,
    this.onSignOut,
    this.userEmail,
  });

  final MetraApiClient api;
  final Future<void> Function()? onSignOut;
  final String? userEmail;

  @override
  State<MetraHome> createState() => _MetraHomeState();
}

class _MetraHomeState extends State<MetraHome> {
  int _index = 0;
  String? _selectedStationId;

  void _open(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      // 0 Home
      _HomeOverview(
        userEmail: widget.userEmail,
        onOpenStations: () => _open(1),
        onOpenHourly: () => _open(3),
        onOpenDaily: () => _open(4),
        onOpenReview: () => _open(5),
        onOpenReports: () => _open(7),
        onOpenAudit: () => _open(6),
        onOpenForecast: () => _open(2),
        onOpenAi: () => _open(8),
        onOpenClimatol: () => _open(9),
        onOpenAdmin: () => _open(10),
      ),
      // 1 Stations
      StationDirectoryScreen(
        api: widget.api,
        selectedStationId: _selectedStationId,
        onStationSelected: (id) => setState(() => _selectedStationId = id),
      ),
      // 2 Forecast
      ForecastCentreScreen(api: widget.api),
      // 3 Hourly entry
      HourlyObservationEntryScreen(
        api: widget.api,
        stationId: _selectedStationId,
      ),
      // 4 Daily entry
      DailyObservationEntryScreen(
        api: widget.api,
        stationId: _selectedStationId,
      ),
      // 5 Observation review
      _selectedStationId == null
          ? const MetraEmptyState(
              icon: Icons.fact_check_outlined,
              title: 'مراجعة الرصدات',
              message:
                  'اختر محطة أولاً من دليل المحطات. سيطبّق الخادم صلاحيات حسابك على المحطة والعمليات المتاحة.',
            )
          : ObservationReviewScreen(
              api: widget.api,
              stationId: _selectedStationId!,
            ),
      // 6 Electronic audit + station audit entry
      ElectronicAuditScreen(
        api: widget.api,
        stationId: _selectedStationId,
      ),
      // 7 Reports hub
      ReportsHubScreen(
        onOpenArchive: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ObservationArchiveScreen(
                api: widget.api,
                stationId: _selectedStationId,
              ),
            ),
          );
        },
      ),
      // 8 AI
      const AiWorkspaceScreen(),
      // 9 Climatol
      const ClimatolWorkspaceScreen(),
      // 10 Admin / users
      UserManagementScreen(
        api: widget.api,
        stationId: _selectedStationId,
      ),
      // 11 Settings
      _SettingsPage(
        userEmail: widget.userEmail,
        onSignOut: widget.onSignOut,
        selectedStationId: _selectedStationId,
        onOpenStationAudit: () {
          if (_selectedStationId == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('اختر محطة أولاً من دليل المحطات لعرض سجل تدقيق المحطة.'),
              ),
            );
            return;
          }
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => StationAuditLogScreen(
                api: widget.api,
                stationId: _selectedStationId!,
              ),
            ),
          );
        },
      ),
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: _navy,
          foregroundColor: Colors.white,
          title: const Text('METRA 2027'),
          actions: [
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 16),
              child: Center(
                child: Text(
                  'منصة الأرصاد',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: MetraAdaptiveNavigation(
          selectedIndex: _index.clamp(0, 11),
          onDestinationSelected: (value) => setState(() => _index = value),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'الرئيسية',
            ),
            NavigationDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map),
              label: 'المحطات',
            ),
            NavigationDestination(
              icon: Icon(Icons.query_stats_outlined),
              selectedIcon: Icon(Icons.query_stats),
              label: 'التنبؤ',
            ),
            NavigationDestination(
              icon: Icon(Icons.thermostat_outlined),
              selectedIcon: Icon(Icons.thermostat),
              label: 'ساعي',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_today_outlined),
              selectedIcon: Icon(Icons.calendar_today),
              label: 'يومي',
            ),
            NavigationDestination(
              icon: Icon(Icons.fact_check_outlined),
              selectedIcon: Icon(Icons.fact_check),
              label: 'مراجعة',
            ),
            NavigationDestination(
              icon: Icon(Icons.shield_outlined),
              selectedIcon: Icon(Icons.shield),
              label: 'تدقيق',
            ),
            NavigationDestination(
              icon: Icon(Icons.analytics_outlined),
              selectedIcon: Icon(Icons.analytics),
              label: 'تقارير',
            ),
            NavigationDestination(
              icon: Icon(Icons.psychology_outlined),
              selectedIcon: Icon(Icons.psychology),
              label: 'ذكاء',
            ),
            NavigationDestination(
              icon: Icon(Icons.timeline),
              selectedIcon: Icon(Icons.timeline),
              label: 'مناخي',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people),
              label: 'مستخدمون',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'إعدادات',
            ),
          ],
          child: IndexedStack(index: _index.clamp(0, 11), children: pages),
        ),
      ),
    );
  }
}

class _HomeOverview extends StatelessWidget {
  const _HomeOverview({
    required this.onOpenStations,
    required this.onOpenHourly,
    required this.onOpenDaily,
    required this.onOpenReview,
    required this.onOpenReports,
    required this.onOpenAudit,
    required this.onOpenForecast,
    required this.onOpenAi,
    required this.onOpenClimatol,
    required this.onOpenAdmin,
    this.userEmail,
  });

  final VoidCallback onOpenStations;
  final VoidCallback onOpenHourly;
  final VoidCallback onOpenDaily;
  final VoidCallback onOpenReview;
  final VoidCallback onOpenReports;
  final VoidCallback onOpenAudit;
  final VoidCallback onOpenForecast;
  final VoidCallback onOpenAi;
  final VoidCallback onOpenClimatol;
  final VoidCallback onOpenAdmin;
  final String? userEmail;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0xFF061746), Color(0xFF0754B5)],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.cloud_outlined, color: Colors.white, size: 38),
              const SizedBox(height: 16),
              const Text(
                'ذكاء الأرصاد يبدأ من بيانات موثوقة',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                userEmail == null
                    ? 'واجهة METRA 2027'
                    : 'مرحباً، $userEmail',
                style: const TextStyle(color: Color(0xFFD6E8FF)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const MetraStatusBanner(
          tone: MetraBannerTone.info,
          message:
              'لن تُعرض درجات حرارة أو رياح أو نتائج تحليل تجريبية على أنها قياسات أو توصيات فعلية. البيانات الحقيقية تظهر فقط من المصادر المعتمدة.',
        ),
        const SizedBox(height: 14),
        const Text(
          'العمليات الأساسية',
          style: TextStyle(
            color: metraNavy,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        _ActionCard(
          icon: Icons.map_outlined,
          title: 'دليل المحطات',
          description: 'استعراض المحطات المعتمدة، الموقع، الإحداثيات والحالة.',
          onTap: onOpenStations,
        ),
        _ActionCard(
          icon: Icons.thermostat_outlined,
          title: 'إدخال الرصد الساعي',
          description: 'نموذج الإدخال الساعي مع مجموعات الحقول التشغيلية.',
          onTap: onOpenHourly,
        ),
        _ActionCard(
          icon: Icons.calendar_today_outlined,
          title: 'إدخال الرصد اليومي',
          description: 'نموذج الإدخال اليومي الحقيقي (وليس شاشة التقارير).',
          onTap: onOpenDaily,
        ),
        _ActionCard(
          icon: Icons.fact_check_outlined,
          title: 'مراجعة واعتماد الرصدات',
          description: 'قائمة الرصدات والقرارات وسجل المراجعة.',
          onTap: onOpenReview,
        ),
        const SizedBox(height: 12),
        const Text(
          'التقارير والتدقيق والتحليل',
          style: TextStyle(
            color: metraNavy,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        _ActionCard(
          icon: Icons.analytics_outlined,
          title: 'مركز التقارير والأرشيف',
          description: 'التقارير والأرشيف المحمي بصلاحية صريحة.',
          onTap: onOpenReports,
        ),
        _ActionCard(
          icon: Icons.shield_outlined,
          title: 'التدقيق الإلكتروني',
          description: 'سجلات مدققة محمية من التعديل والحذف من الواجهة.',
          onTap: onOpenAudit,
        ),
        _ActionCard(
          icon: Icons.query_stats_outlined,
          title: 'مراكز التنبؤ',
          description: 'مقارنة المحطات والمنتجات عند توفر العقود.',
          onTap: onOpenForecast,
        ),
        _ActionCard(
          icon: Icons.psychology_outlined,
          title: 'الذكاء الاصطناعي',
          description: 'واجهة الاستفسارات والنتائج مع حالات تعذر الخدمة.',
          onTap: onOpenAi,
        ),
        _ActionCard(
          icon: Icons.timeline,
          title: 'Climatol والتجانس',
          description: 'إعداد ومراقبة وظائف التجانس المناخي.',
          onTap: onOpenClimatol,
        ),
        _ActionCard(
          icon: Icons.people_outline,
          title: 'إدارة المستخدمين',
          description: 'الحسابات، التسجيل، الأدوار وتعيين المحطات.',
          onTap: onOpenAdmin,
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Icon(icon, color: metraBlue, size: 28),
          title: Text(
            title,
            style: const TextStyle(
              color: metraNavy,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(description),
          trailing: const Icon(Icons.chevron_left),
          onTap: onTap,
        ),
      ),
    );
  }
}

class _SettingsPage extends StatelessWidget {
  const _SettingsPage({
    required this.userEmail,
    required this.onSignOut,
    required this.selectedStationId,
    required this.onOpenStationAudit,
  });

  final String? userEmail;
  final Future<void> Function()? onSignOut;
  final String? selectedStationId;
  final VoidCallback onOpenStationAudit;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const MetraPageHeader(
          title: 'الإعدادات',
          subtitle: 'إعدادات الحساب والعرض والإشعارات والمساعدة.',
        ),
        const SizedBox(height: 8),
        MetraSectionCard(
          title: 'الحساب',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'الحساب: ${userEmail ?? 'مستخدم مسجل'}',
                style: const TextStyle(color: metraMuted),
              ),
              const SizedBox(height: 6),
              const Text(
                'الجلسة تُحفظ وتُجدَّد بواسطة Supabase Auth.',
                style: TextStyle(color: metraMuted),
              ),
              const SizedBox(height: 12),
              if (onSignOut != null)
                FilledButton.tonalIcon(
                  onPressed: onSignOut,
                  icon: const Icon(Icons.logout),
                  label: const Text('تسجيل الخروج'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        MetraSectionCard(
          title: 'سجل تدقيق المحطة',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                selectedStationId == null
                    ? 'لم تُحدد محطة بعد.'
                    : 'المحطة المحددة: $selectedStationId',
                style: const TextStyle(color: metraMuted),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: onOpenStationAudit,
                icon: const Icon(Icons.history),
                label: const Text('فتح سجل تدقيق المحطة'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const MetraSectionCard(
          title: 'اللغة والعرض',
          child: Text(
            'الواجهة عربية بالكامل (RTL). ثيم METRA الموحّد مفعّل على جميع الشاشات.',
            style: TextStyle(color: metraMuted, height: 1.5),
          ),
        ),
        const SizedBox(height: 12),
        const MetraSectionCard(
          title: 'المساعدة ومعلومات التطبيق',
          child: Text(
            'METRA 2027 — تطبيق الأرصاد الوطني.\nالإصدار وفق pubspec.yaml في mobile/metra_mobile.',
            style: TextStyle(color: metraMuted, height: 1.5),
          ),
        ),
      ],
    );
  }
}
