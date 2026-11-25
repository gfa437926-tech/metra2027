import 'package:material_ui/material_ui.dart';

import '../../api_config.dart';
import '../../core/auth/metra_auth.dart';
import '../../core/api/metra_api_client.dart';
import '../account/account_hub_screen.dart';
import '../notifications/notifications_center_screen.dart';

/// Account and client configuration. Never displays secrets or service-role keys.
///
/// Embedded under [MetraHome] — no nested [Scaffold]/[AppBar] (shell owns chrome).
class SystemSettingsScreen extends StatefulWidget {
  const SystemSettingsScreen({
    super.key,
    required this.userEmail,
    required this.onSignOut,
    this.api,
  });

  final String? userEmail;
  final Future<void> Function()? onSignOut;
  final MetraApiClient? api;

  /// Keep in sync with pubspec.yaml version until a platform package is approved.
  static const appVersionLabel = '0.1.0+1';

  @override
  State<SystemSettingsScreen> createState() => _SystemSettingsScreenState();
}

class _SystemSettingsScreenState extends State<SystemSettingsScreen> {
  bool _signingOut = false;

  Future<void> _confirmSignOut() async {
    if (_signingOut || widget.onSignOut == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد تسجيل الخروج'),
          content: const Text(
            'سيتم إنهاء الجلسة على هذا الجهاز. '
            'ستحتاج إلى تسجيل الدخول مجدداً للوصول إلى المحطات والرصد.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('تسجيل الخروج'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _signingOut = true);
    try {
      await widget.onSignOut!();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر تسجيل الخروج. تحقق من الاتصال وحاول مجدداً.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final apiOk = ApiConfig.isConfigured;
    final supabaseOk = isMetraSupabaseConfigured;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Material(
        color: Colors.transparent,
        child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'إعدادات النظام والحساب',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF061B4A),
                ),
          ),
          const SizedBox(height: 4),
          const Text(
            'معلومات الحساب واتصال العميل. لا تُعرض أسرار أو مفاتيح خدمة.',
            style: TextStyle(color: Color(0xFF64748B), height: 1.4),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person_outline)),
              title: const Text('الحساب الحالي'),
              subtitle: Text(widget.userEmail ?? 'بيانات الحساب غير متاحة'),
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
                  subtitle: Text(SystemSettingsScreen.appVersionLabel),
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
                  leading: const Icon(Icons.manage_accounts_outlined),
                  title: const Text('الحساب الشخصي وكلمة المرور'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => Scaffold(
                          appBar: AppBar(title: const Text('الحساب الشخصي')),
                          body: AccountHubScreen(userEmail: widget.userEmail, api: widget.api),
                        ),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: const Text('مركز الإشعارات'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => Scaffold(
                          appBar: AppBar(title: const Text('الإشعارات')),
                          body: const NotificationsCenterScreen(),
                        ),
                      ),
                    );
                  },
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
                    apiOk
                        ? Icons.cloud_done_outlined
                        : Icons.cloud_off_outlined,
                    color: apiOk
                        ? const Color(0xFF087CF0)
                        : const Color(0xFFB45309),
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
            onPressed: widget.onSignOut == null || _signingOut
                ? null
                : _confirmSignOut,
            icon: _signingOut
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout),
            label: Text(_signingOut ? 'جاري تسجيل الخروج…' : 'تسجيل الخروج'),
          ),
        ],
        ),
      ),
    );
  }
}
