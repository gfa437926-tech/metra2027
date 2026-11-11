// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/api/metra_api_client.dart';
import '../../core/widgets/metra_ui.dart';

/// Daily observation entry workspace (not a reports query screen).
/// Field groups follow the executive requirements. Scientific rules and
/// production submission remain blocked on authoritative sources and API contracts.
class DailyObservationEntryScreen extends StatefulWidget {
  const DailyObservationEntryScreen({
    super.key,
    required this.api,
    this.stationId,
  });

  final MetraApiClient api;
  final String? stationId;

  @override
  State<DailyObservationEntryScreen> createState() =>
      _DailyObservationEntryScreenState();
}

class _DailyObservationEntryScreenState
    extends State<DailyObservationEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _maxTemp = TextEditingController();
  final _minTemp = TextEditingController();
  final _precipitation = TextEditingController();
  final _snow = TextEditingController();
  final _evaporation = TextEditingController();
  final _sunshine = TextEditingController();
  final _gusts = TextEditingController();
  final _maxHumidity = TextEditingController();
  final _minHumidity = TextEditingController();
  final _notes = TextEditingController();
  final _referencePeriod = TextEditingController();
  bool _responsibilityConfirmed = false;
  bool _submitting = false;
  String? _statusMessage;

  @override
  void dispose() {
    for (final c in [
      _maxTemp,
      _minTemp,
      _precipitation,
      _snow,
      _evaporation,
      _sunshine,
      _gusts,
      _maxHumidity,
      _minHumidity,
      _notes,
      _referencePeriod,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_responsibilityConfirmed) {
      setState(() => _statusMessage = 'يجب تأكيد مسؤولية الإدخال قبل الحفظ.');
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
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _statusMessage =
          'تم حفظ المسودة محلياً في هذه الجلسة. الإرسال الإنتاجي معلّق حتى اعتماد عقد الإدخال اليومي والحقول المرجعية.';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.stationId == null || widget.stationId!.isEmpty) {
      return const MetraEmptyState(
        icon: Icons.calendar_today_outlined,
        title: 'الرصد اليومي',
        message:
            'اختر محطة أولاً من دليل المحطات. هذه شاشة إدخال يومي حقيقية وليست شاشة استعلام تقارير.',
      );
    }

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          const MetraPageHeader(
            title: 'إدخال الرصد اليومي',
            subtitle:
                'نموذج إدخال يومي تشغيلي. قواعد التجميع والدقة والفترات المرجعية تُستكمل بعد اعتماد المصدر المرجعي.',
          ),
          const SizedBox(height: 8),
          const MetraStatusBanner(
            tone: MetraBannerTone.warning,
            message:
                'لا تُعرض بيانات تجريبية كقياسات حقيقية. الإنتاج معلّق حتى اعتماد العقود العلمية وAPI.',
          ),
          const SizedBox(height: 14),
          MetraSectionCard(
            title: 'درجات الحرارة والرطوبة',
            child: Column(
              children: [
                _numField(_maxTemp, 'العظمى (°م)'),
                _numField(_minTemp, 'الصغرى (°م)'),
                _numField(_maxHumidity, 'الرطوبة العظمى (%)'),
                _numField(_minHumidity, 'الرطوبة الصغرى (%)'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          MetraSectionCard(
            title: 'الهطول والثلوج والتبخر وسطوع الشمس',
            child: Column(
              children: [
                _numField(_precipitation, 'الهطول'),
                _numField(_snow, 'الثلوج'),
                _numField(_evaporation, 'التبخر'),
                _numField(_sunshine, 'سطوع الشمس'),
                _numField(_gusts, 'هبات الرياح'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          MetraSectionCard(
            title: 'الفترة المرجعية والملاحظات',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _textField(_referencePeriod, 'الفترة المرجعية'),
                _textField(_notes, 'ملاحظات', maxLines: 3),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _responsibilityConfirmed,
                  onChanged: (v) =>
                      setState(() => _responsibilityConfirmed = v ?? false),
                  title: const Text(
                    'أؤكد مسؤولية صحة البيانات اليومية المدخلة.',
                    style: TextStyle(fontSize: 14),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ),
          ),
          if (_statusMessage != null) ...[
            const SizedBox(height: 12),
            MetraStatusBanner(tone: MetraBannerTone.info, message: _statusMessage!),
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
                  child: const Text('مسح'),
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
                      : const Icon(Icons.save_outlined),
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
