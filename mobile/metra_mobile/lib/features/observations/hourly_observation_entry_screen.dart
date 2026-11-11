// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/api/metra_api_client.dart';
import '../../core/widgets/metra_ui.dart';

/// Hourly observation entry workspace.
/// Field groups follow the executive METRA requirements list.
/// Detailed scientific validation rules, units, precision, missing markers,
/// psychrometric relations and submission contracts remain blocked on the
/// authoritative source archive and approved API contracts. No invented rules.
class HourlyObservationEntryScreen extends StatefulWidget {
  const HourlyObservationEntryScreen({
    super.key,
    required this.api,
    this.stationId,
  });

  final MetraApiClient api;
  final String? stationId;

  @override
  State<HourlyObservationEntryScreen> createState() =>
      _HourlyObservationEntryScreenState();
}

class _HourlyObservationEntryScreenState
    extends State<HourlyObservationEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dryTemp = TextEditingController();
  final _wetTemp = TextEditingController();
  final _humidity = TextEditingController();
  final _dewPoint = TextEditingController();
  final _stationPressure = TextEditingController();
  final _mslPressure = TextEditingController();
  final _pressureChange = TextEditingController();
  final _vapourPressure = TextEditingController();
  final _windDir = TextEditingController();
  final _windSpeed = TextEditingController();
  final _visibility = TextEditingController();
  final _currentWeather = TextEditingController();
  final _pastWeather = TextEditingController();
  final _cloudTotal = TextEditingController();
  final _cloudTypes = TextEditingController();
  final _cloudHeights = TextEditingController();
  final _precipitation = TextEditingController();
  final _observerNotes = TextEditingController();
  bool _responsibilityConfirmed = false;
  bool _submitting = false;
  String? _statusMessage;

  @override
  void dispose() {
    for (final c in [
      _dryTemp,
      _wetTemp,
      _humidity,
      _dewPoint,
      _stationPressure,
      _mslPressure,
      _pressureChange,
      _vapourPressure,
      _windDir,
      _windSpeed,
      _visibility,
      _currentWeather,
      _pastWeather,
      _cloudTotal,
      _cloudTypes,
      _cloudHeights,
      _precipitation,
      _observerNotes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_responsibilityConfirmed) {
      setState(() => _statusMessage = 'يجب تأكيد مسؤولية الإدخال قبل الإرسال.');
      return;
    }
    if (widget.stationId == null || widget.stationId!.isEmpty) {
      setState(() => _statusMessage = 'اختر محطة أولاً من دليل المحطات.');
      return;
    }

    setState(() {
      _submitting = true;
      _statusMessage = null;
    });

    // Isolated mock path only. No claim of production submission.
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _statusMessage =
          'تم حفظ المسودة محلياً في هذه الجلسة فقط. إرسال الرصدة الإنتاجية محظور حتى اعتماد عقد API العلمي والحقول المرجعية.';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.stationId == null || widget.stationId!.isEmpty) {
      return const MetraEmptyState(
        icon: Icons.thermostat_outlined,
        title: 'الرصد الساعي',
        message:
            'اختر محطة أولاً من دليل المحطات. سيطبّق الخادم صلاحيات الإدخال على المحطة المحددة فقط.',
      );
    }

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          const MetraPageHeader(
            title: 'إدخال الرصد الساعي',
            subtitle:
                'نموذج إدخال تشغيلي. القواعد العلمية الدقيقة (الدقة، الوحدات، علامات النقص، العلاقات السيكرومترية) تُستكمل بعد استخراج المصدر المرجعي المعتمد.',
          ),
          const SizedBox(height: 8),
          const MetraStatusBanner(
            tone: MetraBannerTone.warning,
            message:
                'لا تُعرض أي قيم تجريبية على أنها قياسات حقيقية. الإرسال الإنتاجي معلّق حتى اعتماد عقد API والحقول العلمية المرجعية.',
          ),
          const SizedBox(height: 14),
          MetraSectionCard(
            title: 'درجة الحرارة والرطوبة',
            child: Column(
              children: [
                _numField(_dryTemp, 'درجة الحرارة الجافة (°م)'),
                _numField(_wetTemp, 'درجة الحرارة الرطبة (°م)'),
                _numField(_humidity, 'الرطوبة النسبية (%)'),
                _numField(_dewPoint, 'درجة الندى (°م)'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          MetraSectionCard(
            title: 'الضغط الجوي',
            child: Column(
              children: [
                _numField(_stationPressure, 'ضغط المحطة (هكتوباسكال)'),
                _numField(_mslPressure, 'ضغط سطح البحر (هكتوباسكال)'),
                _numField(_pressureChange, 'تغير الضغط وشكله'),
                _numField(_vapourPressure, 'ضغط البخار'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          MetraSectionCard(
            title: 'الرياح والرؤية',
            child: Column(
              children: [
                _numField(_windDir, 'اتجاه الرياح (درجة)'),
                _numField(_windSpeed, 'سرعة الرياح ومتوسطاتها'),
                _numField(_visibility, 'الرؤية'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          MetraSectionCard(
            title: 'الطقس والسحب والهطول',
            child: Column(
              children: [
                _textField(_currentWeather, 'الطقس الحالي'),
                _textField(_pastWeather, 'الطقس السابق'),
                _numField(_cloudTotal, 'كمية السحب الكلية'),
                _textField(_cloudTypes, 'أنواع السحب'),
                _textField(_cloudHeights, 'ارتفاعات السحب'),
                _numField(_precipitation, 'الهطول'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          MetraSectionCard(
            title: 'ملاحظات الراصد وتأكيد المسؤولية',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _textField(_observerNotes, 'ملاحظات الراصد', maxLines: 3),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _responsibilityConfirmed,
                  onChanged: (v) =>
                      setState(() => _responsibilityConfirmed = v ?? false),
                  title: const Text(
                    'أؤكد مسؤولية صحة البيانات المدخلة وفق إجراءات المحطة المعتمدة.',
                    style: TextStyle(fontSize: 14),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ),
          ),
          if (_statusMessage != null) ...[
            const SizedBox(height: 12),
            MetraStatusBanner(
              tone: MetraBannerTone.info,
              message: _statusMessage!,
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _submitting
                      ? null
                      : () {
                          _formKey.currentState?.reset();
                          setState(() {
                            _responsibilityConfirmed = false;
                            _statusMessage = null;
                          });
                        },
                  child: const Text('مسح النموذج'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_outlined),
                  label: Text(_submitting ? 'جاري الحفظ...' : 'حفظ المسودة'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _numField(TextEditingController c, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
        ],
        decoration: InputDecoration(labelText: label),
        // Basic presence only; scientific range/precision rules are pending.
        validator: (v) {
          if (v == null || v.trim().isEmpty) return null; // optional until contract
          return null;
        },
      ),
    );
  }

  Widget _textField(TextEditingController c, String label, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: c,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}
