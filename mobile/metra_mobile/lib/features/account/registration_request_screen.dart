import 'package:material_ui/material_ui.dart';

import '../../core/api/metra_api_client.dart';
import '../../core/auth/registration_field_rules.dart';
import '../../core/errors/metra_error_presenter.dart';
import '../../core/theme/metra_theme.dart';
import '../../core/widgets/metra_async_state.dart';

/// Station access registration request — authenticated users only.
/// Fields match `RegistrationSubmissionRequest` on the server.
class RegistrationRequestScreen extends StatefulWidget {
  const RegistrationRequestScreen({super.key, required this.api});

  final MetraApiClient api;

  @override
  State<RegistrationRequestScreen> createState() =>
      _RegistrationRequestScreenState();
}

class _RegistrationRequestScreenState extends State<RegistrationRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _father = TextEditingController();
  final _last = TextEditingController();
  final _phone = TextEditingController();
  final _stationId = TextEditingController();

  List<Map<String, dynamic>> _roles = const [];
  String? _roleCode;
  bool _loadingRoles = true;
  bool _submitting = false;
  bool _terms = false;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    _loadRoles();
  }

  @override
  void dispose() {
    _first.dispose();
    _father.dispose();
    _last.dispose();
    _phone.dispose();
    _stationId.dispose();
    super.dispose();
  }

  Future<void> _loadRoles() async {
    setState(() {
      _loadingRoles = true;
      _error = null;
    });
    try {
      final roles = await widget.api.getRegistrationRoles();
      if (!mounted) return;
      setState(() {
        _roles = roles;
        _loadingRoles = false;
        if (_roles.isNotEmpty) {
          _roleCode =
              (_roles.first['role_code'] ??
                      _roles.first['roleCode'] ??
                      _roles.first['code'])
                  ?.toString();
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingRoles = false;
        _error = MetraErrorPresenter.messageFor(e);
      });
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;
    if (!_terms) {
      setState(() => _error = 'يجب الموافقة على شروط الاستخدام المعتمدة.');
      return;
    }
    if (_roleCode == null || _roleCode!.isEmpty) {
      setState(() => _error = 'اختر الدور المطلوب.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
      _success = null;
    });
    try {
      final key =
          'reg-${DateTime.now().toUtc().millisecondsSinceEpoch}-${_stationId.text.trim()}';
      await widget.api.submitRegistrationRequest(
        firstName: _first.text.trim(),
        fatherName: _father.text.trim(),
        lastName: _last.text.trim(),
        phone: _phone.text.trim(),
        roleCode: _roleCode!,
        stationId: _stationId.text.trim(),
        idempotencyKey: key.length > 128 ? key.substring(0, 128) : key,
      );
      if (!mounted) return;
      setState(() {
        _success = 'تم استلام طلب التسجيل. ستظهر الحالة بعد مراجعة مسؤول المحطة/النظام.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = MetraErrorPresenter.messageFor(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _roleLabel(Map<String, dynamic> row) {
    final code = (row['role_code'] ?? row['roleCode'] ?? row['code'] ?? '')
        .toString();
    final ar = (row['name_ar'] ?? row['nameAr'] ?? '').toString();
    if (ar.isNotEmpty) return '$ar ($code)';
    return code;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Material(
        color: Colors.transparent,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'طلب تسجيل على محطة',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: MetraColors.navy,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'يتطلب حساب مصادقة نشط. الحقول مطابقة لعقد الخادم: الاسم، الأب، العائلة، الهاتف، الدور، المحطة، وقبول الشروط.',
              style: TextStyle(color: MetraColors.muted, height: 1.45),
            ),
            const SizedBox(height: 16),
            if (_loadingRoles)
              MetraAsyncStatePanel.loading(message: 'جاري تحميل الأدوار…')
            else
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _first,
                      decoration: const InputDecoration(
                        labelText: 'الاسم الأول',
                        border: OutlineInputBorder(),
                      ),
                      validator: RegistrationFieldRules.requiredName,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _father,
                      decoration: const InputDecoration(
                        labelText: 'اسم الأب',
                        border: OutlineInputBorder(),
                      ),
                      validator: RegistrationFieldRules.requiredName,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _last,
                      decoration: const InputDecoration(
                        labelText: 'اسم العائلة',
                        border: OutlineInputBorder(),
                      ),
                      validator: RegistrationFieldRules.requiredName,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'الهاتف',
                        border: OutlineInputBorder(),
                        helperText: 'أرقام فقط، 8 محارف على الأقل',
                      ),
                      validator: RegistrationFieldRules.phone,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _stationId,
                      decoration: const InputDecoration(
                        labelText: 'معرف المحطة (UUID)',
                        border: OutlineInputBorder(),
                        helperText: 'استخدم المعرف من دليل المحطات بعد اعتماده',
                      ),
                      validator: RegistrationFieldRules.stationId,
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: _roleCode,
                      decoration: const InputDecoration(
                        labelText: 'الدور المطلوب',
                        border: OutlineInputBorder(),
                      ),
                      items: _roles
                          .map(
                            (r) => DropdownMenuItem(
                              value:
                                  (r['role_code'] ?? r['roleCode'] ?? r['code'])
                                      ?.toString(),
                              child: Text(_roleLabel(r)),
                            ),
                          )
                          .where((e) => e.value != null && e.value!.isNotEmpty)
                          .toList(),
                      onChanged: (v) => setState(() => _roleCode = v),
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      value: _terms,
                      onChanged: (v) => setState(() => _terms = v ?? false),
                      title: const Text(
                        'أوافق على شروط METRA (الإصدار metra-terms-2026-11)',
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: MetraColors.danger),
                        ),
                      ),
                    if (_success != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          _success!,
                          style: const TextStyle(color: MetraColors.success),
                        ),
                      ),
                    FilledButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                      label: Text(
                        _submitting ? 'جاري الإرسال…' : 'إرسال طلب التسجيل',
                      ),
                    ),
                    TextButton(
                      onPressed: _loadingRoles ? null : _loadRoles,
                      child: const Text('تحديث قائمة الأدوار'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Displays registration status from GET /api/v1/account/registration-status.
/// Operator-facing Arabic label for registration request status codes.
String registrationStatusLabel(Object? raw) {
  final s = raw?.toString().toLowerCase() ?? '';
  return switch (s) {
    'pending' ||
    'pending_station_approval' ||
    'pending_system_approval' => 'بانتظار الموافقة',
    'approved' || 'active' => 'معتمد',
    'rejected' || 'denied' => 'مرفوض',
    '' => 'غير محدد',
    _ => raw.toString(),
  };
}

class RegistrationStatusScreen extends StatefulWidget {
  const RegistrationStatusScreen({super.key, required this.api});

  final MetraApiClient api;

  @override
  State<RegistrationStatusScreen> createState() =>
      _RegistrationStatusScreenState();
}

class _RegistrationStatusScreenState extends State<RegistrationStatusScreen> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.getMyRegistrationStatus();
  }

  void _reload() {
    setState(() {
      _future = widget.api.getMyRegistrationStatus();
    });
  }

  String _statusLabel(Object? raw) => registrationStatusLabel(raw);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Material(
        color: Colors.transparent,
        child: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return MetraAsyncStatePanel.loading(
                message: 'جاري تحميل حالة التسجيل…',
              );
            }
            if (snapshot.hasError) {
              return MetraAsyncStatePanel.error(
                title: 'تعذر تحميل حالة التسجيل',
                subtitle: MetraErrorPresenter.messageFor(snapshot.error!),
                onRetry: _reload,
              );
            }
            final data = snapshot.data ?? {};
            final status =
                data['status'] ??
                data['result_status'] ??
                data['approval_status'] ??
                data['state'];
            final reason =
                data['rejection_reason'] ??
                data['reason'] ??
                data['note'] ??
                data['review_note'];
            final role =
                data['requested_role_code'] ??
                data['role_code'] ??
                data['role'] ??
                data['requested_role'];
            final station =
                data['station_id'] ??
                data['requested_station_id'] ??
                data['stationId'];
            final submittedAt =
                data['submitted_at'] ??
                data['created_at'] ??
                data['requested_at'];
            // Never dump the entire response map: may include internal ids or notes.
            final safeDetails = <String, String>{};
            void put(String label, Object? value) {
              if (value == null) return;
              final text = value.toString().trim();
              if (text.isEmpty) return;
              safeDetails[label] = text;
            }

            put('الدور المطلوب', role);
            put('المحطة', station);
            put('تاريخ التقديم', submittedAt);
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'حالة طلب التسجيل',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: MetraColors.navy,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'تُعرض الحقول المعتمدة من الخادم فقط. لا تُنشأ حالات وهمية.',
                  style: TextStyle(color: MetraColors.muted, height: 1.4),
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.assignment_turned_in_outlined),
                    title: const Text('الحالة'),
                    subtitle: Text(_statusLabel(status)),
                  ),
                ),
                if (reason != null && reason.toString().trim().isNotEmpty)
                  Card(
                    color: MetraColors.warningBg,
                    child: ListTile(
                      leading: const Icon(
                        Icons.info_outline,
                        color: MetraColors.warning,
                      ),
                      title: const Text('ملاحظة / سبب'),
                      subtitle: Text(reason.toString()),
                    ),
                  ),
                if (safeDetails.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Card(
                    child: Column(
                      children: [
                        for (final entry in safeDetails.entries)
                          ListTile(
                            dense: true,
                            title: Text(entry.key),
                            subtitle: Text(entry.value),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh),
                  label: const Text('تحديث الحالة'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
