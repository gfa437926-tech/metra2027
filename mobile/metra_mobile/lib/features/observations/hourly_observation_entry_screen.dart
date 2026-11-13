import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/api/metra_api_client.dart';
import '../../core/widgets/metra_ui.dart';

class HourlyObservationEntryScreen extends StatefulWidget {
  const HourlyObservationEntryScreen({
    super.key,
    required this.api,
    this.stationId,
  });

  final MetraApiClient api;
  final String? stationId;

  @override
  State<HourlyObservationEntryScreen> createState() => _HourlyObservationEntryScreenState();
}

class _HourlyObservationEntryScreenState extends State<HourlyObservationEntryScreen> {
  static const _fieldKeys = <String>[
    'dryTemp','wetTemp','dewPoint','relativeHumidity',
    'stationPressure','seaLevelPressure','vaporPressure','vaporPressureDiff',
    'pressureSlope','pressureShape',
    'windDirection','windSpeed','avgWindDirection','avgWindSpeed',
    'visibility','currentWeather','pastWeather',
    'totalCloudCover','cloud1Amount','cloud1Type','cloud1Height',
    'cloud2Amount','cloud2Type','cloud2Height',
    'cloud3Amount','cloud3Type','cloud3Height','cloud4Amount',
    'cover12','cover123','precipitationAmount','observerNotes'
  ];

  static const _alwaysRequired = <String>{
    'dryTemp','wetTemp','stationPressure','seaLevelPressure',
    'windDirection','windSpeed','visibility','totalCloudCover',
    'relativeHumidity','dewPoint','cover12','cover123'
  };

  static const _rules = <String, _FieldRule>{
    'dryTemp': _FieldRule(r'^[+-]\d{2}\.\d$', -20, 50),
    'wetTemp': _FieldRule(r'^[+-]\d{2}\.\d$', -20, 50),
    'dewPoint': _FieldRule(r'^[+-]\d{2}\.\d$', -20, 50),
    'stationPressure': _FieldRule(r'^\d{4}\.\d$', 850, 1050),
    'seaLevelPressure': _FieldRule(r'^\d{4}\.\d$', 0, 1050),
    'relativeHumidity': _FieldRule(r'^\d{3}$', 1, 100),
    'vaporPressure': _FieldRule(r'^\d{2}\.\d$', 0, 99),
    'vaporPressureDiff': _FieldRule(r'^\d{2}\.\d$', 0, 99),
    'windDirection': _FieldRule(r'^\d{2}$', 0, 36),
    'avgWindDirection': _FieldRule(r'^\d{2}$', 0, 36),
    'windSpeed': _FieldRule(r'^\d{2}$', 0, 99),
    'avgWindSpeed': _FieldRule(r'^\d{2}$', 0, 99),
    'visibility': _FieldRule(r'^\d{3}$', 0, 200),
    'currentWeather': _FieldRule(r'^\d{2}$', 0, 99),
    'pastWeather': _FieldRule(r'^\d$', 0, 9),
    'totalCloudCover': _FieldRule(r'^[0-8]$', 0, 8),
    'cloud1Amount': _FieldRule(r'^[0-8]$', 0, 8),
    'cloud2Amount': _FieldRule(r'^[0-8]$', 0, 8),
    'cloud3Amount': _FieldRule(r'^[0-8]$', 0, 8),
    'cloud4Amount': _FieldRule(r'^[0-8]$', 0, 8),
    'cloud1Height': _FieldRule(r'^\d{1,3}$', 0, 999),
    'cloud2Height': _FieldRule(r'^\d{1,3}$', 0, 999),
    'cloud3Height': _FieldRule(r'^\d{1,3}$', 0, 999),
    'cover12': _FieldRule(r'^[0-8]$', 0, 8),
    'cover123': _FieldRule(r'^[0-8]$', 0, 8),
    'pressureSlope': _FieldRule(r'^\d{1,2}\.\d$', 0, 99),
    'pressureShape': _FieldRule(r'^[0-8]$', 0, 8),
    'precipitationAmount': _FieldRule(r'^\d{3}\.\d$', 0, 999.9),
  };

  late final Map<String, TextEditingController> _fields = {
    for (final key in _fieldKeys) key: TextEditingController(),
  };
  final _formKey = GlobalKey<FormState>();
  DateTime _observationDate = DateTime.now().toUtc();
  String? _utcHour;
  bool _responsibilityConfirmed = false;
  bool _submitting = false;
  bool _submitted = false;
  String? _statusMessage;
  String? _idempotencyKey;

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  bool _isSynopticHour => const {'00','03','06','09','12','15','18','21'}.contains(_utcHour);
  bool _isPrecipitationHour => const {'00','06','12','18'}.contains(_utcHour);

  bool _isRequired(String key) {
    if (_alwaysRequired.contains(key)) return true;
    if (_isSynopticHour && const {'pressureSlope','pressureShape','pastWeather'}.contains(key)) return true;
    if (_isPrecipitationHour && key == 'precipitationAmount') return true;
    return false;
  }

  String? _validateField(String key, String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return _isRequired(key) ? 'هذا الحقل مطلوب في ساعة الرصد المحددة.' : null;
    if (value == '#') return null;
    final rule = _rules[key];
    if (rule != null) {
      if (!RegExp(rule.pattern).hasMatch(value)) return 'تنسيق القيمة غير صحيح.';
      final number = double.tryParse(value);
      if (number == null || (rule.minimum != null && number < rule.minimum!) ||
          (rule.maximum != null && number > rule.maximum!)) {
        return 'القيمة خارج المجال المسموح.';
      }
    }
    if (key == 'dryTemp' && _fields['wetTemp']!.text.trim().isNotEmpty &&
        _fields['wetTemp']!.text.trim() != '#') {
      final dry = double.tryParse(value);
      final wet = double.tryParse(_fields['wetTemp']!.text.trim());
      if (dry != null && wet != null && dry < wet) return 'الحرارة الجافة يجب أن تكون أكبر من أو تساوي الرطبة.';
    }
    if (key == 'wetTemp' && _fields['dryTemp']!.text.trim().isNotEmpty &&
        _fields['dryTemp']!.text.trim() != '#') {
      final wet = double.tryParse(value);
      final dry = double.tryParse(_fields['dryTemp']!.text.trim());
      if (dry != null && wet != null && dry < wet) return 'الحرارة الرطبة لا يجوز أن تتجاوز الجافة.';
    }
    return null;
  }

  void _invalidateSubmission() {
    _idempotencyKey = null;
    if (_submitted) setState(() => _submitted = false);
  }

  Future<void> _chooseDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _observationDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().toUtc().add(const Duration(days: 1)),
    );
    if (selected == null) return;
    setState(() {
      _observationDate = DateTime.utc(selected.year, selected.month, selected.day);
      _submitted = false;
      _idempotencyKey = null;
    });
  }

  DateTime? get _observedAt {
    final hour = int.tryParse(_utcHour ?? '');
    if (hour == null) return null;
    return DateTime.utc(_observationDate.year, _observationDate.month, _observationDate.day, hour);
  }

  Future<void> _submit() async {
    if (_submitting || _submitted) return;
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;
    if (!_responsibilityConfirmed) {
      setState(() => _statusMessage = 'يجب تأكيد مسؤولية صحة الرصد قبل الإرسال.');
      return;
    }
    final stationId = widget.stationId;
    final observedAt = _observedAt;
    if (stationId == null || stationId.isEmpty || observedAt == null) {
      setState(() => _statusMessage = 'اختر المحطة وتاريخ الرصد وساعة UTC أولاً.');
      return;
    }

    setState(() {
      _submitting = true;
      _statusMessage = null;
    });
    _idempotencyKey ??= 'hourly-' + DateTime.now().microsecondsSinceEpoch.toString();

    final payload = <String, dynamic>{
      for (final entry in _fields.entries)
        entry.key: entry.value.text.trim().isEmpty ? null : entry.value.text.trim(),
      'utcTime': _utcHour,
      'responsibility_agreed': true,
    };

    try {
      await widget.api.submitObservation(
        stationId: stationId,
        idempotencyKey: _idempotencyKey!,
        observationType: 'hourly',
        observedAt: observedAt,
        payload: payload,
        submit: true,
      );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitted = true;
        _statusMessage = 'استلم الخادم النشرة الساعية بنجاح. اعتمادها النهائي يخضع لمسار المراجعة.';
      });
    } on MetraApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _statusMessage = 'لم يقبل الخادم الإرسال: HTTP ' + error.statusCode.toString() + ' (' + error.code + '). تم الاحتفاظ بالمدخلات.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _statusMessage = 'تعذر الاتصال بالخادم. بقيت البيانات في النموذج ولم يُعلن نجاح الإرسال.';
      });
    }
  }

  Widget _field(String key, String label, {int maxLines = 1, int? maxLength}) {
    final numeric = _rules.containsKey(key);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: _fields[key],
        maxLines: maxLines,
        maxLength: maxLength ?? (numeric ? 8 : 50),
        keyboardType: numeric
            ? const TextInputType.numberWithOptions(decimal: true, signed: true)
            : TextInputType.text,
        inputFormatters: numeric
            ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.+#\-]'))]
            : const [],
        validator: (value) => _validateField(key, value),
        onChanged: (_) => _invalidateSubmission(),
        decoration: InputDecoration(
          labelText: label,
          helperText: numeric ? 'استخدم # عند عدم توفر المعلومة' : null,
        ),
      ),
    );
  }

  String _dateText(DateTime date) =>
      date.year.toString().padLeft(4, '0') + '-' +
      date.month.toString().padLeft(2, '0') + '-' +
      date.day.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final stationId = widget.stationId;
    if (stationId == null || stationId.isEmpty) {
      return const MetraEmptyState(
        icon: Icons.thermostat_outlined,
        title: 'الرصد الساعي',
        message: 'اختر محطة أولاً من دليل المحطات. يطبق الخادم صلاحيات الإدخال على المحطة المحددة فقط.',
      );
    }

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          const MetraPageHeader(
            title: 'إدخال الرصد الساعي',
            subtitle: 'إدخال حقول الرصد وفق العقد العلمي المستخرج. التحقق النهائي يتم أيضاً في .NET قبل الحفظ.',
          ),
          const SizedBox(height: 8),
          const MetraStatusBanner(
            tone: MetraBannerTone.info,
            message: 'تُرسل القيم إلى .NET مع رمز # للقيم غير المتوفرة. لا تُحسب الرطوبة أو نقطة الندى تلقائياً دون جدول سيكرومتري معتمد.',
          ),
          const SizedBox(height: 12),
          MetraSectionCard(
            title: 'التاريخ وساعة الرصد UTC',
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('تاريخ الرصد'),
                  subtitle: Text(_dateText(_observationDate)),
                  trailing: IconButton(
                    onPressed: _submitting || _submitted ? null : _chooseDate,
                    icon: const Icon(Icons.calendar_month_outlined),
                  ),
                ),
                DropdownButtonFormField<String>(
                  value: _utcHour,
                  decoration: const InputDecoration(labelText: 'ساعة الرصد بالتوقيت العالمي'),
                  items: List.generate(24, (hour) {
                    final value = hour.toString().padLeft(2, '0');
                    return DropdownMenuItem(value: value, child: Text(value + ':00 UTC'));
                  }),
                  onChanged: _submitting || _submitted ? null : (value) {
                    setState(() {
                      _utcHour = value;
                      _submitted = false;
                      _idempotencyKey = null;
                    });
                  },
                  validator: (value) => value == null ? 'اختر ساعة UTC.' : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          MetraSectionCard(
            title: 'الحرارة والرطوبة',
            child: Column(children: [
              _field('dryTemp', 'الحرارة الجافة (°م)'),
              _field('wetTemp', 'الحرارة الرطبة (°م)'),
              _field('relativeHumidity', 'الرطوبة النسبية (%)'),
              _field('dewPoint', 'درجة الندى (°م)'),
              _field('vaporPressure', 'ضغط بخار الماء (hPa)'),
              _field('vaporPressureDiff', 'فرق ضغط البخار (hPa)'),
            ]),
          ),
          const SizedBox(height: 12),
          MetraSectionCard(
            title: 'الضغط الجوي',
            child: Column(children: [
              _field('stationPressure', 'ضغط المحطة (hPa)'),
              _field('seaLevelPressure', 'ضغط سطح البحر (hPa)'),
              _field('pressureSlope', 'ميل الضغط'),
              _field('pressureShape', 'شكل تغير الضغط (0–8)'),
            ]),
          ),
          const SizedBox(height: 12),
          MetraSectionCard(
            title: 'الرياح والرؤية والطقس',
            child: Column(children: [
              _field('windDirection', 'اتجاه الرياح السطحية (00–36)'),
              _field('windSpeed', 'سرعة الرياح السطحية (م/ث)'),
              _field('avgWindDirection', 'متوسط اتجاه الرياح (اختياري)'),
              _field('avgWindSpeed', 'متوسط سرعة الرياح (م/ث)'),
              _field('visibility', 'مدى الرؤية (مئات الأمتار)'),
              _field('currentWeather', 'الطقس الحاضر (كود)'),
              _field('pastWeather', 'الطقس الغابر (كود)'),
            ]),
          ),
          const SizedBox(height: 12),
          MetraSectionCard(
            title: 'السحب والتغطية',
            child: Column(children: [
              _field('totalCloudCover', 'التغطية الكلية للسحب (0–8)'),
              _field('cloud1Amount', 'كمية السحب — الطبقة الأولى'),
              _field('cloud1Type', 'نوع السحب — الطبقة الأولى'),
              _field('cloud1Height', 'ارتفاع السحب — الطبقة الأولى (عشرات الأمتار)'),
              _field('cloud2Amount', 'كمية السحب — الطبقة الثانية'),
              _field('cloud2Type', 'نوع السحب — الطبقة الثانية'),
              _field('cloud2Height', 'ارتفاع السحب — الطبقة الثانية (عشرات الأمتار)'),
              _field('cloud3Amount', 'كمية السحب — الطبقة الثالثة'),
              _field('cloud3Type', 'نوع السحب — الطبقة الثالثة'),
              _field('cloud3Height', 'ارتفاع السحب — الطبقة الثالثة (عشرات الأمتار)'),
              _field('cloud4Amount', 'كمية السحب — الطبقة الرابعة'),
              _field('cover12', 'مجموع تغطية الطبقتين 1+2'),
              _field('cover123', 'مجموع تغطية الطبقات 1+2+3'),
            ]),
          ),
          const SizedBox(height: 12),
          MetraSectionCard(
            title: 'الهطول وملاحظات الراصد',
            child: Column(children: [
              _field('precipitationAmount', 'كمية الهطول (mm)'),
              _field('observerNotes', 'ملاحظات الراصد', maxLines: 3, maxLength: 2000),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _responsibilityConfirmed,
                onChanged: _submitting || _submitted ? null : (value) {
                  setState(() {
                    _responsibilityConfirmed = value ?? false;
                    _idempotencyKey = null;
                  });
                },
                title: const Text('أؤكد مسؤولية صحة البيانات المدخلة.'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ]),
          ),
          if (_statusMessage != null) ...[
            const SizedBox(height: 12),
            MetraStatusBanner(tone: _submitted ? MetraBannerTone.success : MetraBannerTone.warning, message: _statusMessage!),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _submitting || _submitted ? null : _submit,
            icon: _submitting
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.cloud_upload_outlined),
            label: Text(_submitting ? 'جاري الإرسال...' : _submitted ? 'تم الإرسال' : 'إرسال الرصد إلى الخادم'),
          ),
        ],
      ),
    );
  }
}

class _FieldRule {
  const _FieldRule(this.pattern, this.minimum, this.maximum);
  final String pattern;
  final double? minimum;
  final double? maximum;
}
