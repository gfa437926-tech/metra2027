import 'package:flutter/material.dart';

import 'account_access_state_screen.dart';

class MetraAccountStateGate extends StatelessWidget {
  const MetraAccountStateGate({
    super.key,
    required this.statusFuture,
    required this.activeChild,
    required this.pendingChild,
    required this.onRetry,
    required this.onSignOut,
  });

  final Future<Map<String, dynamic>> statusFuture;
  final Widget activeChild;
  final Widget pendingChild;
  final VoidCallback onRetry;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: statusFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        if (snapshot.hasError) {
          return MetraAccountAccessStateScreen(
            title: 'تعذر التحقق من حالة الحساب',
            message:
                'لن تُفتح مساحة العمل التشغيلية قبل التحقق من حالة الحساب والصلاحيات من الخادم. تحقق من الاتصال ثم أعد المحاولة.',
            onRetry: onRetry,
            onSignOut: onSignOut,
          );
        }

        final data = snapshot.data ?? const <String, dynamic>{};
        final state = data['account_state']?.toString();
        if (state == 'active') return activeChild;
        if (state == null || state == 'pending') return pendingChild;

        final title = switch (state) {
          'suspended' => 'الحساب موقوف',
          'disabled' => 'الحساب معطل',
          'rejected' => 'الحساب غير معتمد',
          _ => 'حالة الحساب غير معروفة',
        };
        final message = state == 'suspended' || state == 'disabled' || state == 'rejected'
            ? 'لا يمكن فتح مساحة العمل التشغيلية بهذه الحالة. راجع مسؤول النظام إذا كنت تعتقد أن الحالة غير صحيحة.'
            : 'أوقف التطبيق فتح مساحة العمل لأن الخادم أعاد حالة حساب غير معروفة. لا تُمنح أي صلاحية افتراضياً.';
        return MetraAccountAccessStateScreen(
          title: title,
          message: message,
          reason: data['state_reason']?.toString(),
          onRetry: onRetry,
          onSignOut: onSignOut,
        );
      },
    );
  }
}
