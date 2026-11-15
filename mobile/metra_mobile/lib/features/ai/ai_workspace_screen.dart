import 'package:flutter/material.dart';
import '../../core/widgets/metra_ui.dart';

/// AI lifecycle workspace: datasets, annotation, splits, experiments, registry,
/// approval and monitoring. Training/deployment are deliberately server-gated.
class AiWorkspaceScreen extends StatefulWidget {
  const AiWorkspaceScreen({super.key});
  @override
  State<AiWorkspaceScreen> createState() => _AiWorkspaceScreenState();
}

class _AiWorkspaceScreenState extends State<AiWorkspaceScreen> {
  int _section = 0;
  String? _task;
  String _draftStatus = '';
  final _dataset = TextEditingController();
  final _notes = TextEditingController();

  @override
  void dispose() { _dataset.dispose(); _notes.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
    children: [
      const MetraPageHeader(title: 'مختبر الذكاء الاصطناعي', subtitle: 'منصة دورة حياة النموذج: مجموعات البيانات، الوسم، التقسيم، التدريب، التقييم، الإصدارات والنشر.'),
      const SizedBox(height: 8),
      const MetraStatusBanner(tone: MetraBannerTone.warning, message: 'واجهة إدارة دورة حياة AI جاهزة. لا يوجد تدريب أو OCR أو نشر فعلي متصل حالياً. كل نتائج النموذج المستقبلية يجب أن ترتبط بمصدر بيانات وإصدار وبطاقة نموذج ومراجعة بشرية.'),
      const SizedBox(height: 12),
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: SegmentedButton<int>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: 0, label: Text('البيانات والوسم'), icon: Icon(Icons.dataset_outlined)),
          ButtonSegment(value: 1, label: Text('التقسيم والتدريب'), icon: Icon(Icons.model_training_outlined)),
          ButtonSegment(value: 2, label: Text('التقييم والنماذج'), icon: Icon(Icons.query_stats)),
          ButtonSegment(value: 3, label: Text('الاعتماد والمراقبة'), icon: Icon(Icons.verified_user_outlined)),
        ],
        selected: {_section}, onSelectionChanged: (v) => setState(() => _section = v.first),
      )),
      const SizedBox(height: 14),
      if (_section == 0) _datasets(),
      if (_section == 1) _training(),
      if (_section == 2) _evaluation(),
      if (_section == 3) _governance(),
    ],
  );

  Widget _datasets() => Column(children: [
    const MetraSectionCard(title: 'مستودع مجموعات البيانات', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('إدارة نسخ البيانات الوصفية ومصادر الصور وملفات الحقيقة الأرضية وبصمات SHA-256.', style: TextStyle(color: metraMuted)),
      SizedBox(height: 12),
      MetraEmptyState(icon: Icons.dataset_outlined, title: 'لا توجد مجموعات بيانات محمّلة', message: 'تظهر هنا مجموعات الصور والسجلات المصنفة وإصداراتها ومصدرها ونطاق المحطات والفترات الزمنية.'),
    ])),
    const SizedBox(height: 12),
    MetraSectionCard(title: 'مخطط الوسم والتصحيح', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('أنواع الوسم المستهدفة', style: TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      const Wrap(spacing: 8, runSpacing: 8, children: [
        Chip(label: Text('أرقام OCR')), Chip(label: Text('تواريخ وأوقات')), Chip(label: Text('محاور المخطط')), Chip(label: Text('منحنى Thermograph')), Chip(label: Text('منحنى Hygrograph')), Chip(label: Text('منحنى Barograph')), Chip(label: Text('منحنى Pluviograph')),
      ]),
      const SizedBox(height: 8),
      const MetraStatusBanner(tone: MetraBannerTone.info, message: 'أداة الوسم ستعرض الصورة الأصلية دون تغيير، وطبقة annotations منفصلة قابلة للمراجعة والتتبع.'),
    ])),
  ]);

  Widget _training() => Column(children: [
    MetraSectionCard(title: 'إعداد تجربة تدريب', child: Column(children: [
      TextField(controller: _dataset, decoration: const InputDecoration(labelText: 'معرف مجموعة البيانات وإصدارها')),
      const SizedBox(height: 10),
      DropdownButtonFormField<String>(
        initialValue: _task,
        decoration: const InputDecoration(labelText: 'مهمة النموذج'),
        items: const ['OCR للأرقام','رقمنة منحنيات المسجلات','تصنيف نوع السجل','كشف جودة الصورة'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
        onChanged: (v) => setState(() => _task = v),
      ),
      const SizedBox(height: 10),
      TextField(controller: _notes, maxLines: 2, decoration: const InputDecoration(labelText: 'إعدادات التجربة وملاحظاتها')),
      const SizedBox(height: 12),
      FilledButton.icon(onPressed: () => setState(() => _draftStatus = 'أُعدّت بطاقة تجربة محلية فقط. لم يتم تشغيل تدريب أو إرسال بيانات.'), icon: const Icon(Icons.save_outlined), label: const Text('إعداد بطاقة التجربة')),
      if (_draftStatus.isNotEmpty) ...[const SizedBox(height: 8), MetraStatusBanner(tone: MetraBannerTone.info, message: _draftStatus)],
    ])),
    const SizedBox(height: 12),
    const MetraSectionCard(title: 'سياسة تقسيم البيانات', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _PolicyRow('Train', 'بيانات التدريب'), _PolicyRow('Validation', 'اختيار الإعدادات ومراقبة فرط التخصيص'), _PolicyRow('Test', 'اختبار مستقل لا يُستخدم أثناء التدريب'),
      SizedBox(height: 8),
      MetraStatusBanner(tone: MetraBannerTone.warning, message: 'يجب منع تسرب صور المحطة نفسها أو الفترات المتجاورة بين التقسيمات وفق سياسة التجربة، وتوثيق التقسيم قبل التدريب.'),
    ])),
    const SizedBox(height: 12),
    const MetraSectionCard(title: 'قائمة تشغيل التجارب', child: MetraEmptyState(icon: Icons.play_circle_outline, title: 'لا توجد تجارب', message: 'تظهر هنا حالة الانتظار والتشغيل والنجاح والفشل وسجلات الموارد عند توصيل منسق التدريب.')),
  ]);

  Widget _evaluation() => Column(children: [
    const MetraSectionCard(title: 'مقاييس التقييم', child: Wrap(spacing: 8, runSpacing: 8, children: [
      Chip(label: Text('CER / WER')), Chip(label: Text('MAE / RMSE')), Chip(label: Text('Precision / Recall')), Chip(label: Text('F1')), Chip(label: Text('Confidence calibration')), Chip(label: Text('Inference latency')),
    ])),
    const SizedBox(height: 12),
    const MetraSectionCard(title: 'لوحة مقارنة التجارب', child: MetraEmptyState(icon: Icons.query_stats, title: 'لا توجد نتائج تقييم', message: 'ستعرض الرسوم مقارنة الإصدارات على مجموعة اختبار مستقلة مع نطاقات الخطأ وتحليل الأداء حسب الجهاز والعنصر والمحطة.')),
    const SizedBox(height: 12),
    const MetraSectionCard(title: 'سجل النماذج والإصدارات', child: MetraEmptyState(icon: Icons.inventory_2_outlined, title: 'سجل النماذج فارغ', message: 'تُحفظ بطاقة كل نموذج مع بصمة الملف، ومصدر البيانات، وإعدادات التدريب، ومقاييس الاختبار، وتاريخ الإنشاء.')),
  ]);

  Widget _governance() => Column(children: [
    const MetraSectionCard(title: 'بوابة اعتماد النموذج', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _WorkflowRow('1', 'مراجعة بطاقة النموذج ومصدر البيانات'),
      _WorkflowRow('2', 'التحقق من تقسيم البيانات ومنع التسرب'),
      _WorkflowRow('3', 'مراجعة الأداء على محطات غير مرئية'),
      _WorkflowRow('4', 'تقييم مخاطر الاستخدام والانحراف'),
      _WorkflowRow('5', 'اعتماد بشري قبل النشر'),
    ])),
    const SizedBox(height: 12),
    const MetraSectionCard(title: 'النشر والمراقبة', child: MetraEmptyState(icon: Icons.monitor_heart_outlined, title: 'لا توجد نماذج منشورة', message: 'بعد اعتماد النموذج ستعرض هنا بيئات النشر والإصدارات النشطة ومعدلات الخطأ والانحراف وطلبات إعادة التدريب.')),
    const SizedBox(height: 12),
    const MetraSectionCard(title: 'حوكمة النموذج', child: Text('لا يجوز استبدال نموذج معتمد دون إصدار جديد. يجب الاحتفاظ بإمكانية الرجوع، وتسجيل كل عملية inference ومصدرها وإصدار النموذج وقرار المراجع عند الحاجة.', style: TextStyle(color: metraMuted, height: 1.5))),
  ]);
}

class _PolicyRow extends StatelessWidget {
  const _PolicyRow(this.code, this.label);
  final String code, label;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 7), child: Row(children: [
    SizedBox(width: 105, child: Text(code, style: const TextStyle(fontWeight: FontWeight.w800, color: metraNavy))),
    Expanded(child: Text(label, style: const TextStyle(color: metraMuted))),
  ]));
}
class _WorkflowRow extends StatelessWidget {
  const _WorkflowRow(this.number, this.label);
  final String number, label;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [
    CircleAvatar(radius: 13, backgroundColor: metraBlue.withValues(alpha: .1), child: Text(number, style: const TextStyle(color: metraBlue, fontSize: 11))),
    const SizedBox(width: 10), Expanded(child: Text(label)),
  ]));
}
