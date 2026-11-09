import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/api/metra_api_client.dart';

/// Authenticated registration entry point. The API derives the account identity
/// from the verified JWT; this screen never sends an actor/user identifier.
class RegistrationAccessScreen extends StatefulWidget {
  const RegistrationAccessScreen({super.key, required this.api});
  final MetraApiClient api;

  @override
  State<RegistrationAccessScreen> createState() => _RegistrationAccessScreenState();
}

class _RegistrationAccessScreenState extends State<RegistrationAccessScreen> {
  final _formKey = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _father = TextEditingController();
  final _last = TextEditingController();
  final _phone = TextEditingController();
  late Future<void> _load;
  List<RegistrationRole> _roles = [];
  List<StationDirectoryItem> _stations = [];
  RegistrationStatus? _status;
  String? _roleCode, _stationId, _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load = _loadData();
  }

  @override
  void dispose() {
    _first.dispose();
    _father.dispose();
    _last.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final results = await Future.wait([
      widget.api.getRequestableRegistrationRoles(),
      widget.api.getAllStationDirectory(),
      widget.api.getMyRegistrationStatus(),
    ]);
    _roles = results[0] as List<RegistrationRole>;
    _stations = (results[1] as List<StationDirectoryItem>).where((station) =>
      station.approvalStatus == 'approved' &&
      station.operationalStatus == 'active' &&
      !station.isDemo).toList(growable: false);
    _status = results[2] as RegistrationStatus;
    if (_roles.isNotEmpty && !_roles.any((role) => role.code == _roleCode)) {
      _roleCode = _roles.first.code;
    }
    if (_stations.isNotEmpty && !_stations.any((station) => station.id == _stationId)) {
      _stationId = _stations.first.id;
    }
  }

  String _idempotencyKey() {
    final random = Random.secure();
    return List<int>.generate(32, (_) => random.nextInt(256))
      .map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    if (_roleCode == null || _stationId == null) {
      setState(() => _error = 'لا توجد أدوار أو محطات مؤهلة للتسجيل حالياً.');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      await widget.api.submitRegistration(
        firstName: _first.text.trim(),
        fatherName: _father.text.trim(),
        lastName: _last.text.trim(),
        phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        roleCode: _roleCode!,
        stationId: _stationId!,
        idempotencyKey: _idempotencyKey(),
      );
      await _loadData();
      if (mounted) setState(() => _load = Future<void>.value());
    } on MetraApiException catch (error) {
      if (mounted) {
        setState(() => _error = switch (error.statusCode) {
        400 => 'البيانات أو المحطة أو الدور غير مقبول. راجع الاختيارات.',
        401 => 'انتهت جلسة الدخول. سجّل الدخول مجدداً.',
        409 => 'يوجد طلب تسجيل قائم أو تعارض في حالة الحساب.',
        503 => 'خدمة التسجيل غير متاحة حالياً. حاول لاحقاً.',
        _ => 'تعذر إرسال طلب التسجيل.',
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر الاتصال بخدمة التسجيل.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(title: const Text('التسجيل وحالة الحساب')),
      body: FutureBuilder<void>(
        future: _load,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Padding(padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('تعذر تحميل بيانات التسجيل والمحطات.'),
                const SizedBox(height: 12),
                FilledButton(onPressed: () => setState(() => _load = _loadData()),
                  child: const Text('إعادة المحاولة')),
              ])));
          }
          return ListView(padding: const EdgeInsets.all(18), children: [
            _statusCard(),
            const SizedBox(height: 16),
            if (_status?.requestId != null && _status?.requestStatus != 'rejected')
              const Card(child: Padding(padding: EdgeInsets.all(16),
                child: Text('يوجد طلب تسجيل مسجل لهذا الحساب. تابع حالة المراجعة أعلاه؛ لا ترسل طلباً مكرراً.')))
            else
              _registrationForm(),
          ]);
        },
      ),
    ),
  );

  Widget _statusCard() {
    final status = _status;
    final state = status?.accountState ?? 'لا يوجد طلب تسجيل';
    final request = status?.requestStatus ?? 'غير مقدم';
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('حالة الحساب', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        _statusLine('حالة الحساب', state),
        _statusLine('حالة الطلب', request),
        if (status?.submittedAt != null)
          _statusLine('تاريخ الإرسال', status!.submittedAt!.toLocal().toString()),
        if ((status?.reviewNote ?? '').isNotEmpty)
          _statusLine('ملاحظة المراجع', status!.reviewNote!),
        if ((status?.stateReason ?? '').isNotEmpty)
          _statusLine('التوضيح', status!.stateReason!),
      ],
    )));
  }

  Widget _statusLine(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 112, child: Text(label, style: const TextStyle(color: Colors.black54))),
      Expanded(child: Text(value)),
    ]),
  );

  Widget _registrationForm() => Card(child: Padding(padding: const EdgeInsets.all(16),
    child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('طلب انتساب أو تحديث الطلب المرفوض',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 14),
        _nameField(_first, 'الاسم الأول'),
        _nameField(_father, 'اسم الأب'),
        _nameField(_last, 'الكنية'),
        TextFormField(controller: _phone, keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'رقم الهاتف (اختياري)', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _roleCode,
          decoration: const InputDecoration(labelText: 'الدور المطلوب', border: OutlineInputBorder()),
          items: _roles.map((role) => DropdownMenuItem(value: role.code,
            child: Text(role.nameArabic))).toList(),
          onChanged: (value) => setState(() => _roleCode = value),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _stationId,
          decoration: const InputDecoration(labelText: 'المحطة', border: OutlineInputBorder()),
          items: _stations.map((station) => DropdownMenuItem(value: station.id,
            child: Text('${station.nameArabic} — ${station.localCode}',
              overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (value) => setState(() => _stationId = value),
        ),
        if (_stations.isEmpty)
          const Padding(padding: EdgeInsets.only(top: 8),
            child: Text('لا توجد محطات معتمدة ونشطة متاحة للتسجيل حالياً.')),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: Colors.red)),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _busy || _roles.isEmpty || _stations.isEmpty ? null : _submit,
          icon: _busy ? const SizedBox(width: 18, height: 18,
            child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send),
          label: Text(_busy ? 'جارٍ الإرسال...' : 'إرسال طلب التسجيل'),
        ),
        const SizedBox(height: 8),
        const Text('يُرسل الطلب عبر API الموثق. لا يرسل التطبيق هوية المنفذ؛ يستخرجها الخادم من JWT.',
          style: TextStyle(fontSize: 12, color: Colors.black54)),
      ],
    ))));

  Widget _nameField(TextEditingController controller, String label) =>
    Padding(padding: const EdgeInsets.only(bottom: 12), child: TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      validator: (value) => value == null || value.trim().isEmpty
        ? 'هذا الحقل مطلوب' : value.trim().length > 120 ? 'الحد الأقصى 120 حرفاً' : null,
    ));
}
