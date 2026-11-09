import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/api/metra_api_client.dart';
import 'daily_observation_contract.dart';

/// Daily observation intake bound to Observation Field Contract v1.
class DailyObservationSubmitScreen extends StatefulWidget {
  const DailyObservationSubmitScreen({
    super.key,
    required this.api,
    required this.stationId,
    this.initialReportType,
    this.initialObservationDate,
  });

  final MetraApiClient api;
  final String stationId;
  /// Deterministic report type for widget tests (24h|06utc|18utc).
  final String? initialReportType;
  final DateTime? initialObservationDate;

  @override
  State<DailyObservationSubmitScreen> createState() =>
      _DailyObservationSubmitScreenState();
}

class _DailyObservationSubmitScreenState
    extends State<DailyObservationSubmitScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {
    for (final field in DailyObservationContract.fields)
      field.key: TextEditingController(),
    'precipitationTrace': TextEditingController(),
  };

  late String _reportType;
  late DateTime _observationDate;
  bool _responsibilityAgreement = false;
  bool _submitImmediately = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final seededType = widget.initialReportType;
    _reportType = seededType != null &&
            DailyObservationContract.reportTypes.containsKey(seededType)
        ? seededType
        : '24h';
    final seededDate = widget.initialObservationDate;
    _observationDate = seededDate?.toUtc() ?? DateTime.now().toUtc();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _idempotencyKey() {
    final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    return 'daily-${bytes.map((v) => v.toRadixString(16).padLeft(2, '0')).join()}';
  }

  DateTime get _observedAt {
    final hour = switch (_reportType) {
      '06utc' => 6,
      '18utc' => 18,
      _ => 0,
    };
    return DateTime.utc(
      _observationDate.year,
      _observationDate.month,
      _observationDate.day,
      hour,
    );
  }

  Map<String, String> _values() {
    final keys = <String>{
      ...DailyObservationContract.requiredFields(_reportType),
      if (_reportType == '24h') 'precipitationTrace',
    };
    return {
      for (final key in keys)
        key: _controllers[key]!.text.trim(),
    };
  }

  Future<void> _save() async {
    if (_saving) return;
    final values = _values();
    final errors = DailyObservationContract.validate(
      _reportType,
      values,
      responsibilityAgreement: _responsibilityAgreement,
    );
    if (errors.isNotEmpty) {
      _formKey.currentState?.validate();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errors.values.first)),
        );
      }
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final receipt = await widget.api.submitObservation(
        stationId: widget.stationId,
        idempotencyKey: _idempotencyKey(),
        observationType: 'daily',
        observedAt: _observedAt,
        payload: {
          'reportType': _reportType,
          'responsibilityAgreement': true,
          'values': values,
        },
        submit: _submitImmediately,
      );
      if (!mounted) return;
      for (final controller in _controllers.values) {
        controller.clear();
      }
      setState(() => _responsibilityAgreement = false);
      final message = _submitImmediately
          ? 'تم حفظ النشرة اليومية وإرسالها للمراجعة: ${receipt['id']}'
          : 'تم حفظ مسودة النشرة اليومية: ${receipt['id']}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } on MetraApiException catch (error) {
      if (!mounted) return;
      final message = switch (error.statusCode) {
        400 => 'رفض الخادم حقول النشرة؛ راجع القيم المدخلة',
        401 => 'يلزم تسجيل الدخول',
        403 => 'ليست لديك صلاحية الإرسال لهذه المحطة',
        409 => 'تعارض مفتاح منع التكرار',
        503 => 'خدمة الرصد غير متاحة حالياً',
        _ => 'تعذر إرسال النشرة (${error.statusCode})',
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } on FormatException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لم يؤكد الخادم حفظ النشرة؛ احتفظنا بالبيانات المدخلة'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(String key, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        key: ValueKey('daily-field-$key'),
        controller: _controllers[key],
        enabled: !_saving,
        keyboardType: TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          helperText: key == 'precipitationTrace'
              ? 'اختياري: T للهطول الأثري'
              : 'أدخل الرمز كما هو؛ استخدم # عند تعذر القراءة',
        ),
        validator: (value) {
          if (key == 'precipitationTrace' &&
              (value == null || value.trim().isEmpty)) {
            return null;
          }
          return DailyObservationContract.validateField(key, value);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = DailyObservationContract.requiredFields(_reportType);
    final dateLabel = '${_observationDate.year.toString().padLeft(4, '0')}-${_observationDate.month.toString().padLeft(2, '0')}-${_observationDate.day.toString().padLeft(2, '0')}';
    return Scaffold(
      appBar: AppBar(title: const Text('إدخال نشرة يومية')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('المحطة: ${widget.stationId}',
                style: const TextStyle(color: Color(0xFF64748B))),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: const ValueKey('daily-report-type'),
              initialValue: _reportType,
              decoration: const InputDecoration(
                labelText: 'نوع النشرة',
                border: OutlineInputBorder(),
              ),
              items: DailyObservationContract.reportTypes.entries
                  .map((entry) => DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ))
                  .toList(),
              onChanged: _saving
                  ? null
                  : (value) {
                      if (value != null) setState(() => _reportType = value);
                    },
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const ValueKey('daily-observation-date'),
              onPressed: _saving
                  ? null
                  : () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _observationDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now().toUtc(),
                      );
                      if (picked != null && mounted) {
                        setState(() => _observationDate = picked);
                      }
                    },
              icon: const Icon(Icons.calendar_today),
              label: Text('تاريخ الرصد UTC: $dateLabel'),
            ),
            const SizedBox(height: 8),
            Text(
              'وقت اعتماد النشرة: ${_observedAt.toIso8601String()}',
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            for (final field in DailyObservationContract.fields)
              if (visible.contains(field.key))
                _field(field.key, field.label),
            if (_reportType == '24h')
              _field('precipitationTrace', 'الهطول الأثري (T/t)'),
            const Divider(height: 24),
            CheckboxListTile(
              key: const ValueKey('daily-responsibility-agreement'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _responsibilityAgreement,
              onChanged: _saving
                  ? null
                  : (value) => setState(
                        () => _responsibilityAgreement = value ?? false,
                      ),
              title: const Text('أقر بصحة البيانات وأتحمل مسؤولية إدخالها'),
              subtitle: const Text('هذا الإقرار إلزامي قبل إرسال أي نشرة يومية'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('إرسال للمراجعة فوراً'),
              subtitle: const Text('عند الإيقاف تُحفظ النشرة كمسودة'),
              value: _submitImmediately,
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _submitImmediately = value),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const ValueKey('daily-submit'),
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.send),
              label: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ النشرة اليومية'),
            ),
          ],
        ),
      ),
    );
  }
}
