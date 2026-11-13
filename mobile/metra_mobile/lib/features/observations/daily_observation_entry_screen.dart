import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/api/metra_api_client.dart';
import '../../core/widgets/metra_ui.dart';

class DailyObservationEntryScreen extends StatefulWidget {
  const DailyObservationEntryScreen({
    super.key,
    required this.api,
    this.stationId,
  });

  final MetraApiClient api;
  final String? stationId;

  @override
  State<DailyObservationEntryScreen> createState() => _DailyObservationEntryScreenState();
}

class _DailyObservationEntryScreenState extends State<DailyObservationEntryScreen> {
  static const _fieldKeys = <String>[
    'minTemp','maxTemp','precipitation','snowThickness','precipitationTrace',
    'evaporation','sunshineDuration','sunshinePercentage',
    'maxGustSpeed','maxGustDirection','maxGustTime',
    'maxHumidity','maxHumidityTime','minHumidity','minHumidityTime','observerNotes'
  ];

  static const _required24h = <String>{
    'minTemp','maxTemp','precipitation','snowThickness',
    'evaporation','sunshineDuration','sunshinePercentage',
    'maxGustSpeed','maxGustDirection','maxGustTime',
    'maxHumidity','maxHumidityTime','minHumidity','minHumidityTime'
  };

  static const _rules = <String, _DailyFieldRule>{
    'minTemp': _DailyFieldRule(r'^-?\d{2}\.\d$', -20, 50),
    'maxTemp': _DailyFieldRule(r'^-?\d{2}\.\d$', -20, 50),
    'precipitation': _DailyFieldRule(r'^\d{3}\.\d$', 0, 999.9),
    'snowThickness': _DailyFieldRule(r'^\d{3}$', 0, 999),
    'evaporation': _DailyFieldRule(r'^\d{2}\.\d$', 0, 99.9),
    'sunshineDuration': _DailyFieldRule(r'^\d{2}\.\d$', 0, 24),
    'sunshinePercentage': _DailyFieldRule(r'^\d{3}$', 0, 100),
    'maxGustSpeed': _DailyFieldRule(r'^\d{2}$', 0, 36),
    'maxGustDirection': _DailyFieldRule(r'^\d{2}$', 0, 36),
    'maxGustTime': _DailyFieldRule(r'^\d{2}\.\d$', 0, 23.9),
    'maxHumidity': _DailyFieldRule(r'^\d{3}$', 0, 100),
    'maxHumidityTime': _DailyFieldRule(r'^\d{2}\.\d$', 0, 23.9),
    'minHumidity': _DailyFieldRule(r'^\d{2}$', 0, 99),
    'minHumidityTime': _DailyFieldRule(r'^\d{2}\.\d$', 0, 23.9),
  };

  late final Map<String, TextEditingController> _fields = {
    for (final key in _fieldKeys) key: TextEditingController(),
  };
  final _formKey = GlobalKey<FormState>();
  final Map<String, bool> _phenomena = {
    'thunderstorm': false,
    'hail': false,
    'snow': false,
    'rain': false,
    'frost': false,
    'fog': false,
    'mist': false,
    'dustStorm': false,
    'blowing_dust': false,
    'haze': false,
    'stormyWind': false,
  };
  DateTime _reportDate = DateTime.now().toUtc();
  String _reportType = '24h';
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

  String? _validateField(String key, String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return _required24h.contains(key) ? 'هذا الحقل مطلوب في تقرير 24 ساعة.' : null;
    if (value == '#') return null;
    if (key == 'precipitationTrace') {
      return RegExp(r'^[Tt]$').hasMatch(value) ? null : 'أدخل T أو اترك الحقل فارغاً.';
    }
    final rule = _rules[key];
    if (rule != null) {
      if (!RegExp(rule.pattern).hasMatch(value)) return 'تنسيق القيمة غير صحيح.';
      final number = double.tryParse(value);
      if (number == null || number < rule.minimum || number > rule.maximum) {
        return 'القيمة خارج المجال المسموح.';
      }
    }
    if (key == 'minTemp' && _fields['maxTemp']!.text.trim().isNotEmpty &&
        _fields['maxTemp']!.text.trim() != '#') {
      final min = double.tryParse(value);
      final max = double.tryParse(_fields['maxTemp']!.text.trim());
      if (min != null && max != null && max < min) return 'العظمى يجب أن تكون أكبر من أو تساوي الصغرى.';
    }
    if (key == 'maxTemp' && _fields['minTemp']!.text.trim().isNotEmpty &&
        _fields['minTemp']!.text.trim() != '#') {
      final max = double.tryParse(value);
      final min = double.tryParse(_fields['minTemp']!.text.trim());
      if (min != null && max != null && max < min) return 'العظمى يجب أن تكون أكبر من أو تساوي الصغرى.';
    }
    if (key == 'minHumidity' && _fields['maxHumidity']!.text.trim().isNotEmpty &&
        _fields['maxHumidity']!.text.trim() != '#') {
      final min = double.tryParse(value);
      final max = double.tryParse(_fields['maxHumidity']!.text.trim());
      if (min != null && max != null && min > max) return 'الرطوبة الصغرى لا يجوز أن تتجاوز العظمى.';
    }
    if (key == 'maxHumidity' && _fields['minHumidity']!.text.trim().isNotEmpty &&
        _fields['minHumidity']!.text.trim() != '#') {
      final max = double.tryParse(value);
      final min = double.tryParse(_fields['minHumidity']!.text.trim());
      if (min != null && max != null && min > max) return 'الرطوبة الصغرى لا يجوز أن تتجاوز العظمى.';
    }
    return null;
  }

  void _invalidateSubmission() {
    _idempotencyKey = null;
    if (_submitted) setState(() => _submitted = false);
  }

  String _dateText(DateTime date) =>
      date.year.toString().padLeft(4, '0') + '-' +
      date.month.toString().padLeft(2, '0') + '-' +
      date.day.toString().padLeft(2, '0');

  Future<void> _chooseDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _reportDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().toUtc().add(const Duration(days: 1)),
    );
    if (selected == null) return;
    setState(() {
      _reportDate = DateTime.utc(selected.year, selected.month, selected.day);
      _submitted = false;
      _idempotencyKey = null;
    });
  }

  Future<void> _submit() async {
    if (_submitting || _submitted) return;
    if (_reportType != '24h') {
      setState(() => _statusMessage = 'تقارير 06 و18 UTC متوقفة حتى اعتماد تعارض الحقول المرجعية.');
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_responsibilityConfirmed) {
      setState(() => _statusMessage = 'يجب تأكيد مسؤولية صحة البيانات اليومية قبل الإرسال.');
      return;
    }
    final stationId = widget.stationId;
    if (stationId == null || stationId.isEmpty) {
      setState(() => _statusMessage = 'اختر محطة أولاً من دليل المحطات.');
      return;
    }

    final observedAt = DateTime.utc(_reportDate.year, _reportDate.month, _reportDate.day);
    setState(() {
      _submitting = true;
      _statusMessage = null;
    });
    _idempotencyKey ??= 'daily-' + DateTime.now().microsecondsSinceEpoch.toString();

    final payload = <String, dynamic>{
      for (final entry in _fields.entries)
        entry.key: entry.value.text.trim().isEmpty ? null : entry.value.text.trim(),
      'reportType': _reportType,
      'responsibility_agreed': true,
      'weatherPhenomena': _phenomena.entries.where((entry) => entry.value).map((entry) => entry.key).toList(),
    };

    try {
      await widget.api.submitObservation(
        stationId: stationId,
        idempotencyKey: _idempotencyKey!,
        observationType: 'daily',
        observedAt: observedAt,
        payload: payload,
        submit: true,
      );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitted = true;
        _statusMessage = 'استلم الخادم التقرير اليومي بنجاح. اعتماد التقرير النهائي يخضع لمسار المراجعة.';
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
        maxLength: maxLength ?? (numeric ? 8 : 200),
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

  @override
  Widget build(BuildContext context) {
    final stationId = widget.stationId;
    if (stationId == null || stationId.isEmpty) {
      return const MetraEmptyState(
        icon: Icons.calendar_today_outlined,
        title: 'الرصد اليومي',
        message: 'اختر محطة أولاً من دليل المحطات. يطبق الخادم صلاحيات الإدخال على المحطة المحددة فقط.',
      );
    }

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          const MetraPageHeader(
            title: 'إدخال الرصد اليومي',
            subtitle: 'إدخال التقرير اليومي 24 ساعة وفق الحقول العلمية المستخرجة. التحقق النهائي يتم في .NET قبل الحفظ.',
          ),
          const SizedBox(height: 8),
          const MetraStatusBanner(
            tone: MetraBannerTone.warning,
            message: 'تقريرا 06 و18 UTC غير متاحين مؤقتاً بسبب تعارض موثق في المصدر القديم. لا يتم إسقاط حقول الهطول أو الثلج بالتخمين.',
          ),
          const SizedBox(height: 12),
          MetraSectionCard(
            title: 'التاريخ ونوع التقرير',
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('تاريخ التقرير'),
                  subtitle: Text(_dateText(_reportDate) + ' UTC'),
                  trailing: IconButton(
                    onPressed: _submitting || _submitted ? null : _chooseDate,
                    icon: const Icon(Icons.calendar_month_outlined),
                  ),
                ),
                DropdownButtonFormField<String>(
                  initialValue: _reportType,
                  decoration: const InputDecoration(labelText: 'نوع التقرير'),
                  items: const [
                    DropdownMenuItem(value: '24h', child: Text('24 ساعة')),
                    DropdownMenuItem(value: '06utc', enabled: false, child: Text('06 UTC — متوقف لحين اعتماد العقد')),
                    DropdownMenuItem(value: '18utc', enabled: false, child: Text('18 UTC — متوقف لحين اعتماد العقد')),
                  ],
                  onChanged: _submitting || _submitted ? null : (value) {
                    if (value == null) return;
                    setState(() {
                      _reportType = value;
                      _submitted = false;
                      _idempotencyKey = null;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          MetraSectionCard(
            title: 'درجات الحرارة',
            child: Column(children: [
              _field('minTemp', 'درجة الحرارة الصغرى (°م)'),
              _field('maxTemp', 'درجة الحرارة العظمى (°م)'),
            ]),
          ),
          const SizedBox(height: 12),
          MetraSectionCard(
            title: 'الهطول والثلوج',
            child: Column(children: [
              _field('precipitation', 'كمية الهطول (mm)'),
              _field('snowThickness', 'أكبر سماكة للثلج (cm)'),
              _field('precipitationTrace', 'أثر الهطول (T أو فارغ)'),
            ]),
          ),
          const SizedBox(height: 12),
          MetraSectionCard(
            title: 'الظواهر الجوية',
            child: Column(children: _phenomena.entries.map((entry) {
              const labels = <String, String>{
                'thunderstorm': 'عواصف رعدية','hail': 'برد','snow': 'ثلج',
                'rain': 'مطر','frost': 'صقيع','fog': 'ضباب','mist': 'شابورة',
                'dustStorm': 'عاصفة ترابية/رملية','blowing_dust': 'غبار متصاعد',
                'haze': 'سديم','stormyWind': 'رياح عاصفة',
              };
              return CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: entry.value,
                onChanged: _submitting || _submitted ? null : (value) {
                  setState(() {
                    _phenomena[entry.key] = value ?? false;
                    _idempotencyKey = null;
                    _submitted = false;
                  });
                },
                title: Text(labels[entry.key] ?? entry.key),
                controlAffinity: ListTileControlAffinity.leading,
              );
            }).toList()),
          ),
          const SizedBox(height: 12),
          MetraSectionCard(
            title: 'التبخر وسطوع الشمس',
            child: Column(children: [
              _field('evaporation', 'مجموع التبخر اليومي (mm)'),
              _field('sunshineDuration', 'مدة سطوع الشمس (ساعة)'),
              _field('sunshinePercentage', 'نسبة سطوع الشمس (%)'),
            ]),
          ),
          const SizedBox(height: 12),
          MetraSectionCard(
            title: 'الرياح',
            child: Column(children: [
              _field('maxGustSpeed', 'سرعة أكبر هبة (م/ث)'),
              _field('maxGustDirection', 'اتجاه أكبر هبة'),
              _field('maxGustTime', 'وقت أكبر هبة UTC'),
            ]),
          ),
          const SizedBox(height: 12),
          MetraSectionCard(
            title: 'الرطوبة',
            child: Column(children: [
              _field('maxHumidity', 'الرطوبة العظمى (%)'),
              _field('maxHumidityTime', 'وقت الرطوبة العظمى UTC'),
              _field('minHumidity', 'الرطوبة الصغرى (%)'),
              _field('minHumidityTime', 'وقت الرطوبة الصغرى UTC'),
            ]),
          ),
          const SizedBox(height: 12),
          MetraSectionCard(
            title: 'ملاحظات الراصد وتأكيد المسؤولية',
            child: Column(children: [
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
                title: const Text('أؤكد مسؤولية صحة البيانات اليومية المدخلة.'),
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
            label: Text(_submitting ? 'جاري الإرسال...' : _submitted ? 'تم الإرسال' : 'إرسال التقرير إلى الخادم'),
          ),
        ],
      ),
    );
  }
}

class _DailyFieldRule {
  const _DailyFieldRule(this.pattern, this.minimum, this.maximum);
  final String pattern;
  final double minimum;
  final double maximum;
}
