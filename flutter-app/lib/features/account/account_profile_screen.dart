import 'package:flutter/material.dart';

class MetraAccountProfileScreen extends StatefulWidget {
  const MetraAccountProfileScreen({
    super.key,
    required this.email,
    this.onSignOut,
    this.loadAccountStatus,
  });

  final String? email;
  final Future<void> Function()? onSignOut;
  final Future<Map<String, dynamic>> Function()? loadAccountStatus;

  @override
  State<MetraAccountProfileScreen> createState() =>
      _MetraAccountProfileScreenState();
}

class _MetraAccountProfileScreenState extends State<MetraAccountProfileScreen> {
  late Future<Map<String, dynamic>>? _statusFuture;

  @override
  void initState() {
    super.initState();
    _statusFuture = widget.loadAccountStatus?.call();
  }

  void _reloadStatus() {
    final loader = widget.loadAccountStatus;
    if (loader == null) return;
    setState(() => _statusFuture = loader());
  }

  String _accountStateLabel(Object? value) => switch (value) {
        'active' => 'الحساب نشط',
        'pending' => 'الحساب قيد المراجعة',
        'suspended' => 'الحساب موقوف',
        'disabled' => 'الحساب معطل',
        'rejected' => 'تم رفض الحساب',
        null => 'حالة الحساب غير متاحة',
        _ => value.toString(),
      };

  String _requestStateLabel(Object? value) => switch (value) {
        'pending_station_approval' => 'بانتظار اعتماد رئيس المحطة',
        'pending_system_approval' => 'بانتظار الاعتماد النظامي النهائي',
        'approved' => 'تم اعتماد الطلب',
        'rejected' => 'تم رفض الطلب',
        'returned' => 'أعيد الطلب للمراجعة',
        null => 'لا يوجد طلب تسجيل ظاهر',
        _ => value.toString(),
      };

  String? _utcLabel(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return null;
    return '${parsed.toUtc().toIso8601String()} UTC';
  }

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
    if (confirmed == true && widget.onSignOut != null) {
      await widget.onSignOut!();
    }
  }

  Widget _accountStatus() {
    if (widget.loadAccountStatus == null || _statusFuture == null) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('حالة الحساب غير مربوطة'),
          subtitle: Text('لا تتوفر حالياً قراءة حالة الحساب من خدمة Backend في هذه الجلسة.'),
        ),
      );
    }
    return FutureBuilder<Map<String, dynamic>>(
      future: _statusFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: ListTile(
              leading: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              title: Text('جارٍ تحميل حالة الحساب'),
            ),
          );
        }
        if (snapshot.hasError) {
          return Card(
            child: ListTile(
              leading: const Icon(Icons.cloud_off_outlined),
              title: const Text('تعذر تحميل حالة الحساب'),
              subtitle: const Text('لم تتغير صلاحيات الحساب. أعد المحاولة أو تواصل مع مسؤول النظام.'),
              trailing: IconButton(
                tooltip: 'إعادة تحميل حالة الحساب',
                onPressed: _reloadStatus,
                icon: const Icon(Icons.refresh),
              ),
            ),
          );
        }
        final data = snapshot.data ?? const <String, dynamic>{};
        final accountState = data['account_state'];
        final requestState = data['request_status'];
        final reason = (data['state_reason'] ?? data['review_note'])?.toString();
        final submittedAt = _utcLabel(data['submitted_at']);
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.verified_user_outlined),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('حالة الحساب والاعتماد',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    IconButton(
                      tooltip: 'تحديث حالة الحساب',
                      onPressed: _reloadStatus,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(_accountStateLabel(accountState)),
                const SizedBox(height: 6),
                Text('طلب الانضمام: ${_requestStateLabel(requestState)}'),
                if (submittedAt != null) ...[
                  const SizedBox(height: 6),
                  Text('تاريخ الطلب: $submittedAt'),
                ],
                if (reason != null && reason.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('ملاحظة المراجعة: $reason'),
                ],
              ],
            ),
          ),
        );
      },
    );
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
                    (widget.email?.trim().isNotEmpty ?? false)
                        ? widget.email!.trim()
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
          _accountStatus(),
          const Card(
            child: ListTile(
              leading: Icon(Icons.admin_panel_settings_outlined),
              title: Text('الأدوار والصلاحيات'),
              subtitle: Text(
                'تُحدد الصلاحيات من الخادم وفق تعيينات الحساب. '
                'لا يعرض هذا التطبيق دوراً أو محطة مسندة قبل توفر سياق حساب موثوق من الخادم.',
              ),
            ),
          ),
          if (widget.onSignOut != null) ...[
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
