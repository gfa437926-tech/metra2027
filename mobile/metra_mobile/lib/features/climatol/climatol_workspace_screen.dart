import 'package:flutter/material.dart';
import '../../core/widgets/metra_ui.dart';

/// Full client-side CLIMATOL workspace. All execution and scientific results
/// remain server-owned; this screen only prepares and reviews UI state.
class ClimatolWorkspaceScreen extends StatefulWidget {
  const ClimatolWorkspaceScreen({super.key});
  @override
  State<ClimatolWorkspaceScreen> createState() => _ClimatolWorkspaceScreenState();
}

class _ClimatolWorkspaceScreenState extends State<ClimatolWorkspaceScreen> {
  int _section = 0;
  String? _variable;
  String _draftStatus = '';
  final _stationGroup = TextEditingController();
  final _from = TextEditingController();
  final _to = TextEditingController();
  final _notes = TextEditingController();

  @override
  void dispose() {
    _stationGroup.dispose(); _from.dispose(); _to.dispose(); _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        const MetraPageHeader(
          title: 'التجانس المناخي وCLIMATOL',
          subtitle: 'إدارة السلاسل الزمنية، المحطات المرجعية، نقاط الانقطاع، السلاسل المصححة والمعدلات المناخية.',
        ),
        const SizedBox(height: 8),
        const MetraStatusBanner(
          tone: MetraBannerTone.warning,
          message: 'واجهة العمل مكتملة من جهة العرض وإعداد المسودات. محرك CLIMATOL وخدمات البيانات غير متصلين؛ لا يتم تعديل السلاسل الخام أو عرض نتائج تحليل افتراضية.',
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 0, label: Text('لوحة التجانس'), icon: Icon(Icons.dashboard_outlined)),
              ButtonSegment(value: 1, label: Text('السلاسل الزمنية'), icon: Icon(Icons.show_chart)),
              ButtonSegment(value: 2, label: Text('الانقطاعات والمرجعيات'), icon: Icon(Icons.compare_arrows)),
              ButtonSegment(value: 3, label: Text('المراجعة والتقارير'), icon: Icon(Icons.fact_check_outlined)),
            ],
            selected: {_section},
            onSelectionChanged: (v) => setState(() => _section = v.first),
          ),
        ),
        const SizedBox(height: 14),
        if (_section == 0) _overview(),
        if (_section == 1) _series(),
        if (_section == 2) _breakpoints(),
        if (_section == 3) _reviewReports(),
      ],
    );
  }

  Widget _overview() => Column(children: [
    const _ClimatolMetricGrid(),
    const SizedBox(height: 12),
    const MetraSectionCard(title: 'دورة العمل العلمية', child: Column(children: [
      _WorkflowLine('1', 'تهيئة السلاسل', 'تحديد المحطة والمتغير والفترة وفحص التغطية والفجوات.'),
      _WorkflowLine('2', 'اختيار المحطات المرجعية', 'اختبار الملاءمة والارتباط المكاني وتوثيق الاختيار.'),
      _WorkflowLine('3', 'كشف نقاط الانقطاع', 'اقتراح الانقطاعات ومراجعة الأدلة الوصفية.'),
      _WorkflowLine('4', 'تشغيل التجانس', 'تنفيذ معزول على الخادم وإنتاج نسخة مشتقة مستقلة.'),
      _WorkflowLine('5', 'المراجعة والاعتماد', 'مقارنة الخام والمصحح واعتماد الإصدار بشرياً.'),
    ])),
    const SizedBox(height: 12),
    MetraSectionCard(title: 'إعداد مهمة جديدة', child: _setupForm()),
  ]);

  Widget _setupForm() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    TextField(controller: _stationGroup, decoration: const InputDecoration(labelText: 'معرف المحطة أو مجموعة المحطات', hintText: 'يُختار من دليل المحطات عند الاتصال')),
    const SizedBox(height: 10),
    DropdownButtonFormField<String>(
      initialValue: _variable,
      decoration: const InputDecoration(labelText: 'العنصر المناخي'),
      items: const ['درجة الحرارة','الهطول','الضغط الجوي','الرطوبة','سرعة الرياح'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
      onChanged: (v) => setState(() => _variable = v),
    ),
    const SizedBox(height: 10),
    Row(children: [
      Expanded(child: TextField(controller: _from, decoration: const InputDecoration(labelText: 'من تاريخ', hintText: 'YYYY-MM-DD'))),
      const SizedBox(width: 8),
      Expanded(child: TextField(controller: _to, decoration: const InputDecoration(labelText: 'إلى تاريخ', hintText: 'YYYY-MM-DD'))),
    ]),
    const SizedBox(height: 10),
    TextField(controller: _notes, maxLines: 2, decoration: const InputDecoration(labelText: 'ملاحظات ومنهجية التحليل')),
    const SizedBox(height: 12),
    FilledButton.icon(onPressed: () => setState(() => _draftStatus = 'أُعدّت مسودة محلية فقط. لم يتم إرسال مهمة أو تشغيل CLIMATOL.'), icon: const Icon(Icons.save_outlined), label: const Text('إعداد مسودة المهمة')),
    if (_draftStatus.isNotEmpty) ...[const SizedBox(height: 8), MetraStatusBanner(tone: MetraBannerTone.info, message: _draftStatus)],
  ]);

  Widget _series() => Column(children: [
    const MetraSectionCard(title: 'مستكشف السلاسل الزمنية', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('فلاتر الاستعراض', style: TextStyle(fontWeight: FontWeight.w800)),
      SizedBox(height: 8),
      Text('المحطة · المتغير · الفترة الزمنية · الدورية · إصدار السلسلة', style: TextStyle(color: metraMuted)),
      SizedBox(height: 14),
      MetraEmptyState(icon: Icons.show_chart, title: 'لا توجد سلسلة محمّلة', message: 'سيظهر الرسم الزمني بعد تحميل القياسات المعتمدة، مع تمييز الفجوات والقيم المفقودة والقيم المرشحة للمراجعة.'),
    ])),
    const SizedBox(height: 12),
    const MetraSectionCard(title: 'طبقات العرض', child: Wrap(spacing: 8, runSpacing: 8, children: [
      Chip(label: Text('السلسلة الخام')), Chip(label: Text('السلسلة المصححة')), Chip(label: Text('المتوسطات')), Chip(label: Text('القيم المفقودة')), Chip(label: Text('نقاط الانقطاع')),
    ])),
  ]);

  Widget _breakpoints() => Column(children: [
    const MetraSectionCard(title: 'كشف نقاط الانقطاع', child: MetraEmptyState(icon: Icons.timeline, title: 'لا توجد نتائج تحليل', message: 'تعرض هذه المساحة الانقطاعات المرشحة وتاريخها وقوة الدليل والاختبار الإحصائي، بعد تشغيل محرك التحليل.')),
    const SizedBox(height: 12),
    const MetraSectionCard(title: 'مقارنة المحطات المرجعية', child: MetraEmptyState(icon: Icons.hub_outlined, title: 'لم تُحدد محطات مرجعية', message: 'ستظهر المحطات المرشحة ومعايير الاختيار والارتباط والتغطية المشتركة عند توفر دليل المحطات والبيانات.')),
    const SizedBox(height: 12),
    const MetraSectionCard(title: 'إدارة الإصدارات', child: Text('تُحفظ كل سلسلة مصححة كإصدار مستقل مرتبط بإصدار الخام ومعلمات التشغيل والمراجع وقرار الاعتماد.', style: TextStyle(color: metraMuted))),
  ]);

  Widget _reviewReports() => Column(children: [
    const MetraSectionCard(title: 'بوابة المراجعة والاعتماد', child: MetraEmptyState(icon: Icons.fact_check_outlined, title: 'قائمة المراجعة فارغة', message: 'تظهر هنا السلسلة قبل وبعد التجانس، والتغييرات المقترحة، وأسبابها، وهوية المراجع وقرار الاعتماد.')),
    const SizedBox(height: 12),
    const MetraSectionCard(title: 'التقارير المناخية', child: Wrap(spacing: 8, runSpacing: 8, children: [
      Chip(label: Text('شهري')), Chip(label: Text('فصلي')), Chip(label: Text('سنوي')), Chip(label: Text('المعدلات المناخية')), Chip(label: Text('الاتجاهات')), Chip(label: Text('المؤشرات')), Chip(label: Text('مقارنة جغرافية')),
    ])),
    const SizedBox(height: 12),
    const MetraSectionCard(title: 'سجل العمليات', child: MetraEmptyState(icon: Icons.history, title: 'لا توجد عمليات مسجلة', message: 'سيحفظ سجل التدقيق المستخدم والتوقيت وبصمة المدخلات وإصدار المحرك ومعلمات التشغيل والمخرجات والقرار.')),
  ]);
}

class _ClimatolMetricGrid extends StatelessWidget {
  const _ClimatolMetricGrid();
  @override
  Widget build(BuildContext context) => const Wrap(spacing: 8, runSpacing: 8, children: [
    _MetricTile('السلاسل المحملة', '—'), _MetricTile('الانقطاعات المرشحة', '—'), _MetricTile('المحطات المرجعية', '—'), _MetricTile('الإصدارات المعتمدة', '—'),
  ]);
}
class _MetricTile extends StatelessWidget {
  const _MetricTile(this.label, this.value);
  final String label; final String value;
  @override
  Widget build(BuildContext context) => SizedBox(width: 158, child: Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(color: metraMuted, fontSize: 11)), const SizedBox(height: 8), Text(value, style: const TextStyle(color: metraNavy, fontSize: 23, fontWeight: FontWeight.bold)),
  ]))));
}
class _WorkflowLine extends StatelessWidget {
  const _WorkflowLine(this.number, this.title, this.description);
  final String number, title, description;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    CircleAvatar(radius: 14, backgroundColor: metraBlue.withValues(alpha: .1), child: Text(number, style: const TextStyle(color: metraBlue, fontSize: 11))),
    const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 3), Text(description, style: const TextStyle(color: metraMuted, height: 1.4)),
    ])),
  ]));
}
