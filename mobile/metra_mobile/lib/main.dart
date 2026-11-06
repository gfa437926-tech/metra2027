import 'package:flutter/material.dart';

import 'models/current_user_context.dart';
import 'services/current_user_context_client.dart';
import 'features/stations/assigned_stations_screen.dart';
import 'features/observations/hourly_observation_screen.dart';

void main() {
  runApp(const MetraMobileApp());
}

class MetraMobileApp extends StatelessWidget {
  const MetraMobileApp({super.key, this.tokenProvider});

  final AccessTokenProvider? tokenProvider;

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
      home: MetraHomePage(tokenProvider: tokenProvider),
    );
  }
}

class MetraHomePage extends StatefulWidget {
  const MetraHomePage({super.key, this.tokenProvider});

  final AccessTokenProvider? tokenProvider;

  @override
  State<MetraHomePage> createState() => _MetraHomePageState();
}

class _MetraHomePageState extends State<MetraHomePage> {
  int selectedIndex = 0;
  late final CurrentUserContextClient _identityClient;
  CurrentUserSessionState _sessionState = CurrentUserSessionState.unconfigured;
  CurrentUserContext? _currentUser;

  @override
  void initState() {
    super.initState();
    _sessionState = CurrentUserSessionState.loading;
    _identityClient = CurrentUserContextClient(tokenProvider: widget.tokenProvider);
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser({bool refresh = false}) async {
    if (refresh && mounted) {
      setState(() {
        _sessionState = CurrentUserSessionState.loading;
      });
    }
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
        appBar: selectedIndex == 1 ? null : AppBar(
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
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$_sessionLabel. لا تُدخل بيانات تشغيلية أو شخصية حقيقية في نسخة المعاينة.',
                        style: const TextStyle(color: Color(0xFF624512)),
                      ),
                    ),
                    Semantics(
                      label: _sessionState == CurrentUserSessionState.loading
                          ? 'جارٍ تحديث حالة الجلسة'
                          : 'تحديث حالة الجلسة',
                      child: IconButton(
                        tooltip: 'تحديث حالة الجلسة',
                        onPressed: _sessionState == CurrentUserSessionState.loading
                            ? null
                            : () => _loadCurrentUser(refresh: true),
                        icon: _sessionState == CurrentUserSessionState.loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF624512),
                                ),
                              )
                            : const Icon(Icons.refresh, color: Color(0xFF624512)),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: IndexedStack(
                  index: selectedIndex,
                  children: [
                    _DashboardMobileView(onHourlyTap: () => setState(() => selectedIndex = 1)),
                    _RecordsMobileView(accessTokenProvider: widget.tokenProvider),
                    AssignedStationsScreen(
                      sessionState: _sessionState,
                      userContext: _currentUser,
                    ),
                    _AccountMobileView(
                      sessionLabel: _sessionLabel,
                      sessionState: _sessionState,
                      userContext: _currentUser,
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
  const _DashboardMobileView({required this.onHourlyTap});
  final VoidCallback onHourlyTap;

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
        _RecordTypeTile(
          title: 'السجلات الساعية',
          subtitle: 'قراءات الرصد كل ساعة',
          icon: Icons.schedule,
          onTap: onHourlyTap,
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
  const _RecordsMobileView({this.accessTokenProvider});

  final AccessTokenProvider? accessTokenProvider;

  @override
  Widget build(BuildContext context) {
    return HourlyObservationScreen(
      accessTokenProvider: accessTokenProvider?.getAccessToken,
    );
  }
}

class _AccountMobileView extends StatelessWidget {
  const _AccountMobileView({
    required this.sessionLabel,
    required this.sessionState,
    required this.userContext,
  });

  final String sessionLabel;
  final CurrentUserSessionState sessionState;
  final CurrentUserContext? userContext;

  @override
  Widget build(BuildContext context) {
    final user = userContext;
    final displayName = user == null
        ? 'لم يتم تحميل بيانات الحساب'
        : '${user.profile.firstName} ${user.profile.lastName}'.trim();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 28,
                  child: Icon(Icons.person_outline, size: 30),
                ),
                const SizedBox(height: 14),
                Text(displayName,
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(sessionLabel),
                const SizedBox(height: 16),
                const Divider(),
                _AccountDetailRow(
                  label: 'حالة الجلسة',
                  value: sessionLabel,
                  icon: Icons.verified_user_outlined,
                ),
                if (user != null) ...[
                  _AccountDetailRow(
                    label: 'اسم المستخدم',
                    value: user.profile.username,
                    icon: Icons.badge_outlined,
                  ),
                  _AccountDetailRow(
                    label: 'الدور',
                    value: user.role,
                    icon: Icons.admin_panel_settings_outlined,
                  ),
                ],
                if (sessionState == CurrentUserSessionState.unconfigured)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      'المصادقة غير مهيأة في نسخة المعاينة. لا يمكن عرض بيانات حساب حقيقية.',
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AccountDetailRow extends StatelessWidget {
  const _AccountDetailRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(value, textAlign: TextAlign.end,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
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
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;

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
        onTap: onTap,
      ),
    );
  }
}

class _MobileSection {
  const _MobileSection(this.title, this.icon);
  final String title;
  final IconData icon;
}
