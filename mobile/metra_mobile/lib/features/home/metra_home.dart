import 'package:flutter/material.dart';
import '../../core/api/metra_api_client.dart';
import 'registration_access_screen.dart';
import '../observations/observation_entry_screen.dart';
import '../observations/observation_review_screen.dart';
import '../stations/station_directory_screen.dart';

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

  void _openObservationWorkspace([String? stationId]) {
    setState(() {
      if (stationId != null) _selectedStationId = stationId;
      _index = 2;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _HomeOverview(
        onOpenStations: () => setState(() => _index = 1),
        onOpenObservations: () => _openObservationWorkspace(),
      ),
      StationDirectoryScreen(
        api: widget.api,
        selectedStationId: _selectedStationId,
        onStationSelected: _openObservationWorkspace,
      ),
      _ObservationWorkspace(
        api: widget.api,
        selectedStationId: _selectedStationId,
        onStationChanged: (value) => setState(() => _selectedStationId = value),
      ),
      const _InformationPage(
        icon: Icons.analytics_outlined,
        title: 'التقارير والتحليلات',
        message: 'التقارير التشغيلية غير مفعلة حتى ربط مصدر موثق للرصدات المعتمدة.',
      ),
      _InformationPage(
        icon: Icons.settings_outlined,
        title: 'إعدادات الحساب',
        message: 'الحساب: ${widget.userEmail ?? 'مستخدم مسجل'}\nالجلسة تحفظ وتُجدد بواسطة Supabase Auth.',
        action: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => RegistrationAccessScreen(api: widget.api),
              )),
              icon: const Icon(Icons.assignment_ind_outlined),
              label: const Text('التسجيل وحالة الحساب'),
            ),
            if (widget.onSignOut != null) ...[
              const SizedBox(height: 10),
              FilledButton.tonalIcon(
                onPressed: widget.onSignOut,
                icon: const Icon(Icons.logout),
                label: const Text('تسجيل الخروج'),
              ),
            ],
          ],
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
                  'منصة الأرصاد',
                  style: TextStyle(color: Colors.white.withValues(alpha: .78), fontSize: 12),
                ),
              ),
            ),
          ],
        ),
        body: IndexedStack(index: _index, children: pages),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (value) => setState(() => _index = value),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'الرئيسية'),
            NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'المحطات'),
            NavigationDestination(icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment), label: 'الرصد'),
            NavigationDestination(icon: Icon(Icons.analytics_outlined), selectedIcon: Icon(Icons.analytics), label: 'التقارير'),
            NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'الإعدادات'),
          ],
        ),
      ),
    );
  }
}

class _ObservationWorkspace extends StatefulWidget {
  const _ObservationWorkspace({
    required this.api,
    required this.selectedStationId,
    required this.onStationChanged,
  });

  final MetraApiClient api;
  final String? selectedStationId;
  final ValueChanged<String?> onStationChanged;

  @override
  State<_ObservationWorkspace> createState() => _ObservationWorkspaceState();
}

class _ObservationWorkspaceState extends State<_ObservationWorkspace> {
  late Future<List<StationDirectoryItem>> _stations;

  @override
  void initState() {
    super.initState();
    _stations = widget.api.getAllStationDirectory();
  }

  Future<void> _refreshStations() async {
    setState(() => _stations = widget.api.getAllStationDirectory());
    await _stations;
  }

  Future<void> _openEntry(String stationId) async {
    await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => ObservationEntryScreen(api: widget.api, stationId: stationId),
    ));
  }

  Future<void> _openReview(String stationId) async {
    await Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => ObservationReviewScreen(api: widget.api, stationId: stationId),
    ));
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<StationDirectoryItem>>(
    future: _stations,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_outlined, size: 42),
                const SizedBox(height: 12),
                const Text('تعذر تحميل المحطات اللازمة لبدء العمل.'),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _refreshStations,
                  icon: const Icon(Icons.refresh),
                  label: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          ),
        );
      }

      final stations = (snapshot.data ?? const <StationDirectoryItem>[])
          .where((station) =>
              station.approvalStatus == 'approved' &&
              station.operationalStatus == 'active' &&
              !station.isDemo)
          .toList(growable: false);
      final selectedId = stations.any((s) => s.id == widget.selectedStationId)
          ? widget.selectedStationId
          : (stations.isEmpty ? null : stations.first.id);
      final selected = selectedId == null ? null : stations.firstWhere((s) => s.id == selectedId);

      return ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Text('مركز أعمال الرصد',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _navy)),
          const SizedBox(height: 6),
          const Text('اختر المحطة أولاً، ثم انتقل إلى واجهة الإدخال أو المراجعة المرتبطة بها.'),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('المحطة النشطة', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  if (stations.isEmpty)
                    const Text('لا توجد محطات معتمدة ونشطة متاحة حالياً.')
                  else
                    DropdownButtonFormField<String>(
                      initialValue: selectedId,
                      isExpanded: true,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                      items: stations.map((station) => DropdownMenuItem(
                        value: station.id,
                        child: Text('${station.nameArabic} — ${station.localCode}',
                          overflow: TextOverflow.ellipsis),
                      )).toList(),
                      onChanged: widget.onStationChanged,
                    ),
                  if (selected != null) ...[
                    const SizedBox(height: 8),
                    Text('نوع المحطة: ${selected.stationType}'),
                    Text('رمز المحطة: ${selected.localCode}'),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _WorkflowCard(
            icon: Icons.edit_note,
            title: 'إدخال الرصد',
            description: 'فتح نموذج إدخال الرصد للمحطة المحددة.',
            buttonLabel: 'فتح واجهة الإدخال',
            onPressed: selectedId == null ? null : () => _openEntry(selectedId),
          ),
          const SizedBox(height: 12),
          _WorkflowCard(
            icon: Icons.fact_check_outlined,
            title: 'مراجعة النشرات',
            description: 'استعراض قائمة النشرات وتنفيذ القرار إذا كانت صلاحيات الحساب تسمح بذلك.',
            buttonLabel: 'فتح واجهة المراجعة',
            onPressed: selectedId == null ? null : () => _openReview(selectedId),
          ),
          const SizedBox(height: 12),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'تنبيه الصلاحيات: اختيار المحطة هنا للتنقل فقط. الخادم هو المرجع النهائي لتحديد المحطات والسجلات والقرارات المسموح بها، وقد يرفض العملية إذا لم يكن الحساب مخولاً.',
                style: TextStyle(fontSize: 12, height: 1.5, color: Colors.black54),
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _WorkflowCard extends StatelessWidget {
  const _WorkflowCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String description;
  final String buttonLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    color: Colors.white,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Icon(icon, color: _blue, size: 28),
            const SizedBox(width: 10),
            Expanded(child: Text(title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _navy))),
          ]),
          const SizedBox(height: 8),
          Text(description, style: const TextStyle(color: Color(0xFF64748B), height: 1.5)),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.arrow_forward),
            label: Text(buttonLabel),
          ),
        ],
      ),
    ),
  );
}

class _HomeOverview extends StatelessWidget {
  const _HomeOverview({required this.onOpenStations, required this.onOpenObservations});
  final VoidCallback onOpenStations;
  final VoidCallback onOpenObservations;

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
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.cloud_outlined, color: Colors.white, size: 38),
            SizedBox(height: 16),
            Text('ذكاء الأرصاد يبدأ من بيانات موثوقة',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('واجهة METRA 2027', style: TextStyle(color: Color(0xFFD6E8FF))),
          ],
        ),
      ),
      const SizedBox(height: 18),
      const _StatusCard(
        icon: Icons.cloud_off_outlined,
        title: 'الطقس المباشر غير متصل',
        description: 'لن تُعرض درجات حرارة أو رياح تجريبية على أنها قياسات فعلية. ستظهر البيانات عند ربط مصدر الرصد المعتمد.',
      ),
      const SizedBox(height: 12),
      _ActionCard(
        icon: Icons.map_outlined,
        title: 'استعراض المحطات',
        description: 'عرض المحطات الكلاسيكية والآلية من الدليل المعتمد.',
        onTap: onOpenStations,
      ),
      const SizedBox(height: 10),
      _ActionCard(
        icon: Icons.assignment_outlined,
        title: 'الانتقال إلى أعمال الرصد',
        description: 'اختيار محطة وفتح واجهات الإدخال والمراجعة.',
        onTap: onOpenObservations,
      ),
    ],
  );
}

class _InformationPage extends StatelessWidget {
  const _InformationPage({required this.icon, required this.title, required this.message, this.action});
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
        child: _StatusCard(icon: icon, title: title, description: message, action: action),
      ),
    ),
  );
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.icon, required this.title, required this.description, this.action});
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
          Text(title, style: const TextStyle(color: _navy, fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(description, style: const TextStyle(color: Color(0xFF64748B), height: 1.6)),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    ),
  );
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.icon, required this.title, required this.description, required this.onTap});
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      leading: Icon(icon, color: _blue, size: 28),
      title: Text(title, style: const TextStyle(color: _navy, fontWeight: FontWeight.bold)),
      subtitle: Text(description),
      trailing: const Icon(Icons.chevron_left),
      onTap: onTap,
    ),
  );
}
