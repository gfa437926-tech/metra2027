import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/api/metra_api_client.dart';
import '../admin/admin_api_messages.dart';

const _registrationTermsVersion = 'metra-terms-2026-11';

/// Registration creates an identity first, then submits a separate pending
/// station/role request. It never grants METRA permissions in the client.
class MetraRegistrationScreen extends StatefulWidget {
  const MetraRegistrationScreen({
    super.key,
    required this.api,
    this.initiallyAuthenticated = false,
    this.createIdentity,
  });

  final MetraApiClient api;
  final bool initiallyAuthenticated;
  final Future<bool> Function(String email, String password)? createIdentity;

  @override
  State<MetraRegistrationScreen> createState() => _MetraRegistrationScreenState();
}

class _MetraRegistrationScreenState extends State<MetraRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _first = TextEditingController();
  final _father = TextEditingController();
  final _last = TextEditingController();
  final _phone = TextEditingController();
  bool _authenticated = false;
  bool _busy = false;
  bool _termsAccepted = false;
  bool _obscure = true;
  String? _error;
  String? _notice;
  String? _stationId;
  String? _roleCode;
  List<StationDirectoryItem> _stations = const [];
  List<Map<String, dynamic>> _roles = const [];
  Map<String, dynamic>? _status;

  @override
  void initState() {
    super.initState();
    _authenticated = widget.initiallyAuthenticated;
    if (_authenticated) _loadRegistrationData();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _first.dispose();
    _father.dispose();
    _last.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _createIdentity() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    final create = widget.createIdentity;
    if (create == null) {
      setState(() => _error = 'إنشاء حساب الهوية غير مهيأ في هذه البيئة.');
      return;
    }
    setState(() { _busy = true; _error = null; _notice = null; });
    try {
      final hasSession = await create(_email.text.trim(), _password.text);
      if (!mounted) return;
      if (hasSession) {
        setState(() => _authenticated = true);
        await _loadRegistrationData();
      } else {
        setState(() => _notice =
            'تم بدء إنشاء حساب الهوية. أكّد بريدك الإلكتروني، ثم سجّل الدخول وافتح طلب الانضمام لإكمال البيانات.');
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر إنشاء حساب الهوية. تحقق من البيانات أو حاول لاحقاً.');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _loadRegistrationData() async {
    setState(() { _busy = true; _error = null; });
    try {
      final results = await Future.wait([
        widget.api.getAllStationDirectory(),
        widget.api.getRequestableRegistrationRoles(),
        widget.api.getMyRegistrationStatus(),
      ]);
      if (!mounted) return;
      final stations = (results[0] as List<StationDirectoryItem>)
          .where((s) => s.approvalStatus == 'approved' &&
              s.operationalStatus == 'active' && !s.isDemo)
          .toList(growable: false);
      setState(() {
        _stations = stations;
        _roles = results[1] as List<Map<String, dynamic>>;
        _status = results[2] as Map<String, dynamic>;
        _stationId = null;
        _roleCode = null;
      });
    } on MetraApiException catch (e) {
      if (mounted) {
        setState(() => _error = adminRegistrationLoadError(e.statusCode));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'تعذر تحميل المحطات والأدوار وحالة الحساب.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool get _canSubmit => _first.text.trim().isNotEmpty &&
      _father.text.trim().isNotEmpty && _last.text.trim().isNotEmpty &&
      _stationId != null && _roleCode != null && _termsAccepted &&
      _stations.any((s) => s.id == _stationId) &&
      _roles.any((r) => (r['role_code'] ?? r['roleCode']) == _roleCode);

  String _idempotencyKey() {
    final random = Random.secure();
    final suffix = List<int>.generate(16, (_) => random.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return 'flutter-registration-${DateTime.now().toUtc().microsecondsSinceEpoch}-$suffix';
  }

  Future<void> _submit() async {
    if (_busy || !_canSubmit) return;
    setState(() { _busy = true; _error = null; _notice = null; });
    try {
      await widget.api.submitRegistrationRequest(
        firstName: _first.text.trim(),
        fatherName: _father.text.trim(),
        lastName: _last.text.trim(),
        phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        roleCode: _roleCode!,
        stationId: _stationId!,
        termsVersion: _registrationTermsVersion,
        idempotencyKey: _idempotencyKey(),
      );
      final status = await widget.api.getMyRegistrationStatus();
      if (mounted) {
        setState(() {
          _status = status;
          _notice = 'استلم الخادم طلب الانضمام. لن تُفعّل الصلاحيات قبل اكتمال مرحلتي الاعتماد.';
        });
      }
    } on MetraApiException catch (e) {
      if (mounted) {
        setState(() => _error = adminRegistrationSubmitError(e.statusCode));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'تعذر إرسال الطلب أو التحقق من إيصال الاستلام.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _stateLabel(String state) => switch (state) {
    'pending' => 'الحساب قيد مراجعة طلب الانضمام',
    'active' => 'الحساب معتمد وفعال',
    'rejected' => 'تم رفض طلب التسجيل',
    'suspended' => 'الحساب موقوف',
    'disabled' => 'الحساب معطل',
    _ => state.isEmpty ? 'لا توجد حالة حساب مسجلة' : state,
  };

  String _requestStateLabel(String state) => switch (state) {
    'pending_station_approval' => 'بانتظار اعتماد رئيس المحطة',
    'pending_system_approval' => 'بانتظار الاعتماد النظامي النهائي',
    'approved' => 'تم اعتماد الطلب',
    'rejected' => 'تم رفض الطلب',
    'returned' => 'أعيد الطلب للمراجعة',
    _ => state,
  };

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('إنشاء الحساب وطلب الانضمام'),
        actions: [IconButton(onPressed: _busy ? null : _loadRegistrationData,
          icon: const Icon(Icons.refresh))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(child: ListTile(
            leading: Icon(Icons.verified_user_outlined),
            title: Text('الهوية لا تمنح صلاحيات تشغيلية'),
            subtitle: Text('يُنشأ حساب الدخول أولاً، ثم يخضع طلب المحطة والدور لمراجعتين منفصلتين. لا يمكن طلب دور مدير النظام من هذا المسار.'),
          )),
          if (_error != null) _message(_error!, isError: true),
          if (_notice != null) _message(_notice!),
          if (!_authenticated) ...[
            Form(key: _formKey, child: Column(children: [
              TextFormField(controller: _email, keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'البريد الإلكتروني'),
                validator: (v) => (v?.trim().contains('@') ?? false) ? null : 'أدخل بريداً صحيحاً'),
              const SizedBox(height: 10),
              TextFormField(controller: _password, obscureText: _obscure,
                decoration: InputDecoration(labelText: 'كلمة المرور (8 أحرف على الأقل)',
                  suffixIcon: IconButton(onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off))),
                validator: (v) => (v?.length ?? 0) >= 8 ? null : 'كلمة المرور قصيرة'),
              const SizedBox(height: 14),
              FilledButton(onPressed: _busy ? null : _createIdentity,
                child: Text(_busy ? 'جارٍ إنشاء الحساب...' : 'إنشاء حساب الدخول')),
            ])),
          ] else ...[
            if (_status != null)
              Card(child: ListTile(
                title: Text(_status?['account_state'] is String
                    ? _stateLabel(_status!['account_state'] as String)
                    : 'لا يوجد حساب تشغيلي مرتبط بعد'),
                subtitle: Text([
                  if (_status?['request_status'] is String)
                    _requestStateLabel(_status!['request_status'] as String),
                  (_status?['review_note'] ?? _status?['state_reason'] ?? '').toString(),
                  if (_status?['submitted_at'] is String)
                    'تاريخ الطلب UTC: ${_status!['submitted_at']}',
                ].where((value) => value.trim().isNotEmpty).join('\n')),
              )),
            if (_status?['account_state'] == null &&
                _status?['request_status'] != 'pending_station_approval' &&
                _status?['request_status'] != 'pending_system_approval') ...[
              const Text('البيانات الشخصية', style: TextStyle(fontWeight: FontWeight.bold)),
              TextField(controller: _first, decoration: const InputDecoration(labelText: 'الاسم الأول'), onChanged: (_) => setState(() {})),
              TextField(controller: _father, decoration: const InputDecoration(labelText: 'اسم الأب'), onChanged: (_) => setState(() {})),
              TextField(controller: _last, decoration: const InputDecoration(labelText: 'اسم العائلة'), onChanged: (_) => setState(() {})),
              TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم الهاتف (اختياري)')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _stationId,
                decoration: const InputDecoration(labelText: 'المحطة المطلوبة'),
                items: _stations.map((s) => DropdownMenuItem(value: s.id,
                  child: Text('${s.nameArabic} — ${s.localCode}', overflow: TextOverflow.ellipsis))).toList(),
                onChanged: _busy ? null : (v) => setState(() => _stationId = v),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _roleCode,
                decoration: const InputDecoration(labelText: 'الدور المطلوب'),
                items: _roles.map((r) {
                  final code = (r['role_code'] ?? r['roleCode'] ?? '').toString();
                  final label = (r['name_ar'] ?? r['nameAr'] ?? code).toString();
                  return DropdownMenuItem(value: code, child: Text(label));
                }).where((item) => item.value?.isNotEmpty == true).toList(),
                onChanged: _busy ? null : (v) => setState(() => _roleCode = v),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                value: _termsAccepted,
                onChanged: _busy ? null : (v) => setState(() => _termsAccepted = v == true),
                title: const Text('أقر بصحة البيانات وأوافق على شروط استخدام METRA وإجراءات التحقق والاعتماد.'),
                subtitle: const Text('إصدار الشروط: metra-terms-2026-11'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              if (_stations.isEmpty) const Text('لا توجد محطات معتمدة وفعالة متاحة للطلب.'),
              if (_roles.isEmpty) const Text('لا توجد أدوار قابلة للطلب حالياً.'),
              FilledButton(onPressed: _busy || !_canSubmit ? null : _submit,
                child: Text(_busy ? 'جارٍ إرسال الطلب...' : 'إرسال طلب الانضمام')),
            ]],
          if (_busy) const LinearProgressIndicator(),
        ],
      ),
    ),
  );

  Widget _message(String text, {bool isError = false}) => Card(
    color: isError ? const Color(0xFFFFEEEE) : const Color(0xFFEAF7EF),
    child: Padding(padding: const EdgeInsets.all(12),
      child: Text(text, style: TextStyle(color: isError ? Colors.red.shade900 : Colors.green.shade900))),
  );
}
