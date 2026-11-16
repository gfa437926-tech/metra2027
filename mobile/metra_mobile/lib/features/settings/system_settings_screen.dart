import 'package:material_ui/material_ui.dart';

import '../../api_config.dart';
import '../../core/auth/metra_auth.dart';

/// Account and client configuration. Never displays secrets or service-role keys.
class SystemSettingsScreen extends StatelessWidget {
  const SystemSettingsScreen({
    super.key,
    required this.userEmail,
    required this.onSignOut,
  });

  final String? userEmail;
  final Future<void> Function()? onSignOut;

  /// Keep in sync with pubspec.yaml version until a platform package is approved.
  static const appVersionLabel = '0.1.0+1';

  @override
  Widget build(BuildContext context) {
    final apiOk = ApiConfig.isConfigured;
    final supabaseOk = isMetraSupabaseConfigured;

    return Scaffold(
      appBar: AppBar(title: const Text('إعدادات النظام والحساب')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 0,
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person_outline)),
              title: const Text('الحساب الحالي'),
              subtitle: Text(userEmail ?? 'بيانات الحساب غير متاحة'),
            ),
          ),
          const SizedBox(height: 12),
          const Card(
            elevation: 0,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.language),
                  title: Text('لغة الواجهة'),
                  subtitle: Text('العربية'),
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.format_textdirection_r_to_l),
                  title: Text('اتجاه الواجهة'),
                  subtitle: Text('من اليمين إلى اليسار (RTL)'),
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('إصدار التطبيق'),
                  subtitle: Text(appVersionLabel),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    apiOk ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                    color: apiOk ? const Color(0xFF087CF0) : const Color(0xFFB45309),
                  ),
                  title: const Text('اتصال واجهة البرمجة (API)'),
                  subtitle: Text(
                    apiOk
                        ? 'مُعد عبر METRA_API_BASE_URL (HTTPS فقط)'
                        : 'غير مُعد — مرّر --dart-define=METRA_API_BASE_URL=https://…',
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    supabaseOk
                        ? Icons.verified_user_outlined
                        : Icons.gpp_bad_outlined,
                    color: supabaseOk
                        ? const Color(0xFF087CF0)
                        : const Color(0xFFB45309),
                  ),
                  title: const Text('مصادقة Supabase'),
                  subtitle: Text(
                    supabaseOk
                        ? 'مُعدة بمفتاح النشر العام فقط (لا Service Role في العميل)'
                        : 'غير مُعدة — يتطلب METRA_SUPABASE_URL وPUBLISHABLE_KEY',
                  ),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.security_outlined),
                  title: Text('حماية الجلسة'),
                  subtitle: Text(
                    'تُخزَّن الجلسة في التخزين الآمن للجهاز. '
                    'لا تُخزن مفاتيح الخدمة السرية داخل تطبيق Flutter.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed:
                onSignOut == null ? null : () async => onSignOut!(),
            icon: const Icon(Icons.logout),
            label: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );
  }
}
