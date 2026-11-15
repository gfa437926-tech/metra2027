import 'package:flutter/material.dart';
import '../../core/widgets/metra_ui.dart';

/// Field workspace for paper and mechanical records, image digitization,
/// source comparison and quality review. Upload/OCR remain server-gated.
class RecordsReviewWorkspaceScreen extends StatefulWidget {
  const RecordsReviewWorkspaceScreen({super.key});
  @override
  State<RecordsReviewWorkspaceScreen> createState() => _RecordsReviewWorkspaceScreenState();
}

class _RecordsReviewWorkspaceScreenState extends State<RecordsReviewWorkspaceScreen> {
  int _section = 0;
  String? _recordType;
  String _draftStatus = '';
  final _station = TextEditingController();
  final _period = TextEditingController();

  @override
  void dispose() { _station.dispose(); _period.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
    children: [
      const MetraPageHeader(title: 'أرشيف السجلات وتدقيق الصور', subtitle: 'إدارة السجلات الورقية والميكانيكية، رقمنة القراءات، مقارنة المصادر الثلاثة ومراجعة جودة الاستخراج.'),
      const SizedBox(height: 8),
      const MetraStatusBanner(tone: MetraBannerTone.warning, message: 'رفع الملفات والتخزين وOCR ورقمنة المنحنيات غير مفعّلة بعد. لا يتم عرض قراءات مستخرجة أو نتائج مقارنة غير حقيقية، وتبقى الصور الأصلية غير قابلة للاستبدال.'),
      const SizedBox(height: 12),
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: SegmentedButton<int>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: 0, label: Text('الأرشيف'), icon: Icon(Icons.folder_outlined)),
          ButtonSegment(value: 1, label: Text('مراجعة الصور'), icon: Icon(Icons.document_scanner_outlined)),
          ButtonSegment(value: 2, label: Text('المقارنة الثلاثية'), icon: Icon(Icons.compare_arrows)),
          ButtonSegment(value: 3, label: Text('الجودة والاعتماد'), icon: Icon(Icons.fact_check_outlined)),
        ],
        selected: {_section}, onSelectionChanged: (v) => setState(() => _section = v.first),
      )),
      const SizedBox(height: 14),
      if (_section == 0) _archive(),
      if (_section == 1) _imageReview(),
      if (_section == 2) _comparison(),
      if (_section == 3) _quality(),
    ],
  );

  Widget _archive() => Column(children: [
    MetraSectionCard(title: 'تعريف سجل جديد', child: Column(children: [
      TextField(controller: _station, decoration: const InputDecoration(labelText: 'معرف المحطة')),
      const SizedBox(height: 10),
      DropdownButtonFormField<String>(initialValue: _recordType, decoration: const InputDecoration(labelText: 'نوع السجل أو الجهاز'), items: const [
        'سجل ورقي','Thermograph','Hygrograph','Barograph','Pluviograph',
      ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => setState(() => _recordType = v)),
      const SizedBox(height: 10),
      TextField(controller: _period, decoration: const InputDecoration(labelText: 'الفترة أو التاريخ المسجل')),
      const SizedBox(height: 12),
      FilledButton.icon(onPressed: () => setState(() => _draftStatus = 'تم تجهيز تعريف محلي فقط. رفع الملف غير متاح قبل ربط التخزين الخاص.'), icon: const Icon(Icons.save_outlined), label: const Text('إعداد تعريف السجل')),
      if (_draftStatus.isNotEmpty) ...[const SizedBox(height: 8), MetraStatusBanner(tone: MetraBannerTone.info, message: _draftStatus)],
    ])),
    const SizedBox(height: 12),
    const MetraSectionCard(title: 'أنواع الأرشيف', child: Column(children: [
      _RecordTypeRow(Icons.menu_book_outlined, 'السجلات الورقية', 'دفاتر الرصد والنماذج اليدوية'),
      _RecordTypeRow(Icons.thermostat_outlined, 'Thermograph', 'مخططات درجة الحرارة'),
      _RecordTypeRow(Icons.water_drop_outlined, 'Hygrograph', 'مخططات الرطوبة'),
      _RecordTypeRow(Icons.speed_outlined, 'Barograph', 'مخططات الضغط الجوي'),
      _RecordTypeRow(Icons.grain_outlined, 'Pluviograph', 'مخططات الهطول المطري'),
    ])),
    const SizedBox(height: 12),
    const MetraSectionCard(title: 'بيانات الأرشفة الإلزامية', child: Text('المحطة · الجهاز · العنصر المناخي · وقت البداية والنهاية · رقم الصفحة · الراصد أو مصدر السجل · بصمة الملف · إصدار المعالجة · حالة المراجعة', style: TextStyle(color: metraMuted, height: 1.6))),
  ]);

  Widget _imageReview() => Column(children: [
    const MetraSectionCard(title: 'مسار معالجة الصورة', child: Column(children: [
      _WorkflowStep('1', 'الصورة الأصلية', 'حفظ الملف كما ورد مع بصمة SHA-256.'),
      _WorkflowStep('2', 'تهيئة العرض', 'تصحيح الاتجاه والميل والتباين في طبقة مشتقة دون المساس بالأصل.'),
      _WorkflowStep('3', 'معايرة المخطط', 'تحديد المحاور والوحدات والتدرج الزمني والقياسي.'),
      _WorkflowStep('4', 'الاستخراج الآلي', 'OCR للأرقام أو رقمنة نقاط المنحنى مع مواضعها.'),
      _WorkflowStep('5', 'المراجعة البشرية', 'تصحيح القراءة واعتمادها مع حفظ القيمة المقترحة والأصلية.'),
    ])),
    const SizedBox(height: 12),
    const MetraSectionCard(title: 'عارض الصورة وطبقات القراءة', child: MetraEmptyState(icon: Icons.image_search_outlined, title: 'لا توجد صورة مفتوحة', message: 'ستظهر الصورة الأصلية بجانب النسخة المحسنة وطبقة OCR أو نقاط المنحنى وإحداثيات القراءة ودرجة الثقة.')),
    const SizedBox(height: 12),
    const MetraSectionCard(title: 'أنواع الاستخراج', child: Wrap(spacing: 8, runSpacing: 8, children: [
      Chip(label: Text('OCR للسجلات الورقية')), Chip(label: Text('رقمنة Thermograph')), Chip(label: Text('رقمنة Hygrograph')), Chip(label: Text('رقمنة Barograph')), Chip(label: Text('رقمنة Pluviograph')),
    ])),
  ]);

  Widget _comparison() => Column(children: [
    const Text('مقارنة المصادر المتزامنة', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
    const SizedBox(height: 10),
    const _SourceCard(number: '1', title: 'السجل الورقي', subtitle: 'القيمة المكتوبة يدوياً، صورة الصفحة، موضع القراءة، وقت الرصد.'),
    const _SourceCard(number: '2', title: 'المسجل الميكانيكي', subtitle: 'القيمة المستخرجة من المنحنى، إحداثيات الصورة، معايرة المحاور وعدم اليقين.'),
    const _SourceCard(number: '3', title: 'الرصد الإلكتروني', subtitle: 'القيمة الرقمية المعتمدة للمحطة والعنصر والفترة الزمنية نفسها.'),
    const SizedBox(height: 10),
    const MetraSectionCard(title: 'لوحة الفروقات', child: MetraEmptyState(icon: Icons.compare_arrows, title: 'لا توجد مقارنة محمّلة', message: 'ستعرض القيم الثلاث والفروق المطلقة والنسبية وحدود التسامح والتراكب البصري وقرار المراجع.')),
    const SizedBox(height: 10),
    const MetraStatusBanner(tone: MetraBannerTone.info, message: 'تُطابق المصادر حسب المحطة والعنصر والطابع الزمني والوحدة. أي اختلاف يُحال للمراجعة ولا يغير الرصد الأصلي تلقائياً.'),
  ]);

  Widget _quality() => Column(children: [
    const MetraSectionCard(title: 'قائمة تدقيق الصورة والقراءة', child: Column(children: [
      _WorkflowStep('✓', 'اكتمال بيانات المصدر', 'المحطة والتاريخ والجهاز والعنصر ورقم الصفحة.'),
      _WorkflowStep('✓', 'جودة الصورة', 'الدقة والوضوح والقص والاتجاه والتباين.'),
      _WorkflowStep('✓', 'معايرة المقياس', 'الوحدات والمحاور والتدرج والزمن.'),
      _WorkflowStep('✓', 'موثوقية الاستخراج', 'درجة الثقة وموضع القراءة ومراجعة القيم منخفضة الثقة.'),
      _WorkflowStep('✓', 'قرار الاعتماد', 'قبول أو رفض أو طلب إعادة معالجة مع سبب وهوية المراجع.'),
    ])),
    const SizedBox(height: 12),
    const MetraSectionCard(title: 'سجل المراجعة والتعديلات', child: MetraEmptyState(icon: Icons.history, title: 'لا توجد قرارات مسجلة', message: 'سيُحفظ كل تعديل مع القيمة الأصلية والمقترحة والمعتمدة وسبب التعديل والمراجع والتوقيت وبصمة الصورة وإصدار أداة الاستخراج.')),
    const SizedBox(height: 12),
    const MetraSectionCard(title: 'تقارير التدقيق', child: Wrap(spacing: 8, runSpacing: 8, children: [
      Chip(label: Text('تغطية الأرشيف')), Chip(label: Text('جودة الصور')), Chip(label: Text('دقة OCR')), Chip(label: Text('جودة رقمنة المنحنيات')), Chip(label: Text('اختلاف المصادر')), Chip(label: Text('قرارات الاعتماد')),
    ])),
  ]);
}

class _RecordTypeRow extends StatelessWidget {
  const _RecordTypeRow(this.icon, this.title, this.description);
  final IconData icon; final String title, description;
  @override
  Widget build(BuildContext context) => ListTile(contentPadding: EdgeInsets.zero, leading: Icon(icon, color: metraBlue), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text(description), trailing: const Chip(label: Text('بانتظار الربط')));
}
class _WorkflowStep extends StatelessWidget {
  const _WorkflowStep(this.number, this.title, this.description);
  final String number, title, description;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    CircleAvatar(radius: 13, backgroundColor: metraBlue.withValues(alpha: .1), child: Text(number, style: const TextStyle(color: metraBlue, fontSize: 11))),
    const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 3), Text(description, style: const TextStyle(color: metraMuted))])),
  ]));
}
class _SourceCard extends StatelessWidget {
  const _SourceCard({required this.number, required this.title, required this.subtitle});
  final String number, title, subtitle;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 9), child: MetraSectionCard(title: '$number · $title', child: Text(subtitle, style: const TextStyle(color: metraMuted, height: 1.5))));
}
