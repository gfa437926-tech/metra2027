import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/api/metra_api_client.dart';
import '../../core/theme/metra_theme.dart';
import 'registration_request_screen.dart';

/// Account hub: profile summary, password change, registration status notes.
/// Does not invent admin user management APIs.
class AccountHubScreen extends StatefulWidget {
  const AccountHubScreen({
    super.key,
    required this.userEmail,
    this.api,
    this.onOpenNotifications,
  });

  final String? userEmail;
  final MetraApiClient? api;
  final VoidCallback? onOpenNotifications;

  @override
  State<AccountHubScreen> createState() => _AccountHubScreenState();
}

class _AccountHubScreenState extends State<AccountHubScreen> {
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _busy = false;
  String? _message;
  bool _error = false;

  @override
  void dispose() {
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (_busy) return;
    final next = _newPassword.text;
    final confirm = _confirmPassword.text;
    if (next.length < 8) {
      setState(() {
        _error = true;
        _message = 'كلمة المرور الجديدة يجب ألا تقل عن 8 أحرف.';
      });
      return;
    }
    if (next != confirm) {
      setState(() {
        _error = true;
        _message = 'تأكيد كلمة المرور غير متطابق.';
      });
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
      _error = false;
    });
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: next),
      );
      if (!mounted) return;
      _newPassword.clear();
      _confirmPassword.clear();
      setState(() {
        _message = 'تم تحديث كلمة المرور بنجاح.';
        _error = false;
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = true;
        _message = e.message.contains('session')
            ? 'انتهت الجلسة. سجّل الدخول مجدداً.'
            : 'تعذر تحديث كلمة المرور. تحقق من الجلسة وحاول لاحقاً.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = true;
        _message = 'تعذر الاتصال بخدمة الحساب.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = widget.userEmail ?? 'غير متاح';
    return Directionality(
      textDirection: TextDirection.rtl,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'الحساب الشخصي',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: MetraColors.navy,
                ),
          ),
          const SizedBox(height: 8),
          const Text(
            'إدارة بيانات الجلسة وكلمة المرور. طلبات التسجيل والصلاحيات تُعتمد عبر مسؤولي المحطة والنظام.',
            style: TextStyle(color: MetraColors.muted, height: 1.45),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person_outline)),
              title: const Text('البريد الإلكتروني'),
              subtitle: Text(email),
            ),
          ),
          const SizedBox(height: 8),
          const Card(
            color: MetraColors.warningBg,
            child: ListTile(
              leading: Icon(Icons.verified_user_outlined, color: MetraColors.warning),
              title: Text('حالة الحساب والصلاحيات'),
              subtitle: Text(
                'تُستمد من سياق الصلاحيات على الخادم بعد تسجيل الدخول. '
                'الحساب غير المصرّح لا يظهر محطات تشغيلية.',
              ),
            ),
          ),
          if (widget.api != null) ...[
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.app_registration),
              title: const Text('طلب تسجيل على محطة'),
              trailing: const Icon(Icons.chevron_left),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: const Text('طلب تسجيل')),
                      body: RegistrationRequestScreen(api: widget.api!),
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.pending_actions_outlined),
              title: const Text('حالة طلب التسجيل'),
              trailing: const Icon(Icons.chevron_left),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: const Text('حالة التسجيل')),
                      body: RegistrationStatusScreen(api: widget.api!),
                    ),
                  ),
                );
              },
            ),
          ],
          if (widget.onOpenNotifications != null) ...[
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('مركز الإشعارات'),
              trailing: const Icon(Icons.chevron_left),
              onTap: widget.onOpenNotifications,
            ),
          ],
          const SizedBox(height: 20),
          Text(
            'تغيير كلمة المرور',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: MetraColors.navy,
                ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _newPassword,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'كلمة المرور الجديدة',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _confirmPassword,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'تأكيد كلمة المرور',
              border: OutlineInputBorder(),
            ),
          ),
          if (_message != null) ...[
            const SizedBox(height: 8),
            Text(
              _message!,
              style: TextStyle(
                color: _error ? MetraColors.danger : MetraColors.success,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy ? null : _changePassword,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.lock_reset),
            label: Text(_busy ? 'جاري التحديث…' : 'تحديث كلمة المرور'),
          ),
        ],
      ),
    );
  }
}
