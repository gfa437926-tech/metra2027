import 'package:flutter/material.dart';

import '../../models/observation_validation.dart';
import '../../services/observation_validation_client.dart';

/// Validates an hourly observation through .NET. It does not save the record.
class HourlyObservationScreen extends StatefulWidget {
  const HourlyObservationScreen({super.key, ObservationValidationClient? validationClient})
      : _providedClient = validationClient;
  final ObservationValidationClient? _providedClient;

  @override
  State<HourlyObservationScreen> createState() => _HourlyObservationScreenState();
}

class _HourlyObservationScreenState extends State<HourlyObservationScreen> {
  late final ObservationValidationClient _client;
  late final bool _ownsClient;
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  String _utcHour = '00';
  DateTime _date = DateTime.now();
  bool _busy = false;
  ObservationValidationResult? _result;
  String? _error;

  static const _baseFields = <(String, String, String)>[
    ('dryTemp', 'الحرارة الجافة', '+00.0'),
    ('wetTemp', 'الحرارة الرطبة', '+00.0'),
    ('stationPressure', 'ضغط المحطة', '1013.2'),
    ('seaLevelPressure', 'الضغط المصحح لمستوى البحر', '1013.2'),
    ('windDirection', 'اتجاه الرياح', '00'),
    ('windSpeed', 'سرعة الرياح', '00'),
    ('visibility', 'مدى الرؤية', '000'),
    ('totalCloudCover', 'التغطية الكلية للسحب', '0'),
    ('relativeHumidity', 'الرطوبة النسبية', '050'),
    ('dewPoint', 'نقطة الندى', '+00.0'),
    ('cover12', 'تغطية الطبقتين الأولى والثانية', '0'),
    ('cover123', 'تغطية الطبقات الثلاث', '0'),
  ];

  static const _optionalFields = <(String, String, String)>[
    ('vaporPressure', 'ضغط البخار', '00.0'),
    ('vaporPressureDiff', 'فرق ضغط البخار', '00.0'),
    ('avgWindDirection', 'متوسط اتجاه الرياح', '00'),
    ('avgWindSpeed', 'متوسط سرعة الرياح', '00'),
    ('currentWeather', 'الطقس الحالي', '00'),
    ('cloud1Amount', 'كمية السحب الأولى', '0'),
    ('cloud2Amount', 'كمية السحب الثانية', '0'),
    ('cloud3Amount', 'كمية السحب الثالثة', '0'),
    ('cloud4Amount', 'كمية السحب الرابعة', '0'),
    ('cloud1Height', 'ارتفاع قاعدة السحب الأولى', '000'),
    ('cloud2Height', 'ارتفاع قاعدة السحب الثانية', '000'),
    ('cloud3Height', 'ارتفاع قاعدة السحب الثالثة', '000'),
  ];

  @override
  void initState() {
    super.initState();
    _client = widget._providedClient ?? ObservationValidationClient();
    _ownsClient = widget._providedClient == null;
    for (final f in [..._baseFields, ..._optionalFields]) {
      _controllers[f.$1] = TextEditingController();
    }
    for (final f in const [
      ('precipitationAmount', 'كمية الهطول', '000.0'),
      ('pressureSlope', 'ميل الضغط', '0.0'),
      ('pressureShape', 'شكل تغير الضغط', '0'),
      ('pastWeather', 'الطقس السابق', '0'),
    ]) {
      _controllers[f.$1] = TextEditingController();
    }
  }

  bool get _synoptic => const {'00','03','06','09','12','15','18','21'}.contains(_utcHour);
  bool get _precipitation => const {'00','06','12','18'}.contains(_utcHour);

  @override
  void dispose() {
    for (final c in _controllers.values) { c.dispose(); }
    if (_ownsClient) _client.close();
    super.dispose();
  }

  Map<String, String?> _payload() {
    final values = <String, String?>{
      'utcTime': _utcHour,
      'observationDate': _date.year.toString().padLeft(4, '0') + '-' +
          _date.month.toString().padLeft(2, '0') + '-' +
          _date.day.toString().padLeft(2, '0'),
    };
    for (final entry in _controllers.entries) {
      final value = entry.value.text.trim();
      if (value.isNotEmpty) values[entry.key] = value;
    }
    return values;
  }

  Future<void> _validate() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() { _busy = true; _result = null; _error = null; });
    try {
      final result = await _client.validateHourly(_payload());
      if (mounted) setState(() => _result = result);
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذر الاتصال بخدمة التحقق: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context, initialDate: _date,
      firstDate: DateTime(2000), lastDate: DateTime(2100),
      helpText: 'تاريخ الرصد',
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = _date.year.toString().padLeft(4, '0') + '-' +
        _date.month.toString().padLeft(2, '0') + '-' +
        _date.day.toString().padLeft(2, '0');
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('إدخال النشرة الساعية')),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('بيانات الرصد', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_month),
                    label: Text('تاريخ الرصد: ' + dateLabel),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _utcHour,
                    decoration: const InputDecoration(
                      labelText: 'ساعة الرصد بالتوقيت العالمي UTC',
                      border: OutlineInputBorder(),
                    ),
                    items: List.generate(24, (i) {
                      final h = i.toString().padLeft(2, '0');
                      return DropdownMenuItem(value: h, child: Text('$h:00 UTC'));
                    }),
                    onChanged: _busy ? null : (v) {
                      if (v != null) setState(() { _utcHour = v; _result = null; });
                    },
                  ),
                ]),
              )),
              const SizedBox(height: 12),
              _section('العناصر الجوية الأساسية', _baseFields),
              _section('العناصر الجوية الإضافية', _optionalFields, required: false),
              if (_synoptic) _section('عناصر الرصد السينوبتيكي — مطلوبة لهذه الساعة', const [
                ('pressureSlope', 'ميل الضغط', '0.0'),
                ('pressureShape', 'شكل تغير الضغط', '0'),
                ('pastWeather', 'الطقس السابق', '0'),
              ]),
              if (_precipitation) _section('الهطول — مطلوب لهذه الساعة', const [
                ('precipitationAmount', 'كمية الهطول', '000.0'),
              ]),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _busy ? null : _validate,
                icon: _busy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.fact_check_outlined),
                label: Text(_busy ? 'جارٍ التحقق...' : 'التحقق من النشرة'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                _notice(_error!, const Color(0xFFFFF0F0), const Color(0xFFB42318)),
              ],
              if (_result != null) ...[
                const SizedBox(height: 12),
                if (_result!.isValid)
                  _notice('النشرة اجتازت التحقق بنجاح. لم يتم حفظها أو إرسالها.',
                      const Color(0xFFEAF7EF), const Color(0xFF16703D))
                else ...[
                  _notice('توجد ' + _result!.issues.length.toString() + ' ملاحظة يجب تصحيحها.',
                      const Color(0xFFFFF6E5), const Color(0xFF8A5A00)),
                  ..._result!.issues.map((issue) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.error_outline, color: Color(0xFFB42318)),
                    title: Text(issue.message),
                    subtitle: Text('الحقل: ' + issue.field),
                  )),
                ],
              ],
              const SizedBox(height: 24),
              const Text(
                'تنبيه: الشاشة تتحقق من القيم عبر واجهة .NET فقط. لا يوجد حفظ مركزي أو اعتماد للمحطة في هذه المرحلة.',
                style: TextStyle(color: Colors.black54, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String title, List<(String, String, String)> fields, {bool required = true}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...fields.map((f) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TextFormField(
              controller: _controllers[f.$1],
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: f.$2, hintText: f.$3,
                border: const OutlineInputBorder(), isDense: true,
              ),
              validator: (v) => required && (v == null || v.trim().isEmpty) ? 'هذا الحقل مطلوب' : null,
              onChanged: (_) { if (_result != null) setState(() => _result = null); },
            ),
          )),
        ]),
      ),
    );
  }

  Widget _notice(String text, Color background, Color foreground) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(10)),
    child: Text(text, style: TextStyle(color: foreground, fontWeight: FontWeight.w600)),
  );
}
