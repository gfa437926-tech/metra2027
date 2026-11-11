import 'package:flutter/material.dart';

class MetraAccountProfileScreen extends StatelessWidget {
  const MetraAccountProfileScreen({
    super.key,
    required this.email,
    this.onSignOut,
  });

  final String? email;
  final Future<void> Function()? onSignOut;

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل تريد إنهاء الجلسة الحالية على هذا الجهاز؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );
    if (confirmed == true && onSignOut != null) {
      await onSignOut!();
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'الملف الشخصي',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const CircleAvatar(
                    radius: 34,
                    child: Icon(Icons.person_outline, size: 36),
                  ),
                  const SizedBox(height: 14),
                  const Text('الحساب المسجل',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  SelectableText(
                    (email?.trim().isNotEmpty ?? false)
                        ? email!.trim()
                        : 'البريد الإلكتروني غير متاح',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Card(
            child: ListTile(
              leading: Icon(Icons.verified_user_outlined),
              title: Text('مصدر الهوية'),
              subtitle: Text('تتم إدارة تسجيل الدخول والجلسة بواسطة Supabase Auth.'),
            ),
          ),
          const Card(
            child: ListTile(
              leading: Icon(Icons.admin_panel_settings_outlined),
              title: Text('الأدوار والصلاحيات'),
              subtitle: Text(
                'تُحدد الصلاحيات من الخادم وفق تعيينات الحساب. '
                'لا يمنح عرض هذه الصفحة أي صلاحية إضافية.',
              ),
            ),
          ),
          if (onSignOut != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => _confirmSignOut(context),
              icon: const Icon(Icons.logout),
              label: const Text('تسجيل الخروج'),
            ),
          ],
        ],
      );
}
