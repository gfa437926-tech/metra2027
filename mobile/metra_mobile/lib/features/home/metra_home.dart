import 'package:material_ui/material_ui.dart';
import '../../core/api/metra_api_client.dart';
import '../../core/widgets/metra_adaptive_navigation.dart';
import '../observations/observation_workspace_screen.dart';
import '../stations/station_directory_screen.dart';
import '../forecast_centres/forecast_centre_screen.dart';
import '../admin/station_administration_screen.dart';
import '../workspaces/metra_workspaces.dart';

const _navy = Color(0xFF061B4A);
const _blue = Color(0xFF087CF0);

class MetraHome extends StatefulWidget {
  const MetraHome({super.key, required this.api, this.onSignOut, this.userEmail});
  final MetraApiClient api;
  final Future<void> Function()? onSignOut;
  final String? userEmail;
  @override
  State<MetraHome> createState() => _MetraHomeState();
}

class _MetraHomeState extends State<MetraHome> {
  int _index = 0;
  String? _selectedStationId;

  Widget _needStation(String title) => _InformationPage(
        icon: Icons.location_on_outlined,
        title: title,
        message:
            'اختر محطة أولاً من دليل المحطات. يفرض الخادم صلاحيات حسابك على المحطة والعمليات.',
      );

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _HomeOverview(
        stationId: _selectedStationId,
        onOpenStations: () => setState(() => _index = 1),
        onOpenObservations: () => setState(() => _index = 3),
      ),
      StationDirectoryScreen(
        api: widget.api,
        selectedStationId: _selectedStationId,
        onStationSelected: (id) => setState(() => _selectedStationId = id),
      ),
      ForecastCentreScreen(api: widget.api),
      _selectedStationId == null
          ? _needStation('وحدة الرصد')
          : ObservationWorkspaceScreen(
              api: widget.api,
              stationId: _selectedStationId!,
            ),
      _selectedStationId == null
          ? _needStation('CLIMATOL والتجانس المناخي')
          : ClimatolWorkspaceScreen(stationId: _selectedStationId!),
      _selectedStationId == null
          ? _needStation('السجلات المصورة والذكاء الاصطناعي')
          : RecordsAiWorkspaceScreen(stationId: _selectedStationId!),
      _selectedStationId == null
          ? _needStation('الأجهزة والصيانة والشبكات')
          : OperationsWorkspaceScreen(stationId: _selectedStationId!),
      _selectedStationId == null
          ? _needStation('التقارير والإحصائيات')
          : ReportsWorkspaceScreen(stationId: _selectedStationId!),
      _selectedStationId == null
          ? _needStation('إدارة المحطة')
          : StationAdministrationScreen(api: widget.api, stationId: _selectedStationId!),
      _InformationPage(
        icon: Icons.settings_outlined,
        title: 'إعدادات الحساب',
        message:
            'الحساب: ${widget.userEmail ?? 'مستخدم مسجل'}\nالجلسة تُحفظ وتُجدد عبر Supabase Auth. لا تُخزَّن مفاتيح service-role في التطبيق.',
        action: widget.onSignOut == null
            ? null
            : FilledButton.tonalIcon(
                onPressed: widget.onSignOut,
                icon: const Icon(Icons.logout),
                label: const Text('تسجيل الخروج'),
              ),
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
                  _selectedStationId == null
                      ? 'منصة الأرصاد'
                      : 'محطة: $_selectedStationId',
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
          selectedIndex: _index,
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
              icon: Icon(Icons.fact_check_outlined),
              selectedIcon: Icon(Icons.fact_check),
              label: 'الرصد',
            ),
            NavigationDestination(
              icon: Icon(Icons.science_outlined),
              selectedIcon: Icon(Icons.science),
              label: 'CLIMATOL',
            ),
            NavigationDestination(
              icon: Icon(Icons.image_search_outlined),
              selectedIcon: Icon(Icons.image_search),
              label: 'سجلات/AI',
            ),
            NavigationDestination(
              icon: Icon(Icons.build_outlined),
              selectedIcon: Icon(Icons.build),
              label: 'أجهزة',
            ),
            NavigationDestination(
              icon: Icon(Icons.analytics_outlined),
              selectedIcon: Icon(Icons.analytics),
              label: 'تقارير',
            ),
            NavigationDestination(
              icon: Icon(Icons.admin_panel_settings_outlined),
              selectedIcon: Icon(Icons.admin_panel_settings),
              label: 'إدارة',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'إعدادات',
            ),
          ],
          child: IndexedStack(index: _index, children: pages),
        ),
      ),
    );
  }
}

class _HomeOverview extends StatelessWidget {
  const _HomeOverview({
    required this.onOpenStations,
    required this.onOpenObservations,
    this.stationId,
  });
  final VoidCallback onOpenStations;
  final VoidCallback onOpenObservations;
  final String? stationId;

  @override
  Widget build(BuildContext context) => ListView(
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
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  stationId == null
                      ? 'اختر محطة من الدليل لبدء الرصد والمراجعة'
                      : 'المحطة النشطة: $stationId',
                  style: const TextStyle(color: Color(0xFFD6E8FF)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const _StatusCard(
            icon: Icons.cloud_off_outlined,
            title: 'الطقس المباشر غير متصل',
            description:
                'لن تُعرض درجات حرارة أو رياح تجريبية على أنها قياسات فعلية.',
          ),
          const SizedBox(height: 12),
          _ActionCard(
            icon: Icons.map_outlined,
            title: 'استعراض المحطات',
            description: 'الدليل المعتمد من واجهة المحطات على الخادم.',
            onTap: onOpenStations,
          ),
          const SizedBox(height: 12),
          _ActionCard(
            icon: Icons.edit_note_outlined,
            title: 'إدخال ومراجعة الرصد',
            description:
                'نماذج ساعي/يومي من كتالوج الحقول المعتمد، مع إرسال عبر API الحالي.',
            onTap: onOpenObservations,
          ),
        ],
      );
}

class _InformationPage extends StatelessWidget {
  const _InformationPage({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: _StatusCard(
              icon: icon,
              title: title,
              description: message,
              action: action,
            ),
          ),
        ),
      );
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.icon,
    required this.title,
    required this.description,
    this.action,
  });
  final IconData icon;
  final String title;
  final String description;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: _blue, size: 30),
              const SizedBox(height: 12),
              Text(title,
                  style: const TextStyle(
                      color: _navy, fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(description,
                  style:
                      const TextStyle(color: Color(0xFF64748B), height: 1.6)),
              if (action != null) ...[const SizedBox(height: 16), action!],
            ],
          ),
        ),
      );
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
  Widget build(BuildContext context) => Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          leading: Icon(icon, color: _blue, size: 28),
          title: Text(title,
              style:
                  const TextStyle(color: _navy, fontWeight: FontWeight.bold)),
          subtitle: Text(description),
          trailing: const Icon(Icons.chevron_left),
          onTap: onTap,
        ),
      );
}
