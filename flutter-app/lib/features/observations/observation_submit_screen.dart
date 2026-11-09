import 'dart:math';

import 'package:flutter/material.dart';
import '../../core/api/metra_api_client.dart';
import 'daily_observation_submit_screen.dart';

/// Convert the station's historical UTC+3 clock to the canonical UTC instant.
DateTime hourlyObservedAtForLocalHour(DateTime localDate, int localHour) {
  if (localHour < 0 || localHour > 23) {
    throw ArgumentError.value(localHour, 'localHour', 'Must be between 0 and 23');
  }
  return DateTime.utc(localDate.year, localDate.month, localDate.day)
      .add(Duration(hours: localHour - 3));
}

/// Hourly observation intake using the canonical v1 API field contract.
class ObservationSubmitScreen extends StatefulWidget {
  const ObservationSubmitScreen({
    super.key,
    required this.api,
    required this.stationId,
    this.initialLocalHour,
    this.initialLocalDate,
  });

  final MetraApiClient api;
  final String stationId;
  /// When set (0-23), skips wall-clock hour for deterministic widget tests.
  final int? initialLocalHour;
  final DateTime? initialLocalDate;

  @override
  State<ObservationSubmitScreen> createState() =>
      _ObservationSubmitScreenState();
}

class _ObservationSubmitScreenState extends State<ObservationSubmitScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _dryTemp = TextEditingController();
  final TextEditingController _wetTemp = TextEditingController();
  final TextEditingController _dewPoint = TextEditingController();
  final TextEditingController _stationPressure = TextEditingController();
  final TextEditingController _seaLevelPressure = TextEditingController();
  final TextEditingController _relativeHumidity = TextEditingController();
  final TextEditingController _windDirection = TextEditingController();
  final TextEditingController _windSpeed = TextEditingController();
  final TextEditingController _visibility = TextEditingController();
  final TextEditingController _totalCloudCover = TextEditingController();
  final TextEditingController _cover12 = TextEditingController();
  final TextEditingController _cover123 = TextEditingController();
  final TextEditingController _precipitationAmount = TextEditingController();
  final TextEditingController _pressureSlope = TextEditingController();
  final TextEditingController _pressureShape = TextEditingController();
  final TextEditingController _pastWeather = TextEditingController();
  final Map<String, TextEditingController> _optionalFields = {
    for (final key in <String>[
      'vaporPressure', 'vaporPressureDiff', 'avgWindDirection', 'avgWindSpeed',
      'currentWeather', 'cloud1Amount', 'cloud2Amount', 'cloud3Amount',
      'cloud4Amount', 'cloud1Type', 'cloud2Type', 'cloud3Type',
      'cloud1Height', 'cloud2Height', 'cloud3Height',
    ]) key: TextEditingController(),
  };
  final TextEditingController _remarks = TextEditingController();

  late DateTime _observationDate;
  late int _localHour;
  int get _utcHour => (_localHour - 3 + 24) % 24;
  bool _submitImmediately = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final stationLocalNow = DateTime.now().toUtc().add(const Duration(hours: 3));
    final seededDate = widget.initialLocalDate;
    _observationDate = seededDate != null
        ? DateTime(seededDate.year, seededDate.month, seededDate.day)
        : DateTime(stationLocalNow.year, stationLocalNow.month, stationLocalNow.day);
    final seededHour = widget.initialLocalHour;
    if (seededHour != null) {
      if (seededHour < 0 || seededHour > 23) {
        throw ArgumentError.value(seededHour, 'initialLocalHour');
      }
      _localHour = seededHour;
    } else {
      _localHour = stationLocalNow.hour;
    }
  }

  @override
  void dispose() {
    for (final controller in <TextEditingController>[
      _dryTemp, _wetTemp, _dewPoint, _stationPressure, _seaLevelPressure,
      _relativeHumidity, _windDirection, _windSpeed, _visibility,
      _totalCloudCover, _cover12, _cover123, _precipitationAmount,
      _pressureSlope, _pressureShape, _pastWeather, ..._optionalFields.values, _remarks,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _needsPrecipitation => const {0, 6, 12, 18}.contains(_utcHour);
  bool get _needsSynoptic => const {0, 3, 6, 9, 12, 15, 18, 21}.contains(_utcHour);

  String? _requiredPattern(String? value, String label, String pattern) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return '$label مطلوب؛ استخدم # إذا تعذرت القراءة';
    if (text == '#') return null;
    if (!RegExp(pattern).hasMatch(text)) return '$label بتنسيق غير صحيح';
    return null;
  }

  String? _boundedValue(
    String? value,
    String label,
    String pattern,
    double minimum,
    double maximum,
  ) {
    final error = _requiredPattern(value, label, pattern);
    if (error != null || value!.trim() == '#') return error;
    final number = double.tryParse(value.trim());
    if (number == null || number < minimum || number > maximum) {
      return '$label خارج المجال المسموح';
    }
    return null;
  }

  String? _temperature(String? value, String label) =>
      _boundedValue(value, label, r'^[+-]\d{2}\.\d$', -20, 50);

  String? _twoDigitCode(String? value, String label, {int? maximum}) =>
      _boundedValue(value, label, r'^\d{2}$', 0, (maximum ?? 99).toDouble());

  String? _threeDigitCode(String? value, String label, {int? maximum}) =>
      _boundedValue(value, label, r'^\d{3}$', 0, (maximum ?? 999).toDouble());

  String? _cloudCode(String? value, String label) =>
      _boundedValue(value, label, r'^[0-8]$', 0, 8);

  String _newIdempotencyKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return 'hourly-${bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join()}';
  }

  Future<void> _save() async {
    if (_saving) return;
    final dry = double.tryParse(_dryTemp.text.trim());
    final wet = double.tryParse(_wetTemp.text.trim());
    if (dry != null && wet != null && wet > dry) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الحرارة الرطبة يجب ألا تتجاوز الحرارة الجافة')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final observedAt = hourlyObservedAtForLocalHour(
      _observationDate, _localHour,
    );
    final values = <String, dynamic>{
      'utcTime': observedAt.hour.toString().padLeft(2, '0'),
      'dryTemp': _dryTemp.text.trim(),
      'wetTemp': _wetTemp.text.trim(),
      'dewPoint': _dewPoint.text.trim(),
      'stationPressure': _stationPressure.text.trim(),
      'seaLevelPressure': _seaLevelPressure.text.trim(),
      'relativeHumidity': _relativeHumidity.text.trim(),
      'windDirection': _windDirection.text.trim(),
      'windSpeed': _windSpeed.text.trim(),
      'visibility': _visibility.text.trim(),
      'totalCloudCover': _totalCloudCover.text.trim(),
      'cover12': _cover12.text.trim(),
      'cover123': _cover123.text.trim(),
    };
    if (_needsPrecipitation) {
      values['precipitationAmount'] = _precipitationAmount.text.trim();
    }
    if (_needsSynoptic) {
      values['pressureSlope'] = _pressureSlope.text.trim();
      values['pressureShape'] = _pressureShape.text.trim();
      values['pastWeather'] = _pastWeather.text.trim();
    }
    for (final entry in _optionalFields.entries) {
      final value = entry.value.text.trim();
      if (value.isNotEmpty) values[entry.key] = value;
    }

    try {
      final receipt = await widget.api.submitObservation(
        stationId: widget.stationId,
        idempotencyKey: _newIdempotencyKey(),
        observationType: 'hourly',
        observedAt: observedAt,
        payload: <String, dynamic>{
          'values': values,
          if (_remarks.text.trim().isNotEmpty) 'remarks': _remarks.text.trim(),
        },
        submit: _submitImmediately,
      );
      if (!mounted) return;
      _clearFields();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _submitImmediately
                ? 'تم حفظ النشرة وإرسالها للمراجعة: ${receipt['id']}'
                : 'تم حفظ مسودة النشرة: ${receipt['id']}',
          ),
        ),
      );
    } on MetraApiException catch (error) {
      if (!mounted) return;
      final message = switch (error.statusCode) {
        400 => 'بيانات النشرة غير صالحة؛ راجع الحقول المطلوبة',
        401 => 'يلزم تسجيل الدخول',
        403 => 'ليست لديك صلاحية الإرسال لهذه المحطة',
        409 => 'تعارض مفتاح منع التكرار',
        503 => 'خدمة الرصد غير متاحة حالياً',
        _ => 'تعذر إرسال النشرة (${error.statusCode})',
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } on FormatException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لم يؤكد الخادم حفظ النشرة؛ لم يتم مسح البيانات')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _clearFields() {
    for (final controller in <TextEditingController>[
      _dryTemp, _wetTemp, _dewPoint, _stationPressure, _seaLevelPressure,
      _relativeHumidity, _windDirection, _windSpeed, _visibility,
      _totalCloudCover, _cover12, _cover123, _precipitationAmount,
      _pressureSlope, _pressureShape, _pastWeather, ..._optionalFields.values, _remarks,
    ]) {
      controller.clear();
    }
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    required String? Function(String?) validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        key: ValueKey('hourly-field-$label'),
        controller: controller,
        enabled: !_saving,
        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          helperText: 'أدخل الرمز بالتنسيق المحدد في عقد النشرة',
        ),
        validator: validator,
      ),
    );
  }

  Widget _optionalField(String key, String label) {
    final controller = _optionalFields[key]!;
    String? validator(String? value) {
      final text = value?.trim() ?? '';
      if (text.isEmpty || text == '#') return null;
      switch (key) {
        case 'vaporPressure':
        case 'vaporPressureDiff':
          return _boundedValue(text, label, r'^\d{2}\.\d$', 0, 99);
        case 'avgWindDirection':
          return _twoDigitCode(text, label, maximum: 36);
        case 'avgWindSpeed':
        case 'currentWeather':
          return _twoDigitCode(text, label);
        case 'cloud1Amount':
        case 'cloud2Amount':
        case 'cloud3Amount':
        case 'cloud4Amount':
          return _cloudCode(text, label);
        case 'cloud1Height':
        case 'cloud2Height':
        case 'cloud3Height':
          return _boundedValue(text, label, r'^\d{1,3}$', 0, 999);
        default:
          // The API recognizes cloud type fields but currently defines no
          // field-level code rule; preserve the supplied string unchanged.
          return null;
      }
    }
    return _field(controller, label, validator: validator);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إدخال نشرة ساعية')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('المحطة: ${widget.stationId}',
                style: const TextStyle(color: Color(0xFF64748B))),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _saving ? null : () async {
                final stationLocalNow = DateTime.now().toUtc().add(const Duration(hours: 3));
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _observationDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(stationLocalNow.year, stationLocalNow.month, stationLocalNow.day),
                );
                if (picked != null && mounted) {
                  setState(() => _observationDate = picked);
                }
              },
              icon: const Icon(Icons.calendar_today),
              label: Text('تاريخ الرصد المحلي: ${_observationDate.year.toString().padLeft(4, '0')}-${_observationDate.month.toString().padLeft(2, '0')}-${_observationDate.day.toString().padLeft(2, '0')}'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              key: const ValueKey('hourly-local-hour'),
              initialValue: _localHour,
              decoration: const InputDecoration(
                labelText: 'ساعة الرصد المحلية (UTC+3)',
                border: OutlineInputBorder(),
              ),
              items: List<DropdownMenuItem<int>>.generate(
                24,
                (hour) => DropdownMenuItem<int>(
                  value: hour,
                  child: Text(hour.toString().padLeft(2, '0')),
                ),
              ),
              onChanged: _saving ? null : (hour) {
                if (hour != null) setState(() => _localHour = hour);
              },
            ),
            const SizedBox(height: 8),
            Text('سيُرسل التوقيت العالمي UTC: ${_utcHour.toString().padLeft(2, '0')}:00',
                style: const TextStyle(color: Color(0xFF64748B))),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const ValueKey('open-daily-observation'),
              onPressed: _saving
                  ? null
                  : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => DailyObservationSubmitScreen(
                            api: widget.api,
                            stationId: widget.stationId,
                          ),
                        ),
                      ),
              icon: const Icon(Icons.calendar_month_outlined),
              label: const Text('الانتقال إلى إدخال النشرة اليومية'),
            ),
            const SizedBox(height: 12),
            _field(_dryTemp, 'الحرارة الجافة (مثل +25.0) *',
                validator: (value) => _temperature(value, 'الحرارة الجافة')),
            _field(_wetTemp, 'الحرارة الرطبة (مثل +20.0) *',
                validator: (value) => _temperature(value, 'الحرارة الرطبة')),
            _field(_dewPoint, 'نقطة الندى (مثل +18.5) *',
                validator: (value) => _temperature(value, 'نقطة الندى')),
            _field(_stationPressure, 'ضغط المحطة (مثل 1013.2) *',
                validator: (value) => _boundedValue(value, 'ضغط المحطة', r'^\d{4}\.\d$', 850, 1050)),
            _field(_seaLevelPressure, 'الضغط عند سطح البحر (مثل 1013.2) *',
                validator: (value) => _boundedValue(value, 'ضغط سطح البحر', r'^\d{4}\.\d$', 0, 1050)),
            _field(_relativeHumidity, 'الرطوبة النسبية (ثلاث خانات مثل 065) *',
                validator: (value) =>
                    _boundedValue(value, 'الرطوبة النسبية', r'^\d{3}$', 1, 100)),
            _field(_windDirection, 'اتجاه الرياح (00-36) *',
                validator: (value) => _twoDigitCode(value, 'اتجاه الرياح', maximum: 36)),
            _field(_windSpeed, 'سرعة الرياح (خانتان) *',
                validator: (value) => _twoDigitCode(value, 'سرعة الرياح')),
            _field(_visibility, 'مدى الرؤية (000-200) *',
                validator: (value) => _threeDigitCode(value, 'مدى الرؤية', maximum: 200)),
            _field(_totalCloudCover, 'التغطية الكلية للسحب (0-8) *',
                validator: (value) => _cloudCode(value, 'التغطية الكلية')),
            _field(_cover12, 'تغطية الطبقتين الأولى والثانية (0-8) *',
                validator: (value) => _cloudCode(value, 'تغطية الطبقتين')),
            _field(_cover123, 'تغطية الطبقات الثلاث (0-8) *',
                validator: (value) => _cloudCode(value, 'تغطية الطبقات الثلاث')),
            const Divider(height: 28),
            const Text('عناصر رصد إضافية (اختيارية)',
                style: TextStyle(fontWeight: FontWeight.bold)),
            _optionalField('vaporPressure', 'ضغط البخار (مثل 12.5)'),
            _optionalField('vaporPressureDiff', 'فرق ضغط البخار (مثل 02.5)'),
            _optionalField('avgWindDirection', 'متوسط اتجاه الرياح (00-36)'),
            _optionalField('avgWindSpeed', 'متوسط سرعة الرياح (00-99)'),
            _optionalField('currentWeather', 'الطقس الحالي (00-99)'),
            _optionalField('cloud1Amount', 'كمية السحب الأولى (0-8)'),
            _optionalField('cloud2Amount', 'كمية السحب الثانية (0-8)'),
            _optionalField('cloud3Amount', 'كمية السحب الثالثة (0-8)'),
            _optionalField('cloud4Amount', 'كمية السحب الرابعة (0-8)'),
            _optionalField('cloud1Type', 'نوع السحب الأولى'),
            _optionalField('cloud2Type', 'نوع السحب الثانية'),
            _optionalField('cloud3Type', 'نوع السحب الثالثة'),
            _optionalField('cloud1Height', 'ارتفاع السحب الأولى (0-999)'),
            _optionalField('cloud2Height', 'ارتفاع السحب الثانية (0-999)'),
            _optionalField('cloud3Height', 'ارتفاع السحب الثالثة (0-999)'),
            if (_needsPrecipitation)
              _field(_precipitationAmount, 'كمية الهطول (مثل 000.0) *',
                  validator: (value) => _boundedValue(
                    value, 'كمية الهطول', r'^\d{3}\.\d$', 0, 999.9)),
            if (_needsSynoptic) ...[
              _field(_pressureSlope, 'ميل الضغط (مثل 2.3) *',
                  validator: (value) => _boundedValue(
                    value, 'ميل الضغط', r'^\d{1,2}\.\d$', 0, 99)),
              _field(_pressureShape, 'شكل تغير الضغط (0-8) *',
                  validator: (value) => _cloudCode(value, 'شكل تغير الضغط')),
              _field(_pastWeather, 'الطقس السابق (0-9) *',
                  validator: (value) => _requiredPattern(
                    value, 'الطقس السابق', r'^\d$')),
            ],
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextFormField(
                controller: _remarks,
                enabled: !_saving,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات الراصد (اختياري)',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('إرسال للمراجعة فوراً'),
              subtitle: const Text('عند إيقاف الخيار تُحفظ النشرة كمسودة فقط'),
              value: _submitImmediately,
              onChanged: _saving ? null : (value) {
                setState(() => _submitImmediately = value);
              },
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const ValueKey('hourly-submit'),
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.send),
              label: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ النشرة'),
            ),
          ],
          ),
        ),
      ),
    );
  }
}
