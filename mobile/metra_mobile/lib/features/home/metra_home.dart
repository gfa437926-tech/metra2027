import 'package:flutter/material.dart';
import '../../core/api/metra_api_client.dart';
import '../observations/observation_review_screen.dart';
import '../stations/station_directory_screen.dart';
import '../maintenance/equipment_fault_screen.dart';
import '../observations/observation_submit_screen.dart';

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
  @override
  Widget build(BuildContext context) {
    final pages = [
      _HomeOverview(onOpenStations: () => setState(() => _index = 1)),
      StationDirectoryScreen(api: widget.api, selectedStationId: _selectedStationId,
        onStationSelected: (id) => setState(() => _selectedStationId = id)),
      _selectedStationId == null
        ? const _InformationPage(icon: Icons.fact_check_outlined, title: 'مراجعة الرصدات',
            message: 'اختر محطة أولاً من دليل المحطات. سيطبّق الخادم صلاحيات حسابك على المحطة والعمليات المتاحة.')
        : ObservationReviewScreen(api: widget.api, stationId: _selectedStationId!),
      _selectedStationId == null
        ? const _InformationPage(icon: Icons.edit_note_outlined, title: 'إدخال نشرة',
            message: 'اختر محطة أولاً لإدخال نشرة ساعية عبر واجهة الخادم.')
        : ObservationSubmitScreen(api: widget.api, stationId: _selectedStationId!),
      _selectedStationId == null
        ? const _InformationPage(icon: Icons.build_outlined, title: 'أعطال المعدات',
            message: 'اختر محطة أولاً لتسجيل أعطال المعدات على الخادم.')
        : EquipmentFaultScreen(api: widget.api, stationId: _selectedStationId!),
      _InformationPage(icon: Icons.settings_outlined, title: 'إعدادات الحساب',
        message:  'الحساب: ${widget.userEmail ?? 'مستخدم مسجل'}\nالجلسة تحفظ وتُجدد بواسطة Supabase Auth.',
        action: widget.onSignOut == null ? null : FilledButton.tonalIcon(
          onPressed: widget.onSignOut, icon: const Icon(Icons.logout), label: const Text('تسجيل الخروج'))),
    ];
    return Directionality(textDirection: TextDirection.rtl, child: Scaffold(
      appBar: AppBar(backgroundColor: _navy, foregroundColor: Colors.white,
        title: const Text('METRA 2027'),
        actions: [Padding(padding: const EdgeInsetsDirectional.only(end: 16),
          child: Center(child: Text('منصة الأرصاد', style: TextStyle(color: Colors.white.withValues(alpha: .78), fontSize: 12))))]),
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'المحطات'),
          NavigationDestination(icon: Icon(Icons.fact_check_outlined), selectedIcon: Icon(Icons.fact_check), label: 'مراجعة'),
          NavigationDestination(icon: Icon(Icons.edit_note_outlined), selectedIcon: Icon(Icons.edit_note), label: 'إدخال'),
          NavigationDestination(icon: Icon(Icons.build_outlined), selectedIcon: Icon(Icons.build), label: 'الصيانة'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'الإعدادات'),
        ]),
    ));
  }
}
class _HomeOverview extends StatelessWidget {
  const _HomeOverview({required this.onOpenStations});
  final VoidCallback onOpenStations;
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(20), children: [
    Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(borderRadius: BorderRadius.circular(24),
      gradient: const LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Color(0xFF061746), Color(0xFF0754B5)])),
      child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.cloud_outlined, color: Colors.white, size: 38), SizedBox(height: 16),
        Text('ذكاء الأرصاد يبدأ من بيانات موثوقة', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        SizedBox(height: 8), Text('واجهة METRA 2027', style: TextStyle(color: Color(0xFFD6E8FF))),
      ])),
    const SizedBox(height: 18),
    const _StatusCard(icon: Icons.cloud_off_outlined, title: 'الطقس المباشر غير متصل',
      description: 'لن تُعرض درجات حرارة أو رياح تجريبية على أنها قياسات فعلية. ستظهر البيانات عند ربط مصدر الرصد المعتمد.'),
    const SizedBox(height: 12),
    _ActionCard(icon: Icons.map_outlined, title: 'استعراض المحطات',
      description: 'عرض المحطات الكلاسيكية والآلية من الدليل المعتمد.', onTap: onOpenStations),
  ]);
}
class _InformationPage extends StatelessWidget {
  const _InformationPage({required this.icon, required this.title, required this.message, this.action});
  final IconData icon; final String title; final String message; final Widget? action;
  @override
  Widget build(BuildContext context) => Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24),
    child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520),
      child: _StatusCard(icon: icon, title: title, description: message, action: action))));
}
class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.icon, required this.title, required this.description, this.action});
  final IconData icon; final String title; final String description; final Widget? action;
  @override
  Widget build(BuildContext context) => Card(elevation: 0, color: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: _blue, size: 30), const SizedBox(height: 12),
      Text(title, style: const TextStyle(color: _navy, fontSize: 17, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8), Text(description, style: const TextStyle(color: Color(0xFF64748B), height: 1.6)),
      if (action != null) ...[const SizedBox(height: 16), action!],
    ])));
}
class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.icon, required this.title, required this.description, required this.onTap});
  final IconData icon; final String title; final String description; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(elevation: 0, color: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      leading: Icon(icon, color: _blue, size: 28), title: Text(title, style: const TextStyle(color: _navy, fontWeight: FontWeight.bold)),
      subtitle: Text(description), trailing: const Icon(Icons.chevron_left), onTap: onTap));
}
