import 'package:flutter/material.dart';
import '../../core/widgets/metra_ui.dart';

/// Instrument inventory and lifecycle workspace.
/// All changes are local drafts until the secured .NET service is available.
class InstrumentManagementScreen extends StatefulWidget {
  const InstrumentManagementScreen({super.key});

  @override
  State<InstrumentManagementScreen> createState() => _InstrumentManagementScreenState();
}

class _InstrumentManagementScreenState extends State<InstrumentManagementScreen> {
  int _section = 0;
  String? _kind;
  String? _draftMessage;
  final _stationId = TextEditingController();
  final _instrumentId = TextEditingController();
  final _serial = TextEditingController();
  final _validFrom = TextEditingController();
  final _validTo = TextEditingController();
  final _notes = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  static const _kinds = [
    'Thermograph', 'Hygrograph', 'Barograph', 'Pluviograph',
    'مقياس حرارة رقمي', 'مقياس رطوبة رقمي', 'بارومتر رقمي', 'مقياس مطر رقمي',
  ];

  @override
  void dispose() {
    _stationId.dispose();
    _instrumentId.dispose();
    _serial.dispose();
    _validFrom.dispose();
    _validTo.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
    children: [
      const MetraPageHeader(
        title: 'إدارة الأجهزة والمعايرة',
        subtitle: 'سجل الأجهزة، ربطها بالمحطات، فترات التشغيل، المعايرة والصيانة وسجل التغييرات.',
      ),
      const SizedBox(height: 8),
      const MetraStatusBanner(
        tone: MetraBannerTone.warning,
        message: 'هذه واجهة تجهيز ومراجعة. لا يوجد حتى الآن API معتمد لحفظ الأجهزة أو نشر تغييرات المعايرة؛ جميع المسودات محلية ولا تغيّر سجلات المحطات.',
      ),
      const SizedBox(height: 12),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SegmentedButton<int>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: 0, label: Text('سجل الأجهزة'), icon: Icon(Icons.sensors_outlined)),
            ButtonSegment(value: 1, label: Text('التوزيع بالمحطات'), icon: Icon(Icons.hub_outlined)),
            ButtonSegment(value: 2, label: Text('المعايرة'), icon: Icon(Icons.tune)),
            ButtonSegment(value: 3, label: Text('الصيانة'), icon: Icon(Icons.build_outlined)),
          ],
          selected: {_section},
          onSelectionChanged: (value) => setState(() => _section = value.first),
        ),
      ),
      const SizedBox(height: 14),
      if (_section == 0) _inventory(),
      if (_section == 1) _deployments(),
      if (_section == 2) _calibration(),
      if (_section == 3) _maintenance(),
    ],
  );

  Widget _inventory() => Column(children: [
    _panel('تعريف جهاز أو أداة رصد', Column(children: [
      Form(
        key: _formKey,
        child: Column(children: [
          TextFormField(
            key: const Key('instrument-id'),
            controller: _instrumentId,
            decoration: const InputDecoration(labelText: 'معرف الجهاز (UUID)'),
            validator: _uuidValidator,
          ),
          const SizedBox(height: 9),
          DropdownButtonFormField<String>(
            key: const Key('instrument-kind'),
            initialValue: _kind,
            decoration: const InputDecoration(labelText: 'نوع الجهاز'),
            items: _kinds.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
            onChanged: (value) => setState(() => _kind = value),
            validator: (value) => value == null ? 'اختر نوع الجهاز' : null,
          ),
          const SizedBox(height: 9),
          TextFormField(
            key: const Key('instrument-serial'),
            controller: _serial,
            decoration: const InputDecoration(labelText: 'الرقم التسلسلي'),
            validator: (value) => (value?.trim().isEmpty ?? true) ? 'الرقم التسلسلي مطلوب' : null,
          ),
          const SizedBox(height: 9),
          TextFormField(
            controller: _notes,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'الشركة والطراز والملاحظات'),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      FilledButton.icon(
        key: const Key('save-instrument-draft'),
        onPressed: _prepareInstrumentDraft,
        icon: const Icon(Icons.save_outlined),
        label: const Text('إعداد مسودة الجهاز'),
      ),
      if (_draftMessage != null) ...[
        const SizedBox(height: 9),
        MetraStatusBanner(tone: MetraBannerTone.info, message: _draftMessage!),
      ],
    ])),
    const SizedBox(height: 12),
    _panel('تصنيفات الأجهزة المدعومة', const Wrap(spacing: 8, runSpacing: 8, children: [
      Chip(label: Text('Thermograph')),
      Chip(label: Text('Hygrograph')),
      Chip(label: Text('Barograph')),
      Chip(label: Text('Pluviograph')),
      Chip(label: Text('أجهزة إلكترونية')),
      Chip(label: Text('أدوات يدوية')),
    ])),
  ]);

  Widget _deployments() => Column(children: [
    _panel('ربط الجهاز بمحطة', Column(children: [
      TextField(controller: _stationId, decoration: const InputDecoration(labelText: 'معرف المحطة (UUID)')),
      const SizedBox(height: 9),
      TextField(controller: _instrumentId, decoration: const InputDecoration(labelText: 'معرف الجهاز (UUID)')),
      const SizedBox(height: 9),
      TextField(controller: _validFrom, decoration: const InputDecoration(labelText: 'بداية فترة التركيب (ISO 8601)')),
      const SizedBox(height: 9),
      TextField(controller: _validTo, decoration: const InputDecoration(labelText: 'نهاية فترة التركيب (اختياري)')),
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: () => setState(() => _draftMessage = 'تم إعداد مسودة ربط محلية فقط. يجب أن يتحقق الخادم من نطاق الجهة وتداخل فترات التركيب قبل الحفظ.'),
        icon: const Icon(Icons.link),
        label: const Text('إعداد مسودة الربط'),
      ),
    ])),
    const SizedBox(height: 12),
    _panel('ضوابط التوزيع', const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _RuleLine('لا يجوز ربط الجهاز بمحطتين في الفترة نفسها إذا كان نوع النشر يمنع ذلك.'),
      _RuleLine('يجب توثيق تاريخ التركيب والفك والمنفذ والسبب.'),
      _RuleLine('تُراجع صلاحية الجهاز قبل قبول الرصدات المرتبطة به.'),
      _RuleLine('تُحفظ سجلات التوزيع السابقة ولا تُستبدل بصمت.'),
    ])),
  ]);

  Widget _calibration() => Column(children: [
    _panel('سجل المعايرة', const MetraEmptyState(
      icon: Icons.tune,
      title: 'لا توجد شهادات معايرة معروضة',
      message: 'ستظهر هنا الشهادة والجهة المنفذة وتاريخ المعايرة وتاريخ الاستحقاق والمعايير المرجعية والانحراف وعدم اليقين.',
    )),
    const SizedBox(height: 12),
    _panel('قائمة التحقق', const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _RuleLine('رقم شهادة المعايرة ومرفقها وبصمتها الرقمية.'),
      _RuleLine('المعيار المرجعي وإمكانية تتبع سلسلة المعايرة.'),
      _RuleLine('النتائج قبل الضبط وبعده وحدود السماح.'),
      _RuleLine('اعتماد فني مستقل وتاريخ المعايرة التالية.'),
    ])),
  ]);

  Widget _maintenance() => Column(children: [
    _panel('طلبات الصيانة', const MetraEmptyState(
      icon: Icons.build_outlined,
      title: 'لا توجد طلبات صيانة',
      message: 'تظهر هنا البلاغات والأعطال والأولوية وقطع الغيار والإجراء الفني ووقت التوقف وإعادة الخدمة.',
    )),
    const SizedBox(height: 12),
    _panel('مؤشرات دورة حياة الجهاز', const Wrap(spacing: 8, runSpacing: 8, children: [
      Chip(label: Text('متاح')),
      Chip(label: Text('قيد التركيب')),
      Chip(label: Text('قيد المعايرة')),
      Chip(label: Text('قيد الصيانة')),
      Chip(label: Text('متوقف')),
      Chip(label: Text('خارج الخدمة')),
    ])),
  ]);

  void _prepareInstrumentDraft() {
    if (!_formKey.currentState!.validate()) {
      setState(() => _draftMessage = 'أكمل معرف الجهاز الصحيح ونوعه ورقمه التسلسلي.');
      return;
    }
    setState(() => _draftMessage = 'أُعدّت مسودة جهاز ' + _kind! + ' محلياً. لم تُحفظ في الخادم.');
  }

  String? _uuidValidator(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'معرف الجهاز مطلوب';
    final pattern = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$');
    return pattern.hasMatch(text) ? null : 'أدخل UUID صالحاً';
  }

  Widget _panel(String title, Widget child) => Card(
    elevation: 0,
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: Color(0xFFE5EAF2)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title, style: const TextStyle(color: metraNavy, fontWeight: FontWeight.w800, fontSize: 15)),
        const SizedBox(height: 12),
        child,
      ]),
    ),
  );
}

class _RuleLine extends StatelessWidget {
  const _RuleLine(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.verified_outlined, size: 17, color: metraBlue),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: const TextStyle(color: metraMuted, height: 1.45))),
    ]),
  );
}
