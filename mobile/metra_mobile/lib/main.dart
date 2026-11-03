import 'package:flutter/material.dart';\nimport 'core/api/metra_api_client.dart';\nimport 'features/stations/station_directory_screen.dart';

void main() => runApp(const MetraApp());

const _navy = Color(0xFF061B4A);
const _blue = Color(0xFF087CF0);

class MetraApp extends StatelessWidget {
  const MetraApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'METRA 2027',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: _blue),
          scaffoldBackgroundColor: const Color(0xFFF3F6FC),
        ),
        home: MetraHome(api: api),
      );
}

class MetraHome extends StatefulWidget {
  const MetraHome({super.key});

  @override
  State<MetraHome> createState() => _MetraHomeState();
}

class _MetraHomeState extends State<MetraHome> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      _HomeOverview(onOpenStations: () => setState(() => _index = 1)),
      const _InformationPage(
        icon: Icons.map_outlined,
        title: 'دليل المحطات',
        message:
            'سيظهر هنا فهرس المحطات وإحداثياتها بعد إتاحة واجهة المحطات المصرّح بها. لم تتم إضافة محطات أو إحداثيات افتراضية.',
      ),
      const _InformationPage(
        icon: Icons.fact_check_outlined,
        title: 'مراجعة الرصدات',
        message:
            'واجهة المراجعة وعمليات الاعتماد والإرجاع متوفرة برمجياً، لكن لم يتم ربطها بعد بتسجيل الدخول وتجديد رمز Supabase واختيار محطة مخوّلة. لن نستخدم رمزاً أو محطة افتراضية لتجاوز هذا الشرط.',
      ),
      const _InformationPage(
        icon: Icons.analytics_outlined,
        title: 'التقارير والتحليلات',
        message:
            'لا توجد تقارير تشغيلية معروضة حالياً. ستُبنى المؤشرات من الرصدات المعتمدة فقط بعد ربط مصدر البيانات.',
      ),
      const _InformationPage(
        icon: Icons.settings_outlined,
        title: 'إعدادات التطبيق',
        message:
            'إعداد عنوان API يتم عبر METRA_API_BASE_URL وقت البناء. يلزم إكمال تسجيل الدخول وتجديد الجلسة واختيار المحطة قبل تفعيل العمليات المحمية.',
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
                    color: Colors.white.withValues(alpha: .78),
                    fontSize: 12,
                  ),
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
              icon: Icon(Icons.fact_check_outlined),
              selectedIcon: Icon(Icons.fact_check),
              label: 'الرصد',
            ),
            NavigationDestination(
              icon: Icon(Icons.analytics_outlined),
              selectedIcon: Icon(Icons.analytics),
              label: 'التقارير',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'الإعدادات',
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeOverview extends StatelessWidget {
  const _HomeOverview({required this.onOpenStations});
  final VoidCallback onOpenStations;

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
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'واجهة METRA 2027',
                  style: TextStyle(color: Color(0xFFD6E8FF)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const _StatusCard(
            icon: Icons.cloud_off_outlined,
            title: 'الطقس المباشر غير متصل',
            description:
                'لن تُعرض درجات حرارة أو رياح تجريبية على أنها قياسات فعلية. ستظهر البيانات عند ربط مصدر الرصد المعتمد.',
          ),
          const SizedBox(height: 12),
          _ActionCard(
            icon: Icons.map_outlined,
            title: 'استعراض المحطات',
            description: 'الانتقال إلى قسم دليل المحطات.',
            onTap: onOpenStations,
          ),
          const SizedBox(height: 12),
          const _StatusCard(
            icon: Icons.verified_user_outlined,
            title: 'سير عمل الرصد',
            description:
                'تتطلب عمليات الإرسال والمراجعة جلسة مستخدم صالحة وصلاحية مرتبطة بالمحطة.',
          ),
        ],
      );
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: _StatusCard(
              icon: icon,
              title: title,
              description: message,
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
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: _blue, size: 30),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  color: _navy,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  height: 1.6,
                ),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          leading: Icon(icon, color: _blue, size: 28),
          title: Text(
            title,
            style: const TextStyle(
              color: _navy,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(description),
          trailing: const Icon(Icons.chevron_left),
          onTap: onTap,
        ),
      );
}
