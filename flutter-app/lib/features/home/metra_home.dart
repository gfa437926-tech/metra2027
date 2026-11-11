import 'package:flutter/material.dart';
import '../../core/api/metra_api_client.dart';
import '../observations/observation_review_screen.dart';
import '../stations/station_directory_screen.dart';
import '../ops/station_ops_hub_screen.dart';
import '../observations/observation_submit_screen.dart';
import '../forecasting/forecasting_center_screen.dart';
import '../account/account_profile_screen.dart';
import '../auth/registration_screen.dart';
import '../observations/phenomenon_capture_screen.dart';
import '../specialist/specialist_unit_shell_screen.dart';
import '../electronic_auditor/electronic_auditor_screen.dart';
import '../observations/daily_observation_submit_screen.dart';
import '../reports/station_reports_hub_screen.dart';
import '../reports/observation_status_screen.dart';

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
  String? _selectedStationLabel;
  @override
  Widget build(BuildContext context) {
    final pages = [
      _HomeOverview(
        selectedStationId: _selectedStationId,
        selectedStationLabel: _selectedStationLabel,
        onOpenStations: () => setState(() => _index = 1),
        onOpenForecasting: () => setState(() => _index = 5),
        onOpenEntry: () => setState(() => _index = 3),
        onOpenReview: () => setState(() => _index = 2),
        onOpenOps: () => setState(() => _index = 4),
      ),
      StationDirectoryScreen(api: widget.api, selectedStationId: _selectedStationId,
        selectedStationLabel: _selectedStationLabel,
        onStationSelected: (id) => setState(() => _selectedStationId = id),
        onStationItemSelected: (station) => setState(() {
          _selectedStationId = station.id;
          _selectedStationLabel = '${station.nameArabic} (${station.localCode})';
        })),

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
        onObservationStatus: () {
          final stationId = _selectedStationId;
          if (stationId == null) {
            setState(() => _index = 1);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('اختر محطة من الدليل أولاً لعرض حالة النشرات.')),
            );
            return;
          }
          Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => ObservationStatusScreen(api: widget.api, stationId: stationId),
          ));
        },
        onReportsHub: () {
          final stationId = _selectedStationId;
          if (stationId == null) {
            setState(() => _index = 1);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('اختر محطة من الدليل أولاً لفتح تقارير المحطة.')),
            );
            return;
          }
          Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => StationReportsHubScreen(api: widget.api, stationId: stationId),
          ));
        },
        onRegistration: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => MetraRegistrationScreen(api: widget.api, initiallyAuthenticated: true),
        )),
        onPhenomena: () {
          final stationId = _selectedStationId;
          if (stationId == null) {
            setState(() => _index = 1);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('اختر محطة من الدليل أولاً لتسجيل الظاهرة.')),
            );
            return;
          }
          Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => PhenomenonCaptureScreen(api: widget.api, stationId: stationId),
          ));
        },
        onDailyEntry: () {
          final stationId = _selectedStationId;
          if (stationId == null) {
            setState(() => _index = 1);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('اختر محطة من الدليل أولاً لإدخال النشرة اليومية.')),
            );
            return;
          }
          Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => DailyObservationSubmitScreen(api: widget.api, stationId: stationId),
          ));
        },
        onElectronicAuditor: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => const ElectronicAuditorScreen(),
        )),
        onRainfall: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => const SpecialistUnitShellScreen(
            title: 'الأمطار والهطول',
            unitCode: 'rainfall',
            description: 'إدخال ومراجعة وتحليل الهطول وفق النماذج المرجعية بعد اعتماد العقد وAPI.',
            requiredBeforeBinding: [
              'عقد حقول الأمطار المعتمد',
              'Endpoints خادمية مع عزل المحطة',
              'اختبارات قبول بدون بيانات وهمية',
            ],
          ),
        )),
        onClimate: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => const SpecialistUnitShellScreen(
            title: 'البيانات المناخية',
            unitCode: 'climate',
            description: 'تقارير وتجميعات مناخية من مصدر معتمد فقط — لا سلاسل مختلقة.',
            requiredBeforeBinding: [
              'تعريف صيغ التجميع المناخي',
              'API تقارير مناخية معتمدة',
            ],
          ),
        )),
        onAgriculture: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => const SpecialistUnitShellScreen(
            title: 'الرصد الزراعي',
            unitCode: 'agriculture',
            description: 'حقول الرصد الزراعي من المراجع المعتمدة بعد ربط API.',
            requiredBeforeBinding: ['عقد الحقول الزراعية', 'مسار حفظ خادمي'],
          ),
        )),
        onSoil: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => const SpecialistUnitShellScreen(
            title: 'حرارة التربة',
            unitCode: 'soil_temperature',
            description: 'قياسات الأعماق والوحدات وفق المرجع — الهيكل فقط حالياً.',
            requiredBeforeBinding: ['عقد حرارة التربة', 'API محطة-معزول'],
          ),
        )),
        onAiWorkspace: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => const SpecialistUnitShellScreen(
            title: 'مساحة الذكاء الاصطناعي',
            unitCode: 'ai_workspace',
            description: 'الاستفسار والتحليل عبر بوابة Backend فقط. لا تُعد مخرجات AI قياسات فعلية.',
            requiredBeforeBinding: [
              'AI Gateway على ASP.NET',
              'تسجيل العمليات الحساسة',
              'عدم وضع مفاتيح المزود في Flutter',
            ],
          ),
        )),
        onClimatol: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => const SpecialistUnitShellScreen(
            title: 'تجانس Climatol',
            unitCode: 'climatol',
            description: 'تشغيل التجانس على عامل معزول مع حفظ النتائج كمنتج مستقل دون تعديل السجلات الأصلية.',
            requiredBeforeBinding: [
              'عامل معالجة Climatol معزول',
              'بصمة مجموعة البيانات وإصدار البرنامج',
              'مسار اعتماد بشري للنتائج',
            ],
          ),
        )),
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
    required this.onRegistration,
    required this.onPhenomena,
    required this.onDailyEntry,
    required this.onElectronicAuditor,
    required this.onObservationStatus,
    required this.onReportsHub,
    required this.onRainfall,
    required this.onClimate,
    required this.onAgriculture,
    required this.onSoil,
    required this.onAiWorkspace,
    required this.onClimatol,
  });

  final VoidCallback onReview;
  final VoidCallback onOperations;
  final VoidCallback onSettings;
  final VoidCallback onRegistration;
  final VoidCallback onPhenomena;
  final VoidCallback onDailyEntry;
  final VoidCallback onElectronicAuditor;
  final VoidCallback onObservationStatus;
  final VoidCallback onReportsHub;
  final VoidCallback onRainfall;
  final VoidCallback onClimate;
  final VoidCallback onAgriculture;
  final VoidCallback onSoil;
  final VoidCallback onAiWorkspace;
  final VoidCallback onClimatol;

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
        icon: Icons.cloud_queue_outlined,
        title: 'تسجيل ظاهرة جوية',
        description: 'بدء وإنهاء الظواهر مع تحقق الخادم وحفظها ضمن المحطة المحددة.',
        onTap: onPhenomena,
      ),
      const SizedBox(height: 10),
      _ActionCard(
        icon: Icons.person_add_alt_1_outlined,
        title: 'طلب الانضمام / حالة التسجيل',
        description: 'استكمال بيانات طلب الانضمام ومتابعة الاعتماد المؤسسي.',
        onTap: onRegistration,
      ),
      const SizedBox(height: 10),
      _ActionCard(
        icon: Icons.calendar_month_outlined,
        title: 'إدخال النشرة اليومية',
        description: 'نماذج 24h / 06UTC / 18UTC عبر واجهة الخادم بعد اختيار المحطة.',
        onTap: onDailyEntry,
      ),
      const SizedBox(height: 10),
      _ActionCard(
        icon: Icons.insights_outlined,
        title: 'حالة نشرات المحطة',
        description: 'أعداد طابور المراجعة والإرجاع من API للمحطة المحددة (UTC).',
        onTap: onObservationStatus,
      ),
      const SizedBox(height: 10),
      _ActionCard(
        icon: Icons.assessment_outlined,
        title: 'تقارير المحطة',
        description: 'مركز تقارير المحطة المرتبطة بالخادم بعد اختيار المحطة.',
        onTap: onReportsHub,
      ),
      const SizedBox(height: 10),
      _ActionCard(
        icon: Icons.rule_folder_outlined,
        title: 'التدقيق الإلكتروني',
        description: 'هيكل لمنظومة تدقيق السجلات الورقية والمسجلات — بدون OCR حالياً.',
        onTap: onElectronicAuditor,
      ),
      const SizedBox(height: 10),
      _ActionCard(
        icon: Icons.water_drop_outlined,
        title: 'الأمطار والهطول',
        description: 'وحدة متخصصة — بانتظار عقد API معتمد (بدون مجاميع وهمية).',
        onTap: onRainfall,
      ),
      const SizedBox(height: 10),
      _ActionCard(
        icon: Icons.thermostat_outlined,
        title: 'البيانات المناخية',
        description: 'هيكل فقط حتى اعتماد عقود التجميع المناخي.',
        onTap: onClimate,
      ),
      const SizedBox(height: 10),
      _ActionCard(
        icon: Icons.agriculture_outlined,
        title: 'الرصد الزراعي',
        description: 'هيكل فقط — لا حفظ تشغيلي دون API.',
        onTap: onAgriculture,
      ),
      const SizedBox(height: 10),
      _ActionCard(
        icon: Icons.layers_outlined,
        title: 'حرارة التربة',
        description: 'هيكل فقط — لا قيم تجريبية.',
        onTap: onSoil,
      ),
      const SizedBox(height: 10),
      _ActionCard(
        icon: Icons.psychology_outlined,
        title: 'مساحة الذكاء الاصطناعي',
        description: 'بوابة AI على الخادم مطلوبة — لا مفاتيح في التطبيق.',
        onTap: onAiWorkspace,
      ),
      const SizedBox(height: 10),
      _ActionCard(
        icon: Icons.timeline,
        title: 'تجانس Climatol',
        description: 'تشغيل على عامل معزول بعد الاعتماد — الهيكل فقط.',
        onTap: onClimatol,
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
  const _HomeOverview({
    required this.onOpenStations,
    required this.onOpenForecasting,
    required this.onOpenEntry,
    required this.onOpenReview,
    required this.onOpenOps,
    this.selectedStationId,
    this.selectedStationLabel,
  });
  final VoidCallback onOpenStations;
  final VoidCallback onOpenForecasting;
  final VoidCallback onOpenEntry;
  final VoidCallback onOpenReview;
  final VoidCallback onOpenOps;
  final String? selectedStationId;
  final String? selectedStationLabel;

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
                Text(
                  'ذكاء الأرصاد يبدأ من بيانات موثوقة',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'إدخال ومراجعة واعتماد النشرات عبر الخادم مع عزل المحطات وصلاحيات الدور.',
                  style: TextStyle(color: Colors.white70, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: selectedStationId == null
                ? const Color(0xFFFFF4E5)
                : const Color(0xFFE8F7EE),
            child: ListTile(
              leading: Icon(
                selectedStationId == null
                    ? Icons.warning_amber_outlined
                    : Icons.check_circle_outline,
                color: selectedStationId == null
                    ? Colors.orange.shade800
                    : Colors.green.shade800,
              ),
              title: Text(
                selectedStationId == null
                    ? 'لم تُحدد محطة العمل'
                    : 'محطة العمل محددة',
              ),
              subtitle: Text(
                selectedStationId == null
                    ? 'اختر محطة من الدليل لتفعيل الإدخال والمراجعة والصيانة والتقارير.'
                    : '${selectedStationLabel ?? selectedStationId} — يمكنك المتابعة للإدخال أو المراجعة أو العمليات.',
              ),
              trailing: TextButton(
                onPressed: onOpenStations,
                child: Text(selectedStationId == null ? 'اختيار' : 'تغيير'),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _QuickNavCard(
            icon: Icons.edit_note_outlined,
            title: 'إدخال نشرة ساعية',
            enabled: selectedStationId != null,
            onTap: selectedStationId == null ? onOpenStations : onOpenEntry,
          ),
          _QuickNavCard(
            icon: Icons.fact_check_outlined,
            title: 'مراجعة النشرات',
            enabled: selectedStationId != null,
            onTap: selectedStationId == null ? onOpenStations : onOpenReview,
          ),
          _QuickNavCard(
            icon: Icons.build_outlined,
            title: 'الصيانة والدعم',
            enabled: selectedStationId != null,
            onTap: selectedStationId == null ? onOpenStations : onOpenOps,
          ),
          _QuickNavCard(
            icon: Icons.public,
            title: 'مركز التنبؤ الجوي',
            enabled: true,
            onTap: onOpenForecasting,
          ),
          const SizedBox(height: 8),
          const Text(
            'التوقيت التشغيلي UTC فقط. لا تُعرض بيانات وهمية عند غياب الاستجابة.',
            style: TextStyle(color: Colors.blueGrey, fontSize: 12),
          ),
        ],
      );
}

class _QuickNavCard extends StatelessWidget {
  const _QuickNavCard({
    required this.icon,
    required this.title,
    required this.onTap,
    required this.enabled,
  });
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: Icon(icon, color: enabled ? _blue : Colors.grey),
          title: Text(title),
          subtitle: Text(
            enabled ? 'متاح للمحطة المحددة' : 'يتطلب اختيار محطة أولاً',
          ),
          trailing: const Icon(Icons.chevron_left),
          onTap: onTap,
        ),
      );
}

class _InformationPage extends StatelessWidget {
  const _InformationPage({required this.icon, required this.title, required this.message});
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: _StatusCard(icon: icon, title: title, description: message),
      ),
    ),
  );
}
class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.icon, required this.title, required this.description});
  final IconData icon;
  final String title;
  final String description;
  @override
  Widget build(BuildContext context) => Card(elevation: 0, color: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: _blue, size: 30), const SizedBox(height: 12),
      Text(title, style: const TextStyle(color: _navy, fontSize: 17, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8), Text(description, style: const TextStyle(color: Color(0xFF64748B), height: 1.6)),
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
