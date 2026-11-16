import 'package:material_ui/material_ui.dart';

class _ServiceNotice extends StatelessWidget {
  const _ServiceNotice({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        color: const Color(0xFFFFF7E8),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, color: Color(0xFF9A6700)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(message),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF087CF0)),
              const SizedBox(width: 10),
              Expanded(child: Text(label)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
}

class ClimatolWorkspaceScreen extends StatefulWidget {
  const ClimatolWorkspaceScreen({super.key, required this.stationId});
  final String stationId;

  @override
  State<ClimatolWorkspaceScreen> createState() => _ClimatolWorkspaceScreenState();
}

class _ClimatolWorkspaceScreenState extends State<ClimatolWorkspaceScreen> {
  final _element = TextEditingController();
  DateTime? _start;
  DateTime? _end;

  @override
  void dispose() {
    _element.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDate(DateTime? current) => showDatePicker(
        context: context,
        initialDate: current ?? DateTime.now(),
        firstDate: DateTime(1900),
        lastDate: DateTime(2100),
      );

  String _dateLabel(DateTime? date) => date == null
      ? 'اختر التاريخ'
      : <String>[
          date.year.toString().padLeft(4, '0'),
          date.month.toString().padLeft(2, '0'),
          date.day.toString().padLeft(2, '0'),
        ].join('-');

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('CLIMATOL والتجانس المناخي')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ServiceNotice(
              title: 'محرك التحليل غير متصل',
              message: 'هذه واجهة إعداد التحليل فقط. لا يتم تشغيل اختبار أو إصدار نتيجة من دون محرك CLIMATOL وخدمة API موثقة.',
            ),
            const SizedBox(height: 12),
            Text('المحطة: ' + widget.stationId, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextField(
              controller: _element,
              decoration: const InputDecoration(
                labelText: 'رمز العنصر المناخي',
                hintText: 'أدخل رمز العنصر من القاموس المعتمد',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final date = await _pickDate(_start);
                if (date != null && mounted) setState(() => _start = date);
              },
              icon: const Icon(Icons.calendar_today),
              label: Text('بداية الفترة: ' + _dateLabel(_start)),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                final date = await _pickDate(_end);
                if (date != null && mounted) setState(() => _end = date);
              },
              icon: const Icon(Icons.event),
              label: Text('نهاية الفترة: ' + _dateLabel(_end)),
            ),
            const SizedBox(height: 12),
            const _MetricCard(label: 'السجلات المتاحة للتحليل', value: '—', icon: Icons.storage_outlined),
            const _MetricCard(label: 'القيم المفقودة', value: '—', icon: Icons.help_outline),
            const _MetricCard(label: 'القيم الشاذة', value: '—', icon: Icons.warning_amber_outlined),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: null,
              icon: const Icon(Icons.science_outlined),
              label: const Text('تشغيل تحليل التجانس'),
            ),
            OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.download_outlined),
              label: const Text('تصدير نتائج التحليل'),
            ),
          ],
        ),
      );
}

class RecordsAiWorkspaceScreen extends StatelessWidget {
  const RecordsAiWorkspaceScreen({super.key, required this.stationId});
  final String stationId;

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('الأرشيف المصور والذكاء الاصطناعي'),
            bottom: const TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: 'الأرشيف المصور'),
                Tab(text: 'مختبر الذكاء الاصطناعي'),
                Tab(text: 'مقارنة النتائج'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _ArchiveTab(stationId: stationId),
              _AiTab(stationId: stationId),
              _ComparisonTab(stationId: stationId),
            ],
          ),
        ),
      );
}

class _ArchiveTab extends StatelessWidget {
  const _ArchiveTab({required this.stationId});
  final String stationId;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ServiceNotice(
            title: 'خدمة الأرشفة غير متصلة',
            message: 'لا توجد خدمة تخزين/رفع ملفات معتمدة في API الحالي. لا يتم رفع الصور أو حفظها محلياً.',
          ),
          const SizedBox(height: 12),
          Text('المحطة: ' + stationId),
          const SizedBox(height: 12),
          const TextField(
            decoration: InputDecoration(
              labelText: 'البحث برقم السجل أو التاريخ',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: null,
            icon: const Icon(Icons.upload_file),
            label: const Text('رفع صورة سجل'),
          ),
          const SizedBox(height: 28),
          const Icon(Icons.photo_library_outlined, size: 48, color: Color(0xFF94A3B8)),
          const SizedBox(height: 8),
          const Center(child: Text('لا توجد صور معروضة — خدمة التخزين غير مهيأة')),
        ],
      );
}

class _AiTab extends StatelessWidget {
  const _AiTab({required this.stationId});
  final String stationId;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ServiceNotice(
            title: 'لا يوجد نموذج إنتاجي متصل',
            message: 'تجهيز مجموعات البيانات والتدريب والاستدلال يتطلب خدمة AI/OCR وإدارة ملفات وإصدارات نماذج.',
          ),
          const SizedBox(height: 12),
          Text('نطاق العمل: ' + stationId),
          const SizedBox(height: 12),
          const _MetricCard(label: 'مجموعات البيانات', value: '—', icon: Icons.storage),
          const _MetricCard(label: 'إصدارات النماذج', value: '—', icon: Icons.psychology_outlined),
          const _MetricCard(label: 'دقة آخر تقييم', value: '—', icon: Icons.insights_outlined),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: null,
            icon: const Icon(Icons.play_arrow),
            label: const Text('بدء تدريب نموذج'),
          ),
          OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('تشغيل استخراج OCR'),
          ),
        ],
      );
}

class _ComparisonTab extends StatelessWidget {
  const _ComparisonTab({required this.stationId});
  final String stationId;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ServiceNotice(
            title: 'المقارنة تنتظر محرك الاستخراج والبيانات المرجعية',
            message: 'تعرض هذه الواجهة مسار المراجعة المطلوب، لكنها لا تحسب نسب تطابق أو فروقات من بيانات غير متاحة.',
          ),
          const SizedBox(height: 12),
          Text('المحطة: ' + stationId),
          const SizedBox(height: 12),
          const Row(
            children: [
              Expanded(child: _ComparisonPanel(title: 'صورة السجل', icon: Icons.image_outlined)),
              SizedBox(width: 8),
              Expanded(child: _ComparisonPanel(title: 'البيانات الحقيقية', icon: Icons.table_chart_outlined)),
            ],
          ),
          const SizedBox(height: 12),
          const _MetricCard(label: 'القيم المستخرجة', value: '—', icon: Icons.document_scanner),
          const _MetricCard(label: 'نسبة التطابق', value: '—', icon: Icons.percent),
          const SizedBox(height: 12),
          const Text('جدول الفروقات', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Table(
            border: TableBorder.all(color: Color(0xFFE2E8F0)),
            children: [
              TableRow(children: [
                Padding(padding: EdgeInsets.all(8), child: Text('الحقل')),
                Padding(padding: EdgeInsets.all(8), child: Text('المستخرج')),
                Padding(padding: EdgeInsets.all(8), child: Text('المرجعي')),
              ]),
              TableRow(children: [
                Padding(padding: EdgeInsets.all(12), child: Text('—')),
                Padding(padding: EdgeInsets.all(12), child: Text('—')),
                Padding(padding: EdgeInsets.all(12), child: Text('—')),
              ]),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: null,
            icon: const Icon(Icons.compare_arrows),
            label: const Text('تنفيذ المقارنة'),
          ),
        ],
      );
}

class _ComparisonPanel extends StatelessWidget {
  const _ComparisonPanel({required this.title, required this.icon});
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: SizedBox(
          height: 140,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 36, color: const Color(0xFF94A3B8)),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              const Text('غير متاح', style: TextStyle(color: Color(0xFF64748B))),
            ],
          ),
        ),
      );
}

class OperationsWorkspaceScreen extends StatelessWidget {
  const OperationsWorkspaceScreen({super.key, required this.stationId});
  final String stationId;

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('الأجهزة والصيانة والاتصالات وتقنية المعلومات'),
            bottom: const TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: 'الأجهزة والصيانة'),
                Tab(text: 'الشبكات والاتصالات'),
                Tab(text: 'تقنية المعلومات'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _OperationsTab(
                title: 'سجل الأجهزة',
                message: 'سجل الأجهزة والأعطال والصيانة يحتاج إلى API للأصول والصيانة.',
                icon: Icons.sensors_outlined,
                stationId: stationId,
              ),
              _OperationsTab(
                title: 'حالة الشبكات والاتصالات',
                message: 'مراقبة الاتصال وآخر اتصال وجودة الشبكة غير متصلة بمصدر حالة حي.',
                icon: Icons.router,
                stationId: stationId,
              ),
              _OperationsTab(
                title: 'أصول وطلبات تقنية المعلومات',
                message: 'إدارة الأصول والبلاغات والتراخيص تنتظر عقود API المعتمدة.',
                icon: Icons.computer,
                stationId: stationId,
              ),
            ],
          ),
        ),
      );
}

class _OperationsTab extends StatelessWidget {
  const _OperationsTab({
    required this.title,
    required this.message,
    required this.icon,
    required this.stationId,
  });

  final String title;
  final String message;
  final IconData icon;
  final String stationId;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ServiceNotice(title: 'الوحدة غير متصلة بالخادم', message: message),
          const SizedBox(height: 12),
          Text('المحطة: ' + stationId),
          const SizedBox(height: 12),
          _MetricCard(label: 'السجلات', value: '—', icon: icon),
          const _MetricCard(label: 'البلاغات المفتوحة', value: '—', icon: Icons.report_problem_outlined),
          const _MetricCard(label: 'طلبات الصيانة', value: '—', icon: Icons.build_outlined),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: null,
            icon: const Icon(Icons.add),
            label: Text('إضافة سجل — ' + title),
          ),
        ],
      );
}

class ReportsWorkspaceScreen extends StatefulWidget {
  const ReportsWorkspaceScreen({super.key, required this.stationId});
  final String stationId;

  @override
  State<ReportsWorkspaceScreen> createState() => _ReportsWorkspaceScreenState();
}

class _ReportsWorkspaceScreenState extends State<ReportsWorkspaceScreen> {
  String _reportType = 'الرصد الساعي';

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('التقارير والإحصائيات')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _ServiceNotice(
              title: 'مصدر التقارير غير متصل',
              message: 'لن تظهر أرقام أو رسوم إحصائية رسمية قبل ربط بيانات الرصد المعتمدة وخدمات التقارير.',
            ),
            const SizedBox(height: 12),
            Text('المحطة: ' + widget.stationId),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _reportType,
              decoration: const InputDecoration(
                labelText: 'نوع التقرير',
                border: OutlineInputBorder(),
              ),
              items: const [
                'الرصد الساعي',
                'الرصد اليومي',
                'جودة البيانات',
                'التدقيق',
                'الأجهزة والأعطال',
              ].map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
              onChanged: (value) => setState(() => _reportType = value ?? _reportType),
            ),
            const SizedBox(height: 12),
            const _MetricCard(label: 'عدد السجلات', value: '—', icon: Icons.table_rows_outlined),
            const _MetricCard(label: 'نسبة الاكتمال', value: '—', icon: Icons.pie_chart_outline),
            const _MetricCard(label: 'الملاحظات', value: '—', icon: Icons.fact_check),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: null,
              icon: const Icon(Icons.assessment),
              label: const Text('إنشاء التقرير'),
            ),
            OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.print_outlined),
              label: const Text('طباعة / تصدير'),
            ),
          ],
        ),
      );
}
