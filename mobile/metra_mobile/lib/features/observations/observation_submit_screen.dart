import 'package:flutter/material.dart';
import '../../core/api/metra_api_client.dart';

/// Hourly observation intake against the real station-scoped submit API.
class ObservationSubmitScreen extends StatefulWidget {
  const ObservationSubmitScreen({
    super.key,
    required this.api,
    required this.stationId,
  });

  final MetraApiClient api;
  final String stationId;

  @override
  State<ObservationSubmitScreen> createState() =>
      _ObservationSubmitScreenState();
}

class _ObservationSubmitScreenState extends State<ObservationSubmitScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _dryTemp = TextEditingController();
  final TextEditingController _wetTemp = TextEditingController();
  final TextEditingController _windSpeed = TextEditingController();
  final TextEditingController _windDirection = TextEditingController();
  final TextEditingController _relativeHumidity = TextEditingController();
  final TextEditingController _stationPressure = TextEditingController();
  final TextEditingController _visibility = TextEditingController();
  final TextEditingController _cloudCover = TextEditingController();
  final TextEditingController _remarks = TextEditingController();
  bool _submitImmediately = true;
  bool _saving = false;

  @override
  void dispose() {
    _dryTemp.dispose();
    _wetTemp.dispose();
    _windSpeed.dispose();
    _windDirection.dispose();
    _relativeHumidity.dispose();
    _stationPressure.dispose();
    _visibility.dispose();
    _cloudCover.dispose();
    _remarks.dispose();
    super.dispose();
  }

  String? _validateTemp(String? value, String label) {
    final String text = value?.trim() ?? '';
    if (text.isEmpty) {
      return '$label مطلوب';
    }
    final double? number = double.tryParse(text.replaceAll('+', ''));
    if (number == null) {
      return '$label يجب أن يكون رقماً';
    }
    if (number < -90 || number > 60) {
      return '$label خارج المدى المسموح (-90..60)';
    }
    return null;
  }

  String? _validateOptionalNumber(
    String? value, {
    required String label,
    required double min,
    required double max,
  }) {
    final String text = value?.trim() ?? '';
    if (text.isEmpty) {
      return null;
    }
    final double? number = double.tryParse(text);
    if (number == null) {
      return '$label يجب أن يكون رقماً';
    }
    if (number < min || number > max) {
      return '$label خارج المدى ($min..$max)';
    }
    return null;
  }

  String? _validateCrossField() {
    final double? dry = double.tryParse(_dryTemp.text.trim().replaceAll('+', ''));
    final double? wet = double.tryParse(_wetTemp.text.trim().replaceAll('+', ''));
    if (dry != null && wet != null && wet > dry) {
      return 'الحرارة الرطبة لا يجوز أن تتجاوز الجافة';
    }
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) {
      return;
    }
    final String? cross = _validateCrossField();
    if (cross != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(cross)));
      return;
    }
    setState(() => _saving = true);
    final String idempotencyKey =
        'hourly-${widget.stationId}-${DateTime.now().toUtc().millisecondsSinceEpoch}';
    try {
      await widget.api.submitObservation(
        stationId: widget.stationId,
        idempotencyKey: idempotencyKey,
        observationType: 'hourly',
        observedAt: DateTime.now().toUtc(),
        payload: <String, dynamic>{
          'dryTemp': _dryTemp.text.trim(),
          'wetTemp': _wetTemp.text.trim(),
          'windSpeed': _windSpeed.text.trim(),
          'windDirection': _windDirection.text.trim(),
          'relativeHumidity': _relativeHumidity.text.trim(),
          'stationPressure': _stationPressure.text.trim(),
          'visibility': _visibility.text.trim(),
          'cloudCover': _cloudCover.text.trim(),
          'remarks': _remarks.text.trim(),
        },
        submit: _submitImmediately,
      );
      if (!mounted) {
        return;
      }
      _dryTemp.clear();
      _wetTemp.clear();
      _windSpeed.clear();
      _windDirection.clear();
      _relativeHumidity.clear();
      _stationPressure.clear();
      _visibility.clear();
      _cloudCover.clear();
      _remarks.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _submitImmediately
                ? 'تم إرسال النشرة للمراجعة'
                : 'تم حفظ مسودة النشرة',
          ),
        ),
      );
    } on MetraApiException catch (error) {
      if (!mounted) {
        return;
      }
      final String message = switch (error.statusCode) {
        400 => 'بيانات النشرة غير صالحة',
        401 => 'يلزم تسجيل الدخول',
        403 => 'ليست لديك صلاحية الإرسال لهذه المحطة',
        409 => 'تعارض مفتاح منع التكرار',
        503 => 'خدمة الرصد غير متاحة حالياً',
        _ => 'تعذر إرسال النشرة (${error.statusCode})',
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        enabled: !_saving,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: validator,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إدخال نشرة ساعية')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Text(
              'المحطة: ${widget.stationId}',
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            _field(
              _dryTemp,
              'الحرارة الجافة (°م) *',
              validator: (String? value) => _validateTemp(value, 'الحرارة الجافة'),
            ),
            _field(
              _wetTemp,
              'الحرارة الرطبة (°م) *',
              validator: (String? value) => _validateTemp(value, 'الحرارة الرطبة'),
            ),
            _field(
              _relativeHumidity,
              'الرطوبة النسبية %',
              validator: (String? value) => _validateOptionalNumber(
                value,
                label: 'الرطوبة',
                min: 0,
                max: 100,
              ),
            ),
            _field(
              _windDirection,
              'اتجاه الرياح (درجة)',
              validator: (String? value) => _validateOptionalNumber(
                value,
                label: 'اتجاه الرياح',
                min: 0,
                max: 360,
              ),
            ),
            _field(
              _windSpeed,
              'سرعة الرياح',
              validator: (String? value) => _validateOptionalNumber(
                value,
                label: 'سرعة الرياح',
                min: 0,
                max: 150,
              ),
            ),
            _field(
              _stationPressure,
              'ضغط المحطة (هكتوباسكال)',
              validator: (String? value) => _validateOptionalNumber(
                value,
                label: 'ضغط المحطة',
                min: 800,
                max: 1100,
              ),
            ),
            _field(
              _visibility,
              'الرؤية الأفقية (كم)',
              validator: (String? value) => _validateOptionalNumber(
                value,
                label: 'الرؤية',
                min: 0,
                max: 70,
              ),
            ),
            _field(
              _cloudCover,
              'الغطاء السحابي (أوكتا 0-8)',
              validator: (String? value) => _validateOptionalNumber(
                value,
                label: 'الغطاء السحابي',
                min: 0,
                max: 8,
              ),
            ),
            _field(_remarks, 'ملاحظات الراصد', maxLines: 3),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('إرسال للمراجعة فوراً'),
              subtitle: const Text('إذا أُوقف الحفظ كمسودة فقط'),
              value: _submitImmediately,
              onChanged: _saving
                  ? null
                  : (bool value) {
                      setState(() => _submitImmediately = value);
                    },
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.send),
              label: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ النشرة'),
            ),
          ],
        ),
      ),
    );
  }
}
