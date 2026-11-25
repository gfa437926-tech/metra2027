import 'package:material_ui/material_ui.dart';

import '../../core/api/metra_api_client.dart';
import '../../core/auth/metra_access_context.dart';
import '../../core/drafts/observation_draft_store.dart';
import '../../core/errors/metra_error_presenter.dart';
import '../../core/widgets/metra_adaptive_navigation.dart';
import '../../core/widgets/metra_permission_denied_page.dart';
import '../observations/observation_workspace_screen.dart';
import '../stations/station_directory_screen.dart';
import '../forecast_centres/forecast_centre_screen.dart';
import '../admin/station_administration_screen.dart';
import '../workspaces/metra_workspaces.dart';
import '../settings/system_settings_screen.dart';

const _navy = Color(0xFF061B4A);
const _blue = Color(0xFF087CF0);

class _NavItem {
  const _NavItem({
    required this.id,
    required this.destination,
    required this.builder,
  });

  final MetraDestinationId id;
  final NavigationDestination destination;
  final Widget Function() builder;
}

class MetraHome extends StatefulWidget {
  const MetraHome({
    super.key,
    required this.api,
    this.onSignOut,
    this.userEmail,
    this.accessContextOverride,
  });

  final MetraApiClient api;
  final Future<void> Function()? onSignOut;
  final String? userEmail;

  /// Test-only: skip network load and use a fixed context.
  final MetraAccessContext? accessContextOverride;

  @override
  State<MetraHome> createState() => _MetraHomeState();
}

class _MetraHomeState extends State<MetraHome> {
  int _index = 0;
  String? _selectedStationId;
  MetraAccessContext _access = MetraAccessContext.unresolved();
  bool _loadingAccess = true;
  String? _accessError;

  @override
  void initState() {
    super.initState();
    if (widget.accessContextOverride != null) {
      _access = widget.accessContextOverride!;
      _loadingAccess = false;
    } else {
      _loadAccessContext();
    }
  }

  Future<void> _loadAccessContext() async {
    setState(() {
      _loadingAccess = true;
      _accessError = null;
    });
    try {
      final context = await widget.api.getAccessContext();
      if (!mounted) return;
      setState(() {
        _access = context;
        _loadingAccess = false;
        _index = 0;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _access = MetraAccessContext.unresolved();
        _loadingAccess = false;
        _accessError = MetraErrorPresenter.messageFor(error);
        _index = 0;
      });
    }
  }

  Widget _needStation(String title) => _InformationPage(
    icon: Icons.location_on_outlined,
    title: title,
    message: 'اختر محطة أولاً من دليل المحطات. يفرض الخادم صلاحيات حسابك على المحطة والعمليات.',
  );

  Widget _gateObservation() {
    if (_loadingAccess) {
      return const MetraPermissionDeniedPage(
        title: 'الصلاحيات',
        message: MetraPermissionDeniedMessages.contextLoading,
      );
    }
    if (!_access.isResolved) {
      return MetraPermissionDeniedPage(
        title: 'الصلاحيات غير متاحة',
        message:
            _accessError ?? MetraPermissionDeniedMessages.contextUnavailable,
      );
    }
    if (_selectedStationId == null) return _needStation('وحدة الرصد');
    final stationId = _selectedStationId!;
    if (!_access.canAccessObservationWorkspace(stationId)) {
      return const MetraPermissionDeniedPage(
        title: 'غير مصرح',
        message: MetraPermissionDeniedMessages.observations,
      );
    }
    return ObservationWorkspaceScreen(
      api: widget.api,
      stationId: stationId,
      accessContext: _access,
    );
  }

  Widget _gateAdmin() {
    if (_loadingAccess) {
      return const MetraPermissionDeniedPage(
        title: 'الصلاحيات',
        message: MetraPermissionDeniedMessages.contextLoading,
      );
    }
    if (!_access.isResolved) {
      return MetraPermissionDeniedPage(
        title: 'الصلاحيات غير متاحة',
        message:
            _accessError ?? MetraPermissionDeniedMessages.contextUnavailable,
      );
    }
    if (_selectedStationId == null) return _needStation('إدارة المحطة');
    final stationId = _selectedStationId!;
    if (!_access.canAdministerStation(stationId)) {
      return const MetraPermissionDeniedPage(
        title: 'غير مصرح',
        message: MetraPermissionDeniedMessages.administration,
      );
    }
    return StationAdministrationScreen(api: widget.api, stationId: stationId);
  }

  List<_NavItem> _buildNavItems() {
    // Visibility uses permission codes only. Placeholders stay visible because
    // they have no backend permission contract and show offline notices.
    final accessForNav = _loadingAccess
        ? MetraAccessContext.unresolved()
        : _access;

    final all = <_NavItem>[
      _NavItem(
        id: MetraDestinationId.home,
        destination: const NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'الرئيسية',
        ),
        builder: () => _HomeOverview(
          stationId: _selectedStationId,
          access: _access,
          loadingAccess: _loadingAccess,
          accessError: _accessError,
          onRetryAccess: _loadAccessContext,
          showObservationsShortcut:
              accessForNav.canAccessAnyObservationWorkspace,
          showAdminShortcut: accessForNav.canAccessAnyStationAdministration,
          onOpenStations: () => _selectDestination(MetraDestinationId.stations),
          onOpenObservations: () =>
              _selectDestination(MetraDestinationId.observations),
          onOpenAdmin: () => _selectDestination(MetraDestinationId.admin),
        ),
      ),
      _NavItem(
        id: MetraDestinationId.stations,
        destination: const NavigationDestination(
          icon: Icon(Icons.map_outlined),
          selectedIcon: Icon(Icons.map),
          label: 'المحطات',
        ),
        builder: () => StationDirectoryScreen(
          api: widget.api,
          selectedStationId: _selectedStationId,
          accessContext: _loadingAccess
              ? MetraAccessContext.unresolved()
              : _access,
          onStationSelected: (id) => setState(() {
            _selectedStationId = id;
            // Keep current index; page gates re-evaluate for the new station.
          }),
        ),
      ),
      _NavItem(
        id: MetraDestinationId.forecast,
        destination: const NavigationDestination(
          icon: Icon(Icons.query_stats_outlined),
          selectedIcon: Icon(Icons.query_stats),
          label: 'التنبؤ',
        ),
        builder: () => ForecastCentreScreen(api: widget.api),
      ),
      _NavItem(
        id: MetraDestinationId.observations,
        destination: const NavigationDestination(
          icon: Icon(Icons.fact_check_outlined),
          selectedIcon: Icon(Icons.fact_check),
          label: 'الرصد',
        ),
        builder: _gateObservation,
      ),
      _NavItem(
        id: MetraDestinationId.climatol,
        destination: const NavigationDestination(
          icon: Icon(Icons.science_outlined),
          selectedIcon: Icon(Icons.science),
          label: 'CLIMATOL',
        ),
        builder: () => _selectedStationId == null
            ? _needStation('CLIMATOL والتجانس المناخي')
            : ClimatolWorkspaceScreen(stationId: _selectedStationId!),
      ),
      _NavItem(
        id: MetraDestinationId.recordsAi,
        destination: const NavigationDestination(
          icon: Icon(Icons.image_search_outlined),
          selectedIcon: Icon(Icons.image_search),
          label: 'سجلات/AI',
        ),
        builder: () => _selectedStationId == null
            ? _needStation('السجلات المصورة والذكاء الاصطناعي')
            : RecordsAiWorkspaceScreen(stationId: _selectedStationId!),
      ),
      _NavItem(
        id: MetraDestinationId.operations,
        destination: const NavigationDestination(
          icon: Icon(Icons.build_outlined),
          selectedIcon: Icon(Icons.build),
          label: 'أجهزة',
        ),
        builder: () => _selectedStationId == null
            ? _needStation('الأجهزة والصيانة والشبكات')
            : OperationsWorkspaceScreen(stationId: _selectedStationId!),
      ),
      _NavItem(
        id: MetraDestinationId.reports,
        destination: const NavigationDestination(
          icon: Icon(Icons.analytics_outlined),
          selectedIcon: Icon(Icons.analytics),
          label: 'تقارير',
        ),
        builder: () => _selectedStationId == null
            ? _needStation('التقارير والإحصائيات')
            : ReportsWorkspaceScreen(stationId: _selectedStationId!),
      ),
      _NavItem(
        id: MetraDestinationId.admin,
        destination: const NavigationDestination(
          icon: Icon(Icons.admin_panel_settings_outlined),
          selectedIcon: Icon(Icons.admin_panel_settings),
          label: 'إدارة',
        ),
        builder: _gateAdmin,
      ),
      _NavItem(
        id: MetraDestinationId.settings,
        destination: const NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: 'إعدادات',
        ),
        builder: () => SystemSettingsScreen(
          userEmail: widget.userEmail,
          onSignOut: widget.onSignOut,
          api: widget.api,
        ),
      ),
    ];

    return all
        .where((item) => accessForNav.isDestinationVisible(item.id))
        .toList(growable: false);
  }

  void _selectDestination(MetraDestinationId id) {
    final items = _buildNavItems();
    final index = items.indexWhere((item) => item.id == id);
    if (index < 0) return;
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final items = _buildNavItems();
    final safeIndex = _index.clamp(0, items.isEmpty ? 0 : items.length - 1);
    if (safeIndex != _index) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _index = safeIndex);
      });
    }

    final pages = items.map((item) => item.builder()).toList(growable: false);
    final destinations = items
        .map((item) => item.destination)
        .toList(growable: false);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: _navy,
          foregroundColor: Colors.white,
          title: const Text('METRA 2027 — منظومة الأرصاد'),
          actions: [
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 12),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Text(
                    _selectedStationId == null
                        ? 'منصة الأرصاد'
                        : 'محطة: $_selectedStationId',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: MetraAdaptiveNavigation(
          selectedIndex: safeIndex,
          onDestinationSelected: (value) => setState(() => _index = value),
          destinations: destinations,
          child: IndexedStack(index: safeIndex, children: pages),
        ),
      ),
    );
  }
}

class _HomeOverview extends StatelessWidget {
  const _HomeOverview({
    required this.stationId,
    required this.access,
    required this.loadingAccess,
    required this.accessError,
    required this.onRetryAccess,
    required this.showObservationsShortcut,
    required this.showAdminShortcut,
    required this.onOpenStations,
    required this.onOpenObservations,
    required this.onOpenAdmin,
  });

  final String? stationId;
  final MetraAccessContext access;
  final bool loadingAccess;
  final String? accessError;
  final VoidCallback onRetryAccess;
  final bool showObservationsShortcut;
  final bool showAdminShortcut;
  final VoidCallback onOpenStations;
  final VoidCallback onOpenObservations;
  final VoidCallback onOpenAdmin;

  @override
  Widget build(BuildContext context) {
    final canObsOnStation =
        stationId != null &&
        access.isResolved &&
        access.canAccessObservationWorkspace(stationId!);
    final canAdminOnStation =
        stationId != null &&
        access.isResolved &&
        access.canAdministerStation(stationId!);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Material(
        color: Colors.transparent,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'لوحة التشغيل',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(color: _navy, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              stationId == null
                  ? 'ابدأ باختيار محطة من الدليل. تُفرض صلاحيات الرصد والمراجعة على الخادم.'
                  : 'المحطة النشطة: $stationId',
              style: const TextStyle(color: Color(0xFF475569), height: 1.5),
            ),
            const SizedBox(height: 12),
            if (loadingAccess)
              const Card(
                elevation: 0,
                child: ListTile(
                  leading: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  title: Text(MetraPermissionDeniedMessages.contextLoading),
                ),
              )
            else if (!access.isResolved)
              Card(
                elevation: 0,
                color: const Color(0xFFFFF7E8),
                child: ListTile(
                  leading: const Icon(Icons.warning_amber_outlined),
                  title: const Text('سياق الصلاحيات غير متاح'),
                  subtitle: Text(
                    accessError ??
                        MetraPermissionDeniedMessages.contextUnavailable,
                  ),
                  trailing: TextButton(
                    onPressed: onRetryAccess,
                    child: const Text('إعادة'),
                  ),
                ),
              )
            else
              Card(
                elevation: 0,
                child: ListTile(
                  leading: const Icon(
                    Icons.verified_user_outlined,
                    color: _blue,
                  ),
                  title: const Text('سياق الصلاحيات محمّل من الخادم'),
                  subtitle: Text(
                    'محطات بصلاحيات مؤكدة: ${access.stationPermissions.length}',
                  ),
                ),
              ),
            if (stationId != null && stationId!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              _StationDraftSummaryCard(
                stationId: stationId!,
                onOpenObservations: showObservationsShortcut
                    ? onOpenObservations
                    : null,
              ),
            ],
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
                if (showObservationsShortcut)
                  _ActionCard(
                    icon: Icons.fact_check_outlined,
                    title: 'وحدة الرصد',
                    subtitle: stationId == null
                        ? 'يتطلب اختيار محطة'
                        : (canObsOnStation
                              ? 'ساعي · يومي · ظاهرة'
                              : 'غير مصرح لهذه المحطة'),
                    onTap: onOpenObservations,
                  ),
                if (showAdminShortcut)
                  _ActionCard(
                    icon: Icons.admin_panel_settings_outlined,
                    title: 'إدارة المحطة',
                    subtitle: stationId == null
                        ? 'يتطلب اختيار محطة'
                        : (canAdminOnStation
                              ? 'مستخدمون · تسجيلات'
                              : 'غير مصرح لهذه المحطة'),
                    onTap: onOpenAdmin,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const _StatusCard(
              title: 'حالة الربط المعتمدة',
              body:
                  'المتصل بالخادم: الرصد الساعي واليومي والظواهر ومراجعة الأرصاد وAccess Context. '
                  'عناصر التنقل التشغيلية تُخفى عند غياب صلاحيات الخادم. '
                  'بقية النماذج للتحقق المحلي فقط حتى اعتماد عقود API.',
            ),
            const SizedBox(height: 12),
            const _StatusCard(
              title: 'ملخص الأعمال اليومية',
              body:
                  'اختر محطة مصرّحاً بها ثم انتقل إلى وحدة الرصد لإدخال الساعي/اليومي/الظواهر. '
                  'نماذج الأمطار والتربة والزراعي والمناخي الساعي والأعطال متاحة للتحقق المحلي والمسودات فقط '
                  'حتى موافقة قاعدة البيانات والعقود (U1 وما يليها).',
            ),
            const SizedBox(height: 12),
            const _StatusCard(
              title: 'تنبيه بيانات',
              body:
                  'لا تُعرض أرقام رصد أو إحصاءات علمية وهمية في لوحة التحكم. '
                  'المؤشرات الرقمية تظهر فقط من مصادر API معتمدة.',
            ),
          ],
        ),
      ),
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
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(height: 1.5),
          ),
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
          Text(
            body,
            style: const TextStyle(height: 1.55, color: Color(0xFF334155)),
          ),
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
              Text(
                subtitle,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Live session-draft summary for the selected station (local only).
class _StationDraftSummaryCard extends StatefulWidget {
  const _StationDraftSummaryCard({
    required this.stationId,
    this.onOpenObservations,
  });

  final String stationId;
  final VoidCallback? onOpenObservations;

  @override
  State<_StationDraftSummaryCard> createState() =>
      _StationDraftSummaryCardState();
}

class _StationDraftSummaryCardState extends State<_StationDraftSummaryCard> {
  @override
  void initState() {
    super.initState();
    ObservationDraftStore.instance.addListener(_onChange);
  }

  @override
  void dispose() {
    ObservationDraftStore.instance.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final types = ObservationDraftStore.instance.formTypesWithDrafts(
      widget.stationId,
    );
    if (types.isEmpty) {
      return const SizedBox.shrink();
    }
    final labels = types.toList()..sort();
    return Card(
      elevation: 0,
      color: const Color(0xFFE8F4FF),
      child: ListTile(
        leading: const Icon(Icons.edit_note, color: _blue),
        title: Text('مسودات محلية: ${types.length} نموذج'),
        subtitle: Text(
          'جلسة فقط — لم تُرسل إلى الخادم · ${labels.join(' · ')}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: widget.onOpenObservations == null
            ? null
            : TextButton(
                onPressed: widget.onOpenObservations,
                child: const Text('الرصد'),
              ),
      ),
    );
  }
}
