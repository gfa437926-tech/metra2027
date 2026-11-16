import 'package:material_ui/material_ui.dart';
import '../../core/api/metra_api_client.dart';
import '../../core/widgets/metra_adaptive_navigation.dart';
import '../observations/observation_workspace_screen.dart';
import '../stations/station_directory_screen.dart';
import '../forecast_centres/forecast_centre_screen.dart';
import '../admin/station_administration_screen.dart';
import '../workspaces/metra_workspaces.dart';
import '../settings/system_settings_screen.dart';

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
      SystemSettingsScreen(
        userEmail: widget.userEmail,
        onSignOut: widget.onSignOut,
      ),
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: _navy,
          foregroundColor: Colors.white,
          title: const Text('METRA 2027 — منظومة الأرصاد'),
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
    required this.stationId,
    required this.onOpenStations,
    required this.onOpenObservations,
  });
  final String? stationId;
  final VoidCallback onOpenStations;
  final VoidCallback onOpenObservations;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('لوحة التشغيل',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(color: _navy, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
          stationId == null
              ? 'ابدأ باختيار محطة من الدليل. تُفرض صلاحيات الرصد والمراجعة على الخادم.'
              : 'المحطة النشطة: $stationId',
          style: const TextStyle(color: Color(0xFF475569), height: 1.5),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _ActionCard(
              icon: Icons.map_outlined,
              title: 'دليل المحطات',
              subtitle: 'اختيار محطة العمل',
              onTap: onOpenStations,
            ),
            _ActionCard(
              icon: Icons.fact_check_outlined,
              title: 'وحدة الرصد',
              subtitle:
                  stationId == null ? 'يتطلب اختيار محطة' : 'ساعي · يومي · ظاهرة',
              onTap: onOpenObservations,
            ),
          ],
        ),
        const SizedBox(height: 16),
        const _StatusCard(
          title: 'حالة الربط المعتمدة',
          body:
              'المتصل بالخادم: الرصد الساعي واليومي والظواهر ومراجعة الأرصاد. '
              'بقية النماذج للتحقق المحلي فقط حتى اعتماد عقود API.',
        ),
      ],
    );
  }
}

class _InformationPage extends StatelessWidget {
  const _InformationPage({
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: _blue),
              const SizedBox(height: 12),
              Text(title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 8),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(height: 1.5)),
            ],
          ),
        ),
      );
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(body, style: const TextStyle(height: 1.55, color: Color(0xFF334155))),
            ],
          ),
        ),
      );
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 220,
        child: Card(
          elevation: 0,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: _blue),
                  const SizedBox(height: 10),
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: const TextStyle(
                          color: Color(0xFF64748B), fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
      );
}
