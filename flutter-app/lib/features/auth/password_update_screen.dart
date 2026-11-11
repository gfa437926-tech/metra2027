import 'package:flutter/material.dart';

class MetraPasswordUpdateScreen extends StatefulWidget {
  const MetraPasswordUpdateScreen({
    super.key,
    required this.updatePassword,
    required this.onCancel,
  });

  final Future<void> Function(String password) updatePassword;
  final Future<void> Function() onCancel;

  @override
  State<MetraPasswordUpdateScreen> createState() =>
      _MetraPasswordUpdateScreenState();
}

class _MetraPasswordUpdateScreenState extends State<MetraPasswordUpdateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;
  String? _success;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() { _busy = true; _error = null; _success = null; });
    try {
      await widget.updatePassword(_password.text);
      if (mounted) setState(() => _success = 'تم تحديث كلمة المرور. جارٍ التحقق من حالة الحساب.');
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر تحديث كلمة المرور. قد يكون رابط الاستعادة منتهياً أو غير صالح.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('تعيين كلمة مرور جديدة'),
            actions: [
              TextButton(
                onPressed: _busy ? null : widget.onCancel,
                child: const Text('إلغاء'),
              ),
            ],
          ),
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
                          const Icon(Icons.password_outlined, size: 48),
                          const SizedBox(height: 16),
                          const Text(
                            'أدخل كلمة مرور جديدة ثم أكدها. يجب ألا تقل عن 8 محارف، وسيطبق مزود الهوية أي سياسة أقوى مهيأة لديه.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _password,
                            obscureText: _obscure,
                            autofillHints: const [AutofillHints.newPassword],
                            decoration: InputDecoration(
                              labelText: 'كلمة المرور الجديدة',
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                onPressed: () => setState(() => _obscure = !_obscure),
                                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                              ),
                            ),
                            validator: (value) => (value?.length ?? 0) >= 8
                                ? null
                                : 'كلمة المرور يجب أن تكون 8 محارف على الأقل',
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _confirmation,
                            obscureText: _obscure,
                            autofillHints: const [AutofillHints.newPassword],
                            decoration: const InputDecoration(
                              labelText: 'تأكيد كلمة المرور',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) => value == _password.text
                                ? null
                                : 'كلمتا المرور غير متطابقتين',
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Text(_error!, style: const TextStyle(color: Colors.red)),
                          ],
                          if (_success != null) ...[
                            const SizedBox(height: 12),
                            Text(_success!, style: const TextStyle(color: Colors.green)),
                          ],
                          const SizedBox(height: 18),
                          FilledButton(
                            onPressed: _busy ? null : _submit,
                            child: _busy
                                ? const SizedBox(
                                    height: 20, width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('حفظ كلمة المرور'),
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
