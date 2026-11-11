import 'package:flutter/material.dart';

/// Password recovery uses the configured identity provider and deliberately
/// returns the same confirmation for known and unknown email addresses.
class MetraPasswordRecoveryScreen extends StatefulWidget {
  const MetraPasswordRecoveryScreen({
    super.key,
    required this.sendRecovery,
  });

  final Future<void> Function(String email) sendRecovery;

  @override
  State<MetraPasswordRecoveryScreen> createState() =>
      _MetraPasswordRecoveryScreenState();
}

class _MetraPasswordRecoveryScreenState
    extends State<MetraPasswordRecoveryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _busy = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
      _sent = false;
    });
    try {
      await widget.sendRecovery(_email.text.trim());
      if (mounted) setState(() => _sent = true);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'تعذر إرسال الطلب حالياً. تحقق من الاتصال وحاول لاحقاً.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(title: const Text('استعادة كلمة المرور')),
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Icon(Icons.lock_reset_outlined, size: 48),
                          const SizedBox(height: 16),
                          const Text(
                            'أدخل البريد الإلكتروني المرتبط بحسابك. '
                            'إذا كان الحساب مؤهلاً للاستعادة فستصلك تعليمات عبر البريد.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            decoration: const InputDecoration(
                              labelText: 'البريد الإلكتروني',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              final email = value?.trim() ?? '';
                              return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                      .hasMatch(email)
                                  ? null
                                  : 'أدخل بريداً إلكترونياً صحيحاً';
                            },
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Text(_error!,
                                style: const TextStyle(color: Colors.red)),
                          ],
                          if (_sent) ...[
                            const SizedBox(height: 12),
                            const Text(
                              'إذا كان البريد مرتبطاً بحساب قابل للاستعادة، '
                              'فستصلك رسالة تتضمن الخطوات التالية.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.green),
                            ),
                          ],
                          const SizedBox(height: 18),
                          FilledButton(
                            onPressed: _busy ? null : _submit,
                            child: _busy
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Text('إرسال تعليمات الاستعادة'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
