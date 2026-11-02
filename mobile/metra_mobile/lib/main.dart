import 'package:flutter/material.dart';

import 'models/current_user_context.dart';
import 'services/current_user_context_client.dart';

void main() {
  runApp(const MetraMobileApp());
}

class MetraMobileApp extends StatelessWidget {
  const MetraMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF2C3E50);
    const blue = Color(0xFF2980B9);

    return MaterialApp(
      title: 'METRA 2027',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: blue),
        scaffoldBackgroundColor: const Color(0xFFF5F7F9),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: navy,
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
      ),
      home: const MetraHomePage(),
    );
  }
}

class MetraHomePage extends StatefulWidget {
  const MetraHomePage({super.key});

  @override
  State<MetraHomePage> createState() => _MetraHomePageState();
}

class _MetraHomePageState extends State<MetraHomePage> {
  int selectedIndex = 0;
  final CurrentUserContextClient _identityClient = CurrentUserContextClient();
  CurrentUserSessionState _sessionState = CurrentUserSessionState.unconfigured;
  CurrentUserContext? _currentUser;

  @override
  void initState() {
    super.initState();
    _sessionState = CurrentUserSessionState.loading;
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final result = await _identityClient.load();
    if (!mounted) return;
    setState(() {
      _sessionState = result.state;
      _currentUser = result.context;
    });
  }

  @override
  void dispose() {
    _identityClient.close();
    super.dispose();
  }

  String get _sessionLabel {
    switch (_sessionState) {
      case CurrentUserSessionState.loading:
        return 'جارٍ التحقق من الجلسة';
      case CurrentUserSessionState.unauthenticated:
        return 'غير مسجل الدخول';
      case CurrentUserSessionState.active:
        return 'الحساب نشط';
      case CurrentUserSessionState.pendingApproval:
        return 'الحساب بانتظار الموافقة';
      case CurrentUserSessionState.suspended:
        return 'الحساب موقوف أو غير مفعّل';
      case CurrentUserSessionState.forbidden:
        return 'لا توجد صلاحية للوصول';
      case CurrentUserSessionState.unavailable:
        return 'خدمة الهوية غير متاحة';
      case CurrentUserSessionState.unknownAccountState:
        return 'حالة الحساب غير معروفة';
      case CurrentUserSessionState.unconfigured:
        return 'نسخة معاينة — المصادقة غير مهيأة';
    }
  }

  static const sections = <_MobileSection>[
    _MobileSection('الرئيسية', Icons.dashboard_outlined),
    _MobileSection('السجلات', Icons.assignment_outlined),
    _MobileSection('المحطة', Icons.location_on_outlined),
    _MobileSection('حسابي', Icons.person_outline),
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('نظام إدارة البيانات الجوية'),
          actions: [
            IconButton(
              tooltip: 'الإشعارات',
              onPressed: () {},
              icon: const Icon(Icons.notifications_none),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF6E5),
                  border: Border.all(color: const Color(0xFFD6A54B)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$_sessionLabel. لا تُدخل بيانات تشغيلية أو شخصية حقيقية في نسخة المعاينة.',
                  style: const TextStyle(color: Color(0xFF624512)),
                ),
              ),
              Expanded(
                child: IndexedStack(
                  index: selectedIndex,
                  children: [
                    const _DashboardMobileView(),
                    const _RecordsMobileView(),
                    _PlaceholderMobileView(
                      title: 'المحطة',
                      description: _currentUser == null
                          ? 'لا توجد محطة مرتبطة بجلسة موثقة.'
                          : 'تعرض المحطات الفعالة بعد تحميلها من خدمة الهوية.',
                      icon: Icons.location_on_outlined,
                    ),
                    _PlaceholderMobileView(
                      title: 'حسابي',
                      description: _currentUser == null
                          ? _sessionLabel
                          : '${_currentUser!.profile.firstName} ${_currentUser!.profile.lastName}',
                      icon: Icons.person_outline,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: (index) =>
              setState(() => selectedIndex = index),
          destinations: sections
              .map((section) => NavigationDestination(
                    icon: Icon(section.icon),
                    label: section.title,
                  ))
              .toList(),
        ),
      ),
    );
  }
}

class _DashboardMobileView extends StatelessWidget {
  const _DashboardMobileView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF3498DB), Color(0xFF2980B9)],
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.cloud_queue, color: Colors.white, size: 38),
              SizedBox(height: 12),
              Text(
                'مرحباً بك في METRA 2027',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'إدارة السجلات الجوية والمناخية من هاتفك',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const Text(
          'أنواع السجلات',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        const _RecordTypeTile(
          title: 'السجلات اليومية',
          subtitle: 'إدخال ومراجعة الرصد اليومي',
          icon: Icons.calendar_today_outlined,
        ),
        const _RecordTypeTile(
          title: 'السجلات الساعية',
          subtitle: 'قراءات الرصد كل ساعة',
          icon: Icons.schedule,
        ),
        const _RecordTypeTile(
          title: 'السجلات الشهرية والسنوية',
          subtitle: 'ملخصات ومجاميع الفترات المناخية',
          icon: Icons.date_range,
        ),
        const _RecordTypeTile(
          title: 'الأرصاد الزراعية',
          subtitle: 'السجلات والقياسات الزراعية',
          icon: Icons.grass,
        ),
        const _RecordTypeTile(
          title: 'حرارة التربة',
          subtitle: 'درجات الحرارة حسب العمق',
          icon: Icons.thermostat,
        ),
      ],
    );
  }
}

class _RecordsMobileView extends StatelessWidget {
  const _RecordsMobileView();

  @override
  Widget build(BuildContext context) {
    return const _PlaceholderMobileView(
      title: 'السجلات المناخية',
      description:
          'ستُضاف هنا قوائم الإدخال والبحث والمراجعة بعد اعتماد نماذج السجلات.',
      icon: Icons.assignment_outlined,
    );
  }
}

class _PlaceholderMobileView extends StatelessWidget {
  const _PlaceholderMobileView({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: const Color(0xFF2980B9)),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 8),
            Text(description, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _RecordTypeTile extends StatelessWidget {
  const _RecordTypeTile({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFEAF3F8),
          child: Icon(icon, color: const Color(0xFF2980B9)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_left),
        onTap: () {},
      ),
    );
  }
}

class _MobileSection {
  const _MobileSection(this.title, this.icon);
  final String title;
  final IconData icon;
}
