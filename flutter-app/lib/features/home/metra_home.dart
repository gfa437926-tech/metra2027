import 'package:flutter/material.dart';
import '../../core/api/metra_api_client.dart';
import '../observations/observation_review_screen.dart';
import '../stations/station_directory_screen.dart';
import '../ops/station_ops_hub_screen.dart';
import '../observations/observation_submit_screen.dart';
import '../forecasting/forecasting_center_screen.dart';
import '../account/account_profile_screen.dart';

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
      _HomeOverview(
        onOpenStations: () => setState(() => _index = 1),
        onOpenForecasting: () => setState(() => _index = 5)),
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
        ? const _InformationPage(icon: Icons.build_outlined, title: 'الصيانة والدعم',
            message: 'اختر محطة أولاً لتسجيل أعطال المعدات أو بلاغات الدعم على الخادم.')
        : StationOpsHubScreen(api: widget.api, stationId: _selectedStationId!),
      ForecastingCenterScreen(api: widget.api),
      MetraAccountProfileScreen(
        email: widget.userEmail,
        onSignOut: widget.onSignOut,
      ),
      _MoreMenuPage(
        onReview: () => setState(() => _index = 2),
        onOperations: () => setState(() => _index = 4),
        onSettings: () => setState(() => _index = 6),
      ),
    ];
    return Directionality(textDirection: TextDirection.rtl, child: Scaffold(
      appBar: AppBar(backgroundColor: _navy, foregroundColor: Colors.white,
        title: const Text('METRA 2027'),
        actions: [Padding(padding: const EdgeInsetsDirectional.only(end: 16),
          child: Center(child: Text('منصة الأرصاد', style: TextStyle(color: Colors.white.withValues(alpha: .78), fontSize: 12))))]),
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: switch (_index) {
          0 => 0,
          1 => 1,
          3 => 2,
          5 => 3,
          _ => 4,
        },
        onDestinationSelected: (value) => setState(() {
          _index = switch (value) {
            0 => 0,
            1 => 1,
            2 => 3,
            3 => 5,
            _ => 7,
          };
        }),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'المحطات'),
          NavigationDestination(icon: Icon(Icons.edit_note_outlined), selectedIcon: Icon(Icons.edit_note), label: 'إدخال'),
          NavigationDestination(icon: Icon(Icons.cloud_outlined), selectedIcon: Icon(Icons.cloud), label: 'التنبؤ'),
          NavigationDestination(icon: Icon(Icons.grid_view_outlined), selectedIcon: Icon(Icons.grid_view), label: 'المزيد'),
        ]),
    ));
  }
}
class _MoreMenuPage extends StatelessWidget {
  const _MoreMenuPage({
    required this.onReview,
    required this.onOperations,
    required this.onSettings,
  });

  final VoidCallback onReview;
  final VoidCallback onOperations;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const Text('المزيد', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      _ActionCard(
        icon: Icons.fact_check_outlined,
        title: 'مراجعة الرصدات',
        description: 'طوابير المراجعة والقرارات والسجلات المُعادة.',
        onTap: onReview,
      ),
      const SizedBox(height: 10),
      _ActionCard(
        icon: Icons.build_outlined,
        title: 'العمليات والصيانة',
        description: 'الأعطال والدعم والتقارير وتعيينات المحطة.',
        onTap: onOperations,
      ),
      const SizedBox(height: 10),
      _ActionCard(
        icon: Icons.settings_outlined,
        title: 'إعدادات الحساب',
        description: 'بيانات الحساب والجلسة وتسجيل الخروج.',
        onTap: onSettings,
      ),
    ],
  );
}

class _HomeOverview extends StatelessWidget {
  const _HomeOverview({required this.onOpenStations, required this.onOpenForecasting});
  final VoidCallback onOpenStations;
  final VoidCallback onOpenForecasting;
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
    const SizedBox(height: 12),
    _ActionCard(
      icon: Icons.cloud_outlined,
      title: 'مركز التنبؤ الجوي',
      description: 'مقارنة جغرافية وتفاصيل الكتالوج — اطلاع فقط بدون تعديل السجلات.',
      onTap: onOpenForecasting,
    ),
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
