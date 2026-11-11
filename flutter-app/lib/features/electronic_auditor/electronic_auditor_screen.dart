import 'package:flutter/material.dart';

import '../../core/api/metra_api_client.dart';

/// Electronic audit UI. It intentionally does not claim OCR, chart digitization,
/// image storage, or comparison until the server-side audit API is available.
class ElectronicAuditorScreen extends StatefulWidget {
  const ElectronicAuditorScreen({super.key, this.api, this.initialTabIndex = 0});

  final MetraApiClient? api;
  final int initialTabIndex;

  @override
  State<ElectronicAuditorScreen> createState() => _ElectronicAuditorScreenState();
}

class _ElectronicAuditorScreenState extends State<ElectronicAuditorScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late Future<List<StationDirectoryItem>>? _stations;
  String? _stationId;
  String _track = 'paper';
  String _instrument = 'thermograph';
  String _registerType = 'daily';
  String _alignment = 'exact_utc';
  final _pageNumber = TextEditingController();
  final _caseNote = TextEditingController();
  final _calibrationNote = TextEditingController();
  DateTime? _periodDate;
  bool _paper = true;
  bool _mechanical = false;
  bool _electronic = true;

  static const _navy = Color(0xFF061B4A);
  static const _blue = Color(0xFF087CF0);

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 8, initialIndex: widget.initialTabIndex.clamp(0, 7).toInt(), vsync: this);
    _stations = widget.api?.getAllStationDirectory();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _pageNumber.dispose();
    _caseNote.dispose();
    _calibrationNote.dispose();
    super.dispose();
  }

  Future<void> _chooseDate() async {
    final now = DateTime.now().toUtc();
    final value = await showDatePicker(
      context: context,
      initialDate: _periodDate ?? DateTime.utc(now.year, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: DateTime.utc(now.year, now.month, now.day),
      helpText: 'تاريخ السجل (UTC)',
    );
    if (value != null) setState(() => _periodDate = value);
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        title: const Text('التدقيق الإلكتروني'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_outlined), text: 'لوحة التدقيق'),
            Tab(icon: Icon(Icons.menu_book_outlined), text: 'السجلات الورقية'),
            Tab(icon: Icon(Icons.show_chart), text: 'المسجلات الميكانيكية'),
            Tab(icon: Icon(Icons.compare_arrows), text: 'المقارنة'),
            Tab(icon: Icon(Icons.fact_check_outlined), text: 'مراجعة القراءات'),
            Tab(icon: Icon(Icons.library_books_outlined), text: 'المكتبة'),
            Tab(icon: Icon(Icons.model_training), text: 'مختبر التدريب'),
            Tab(icon: Icon(Icons.description_outlined), text: 'التقارير'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _dashboard(),
          _paperRegister(),
          _mechanicalChart(),
          _comparison(),
          _readingReview(),
          _library(),
          _training(),
          _reports(),
        ],
      ),
    ),
  );

  Widget _dashboard() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      _notice('هيكلية فقط — لا يوجد حتى الآن API تشغيلي لحالات التدقيق أو رفع الصور أو OCR. لا تُنشأ أرقام أو نتائج وهمية.'),
      const SizedBox(height: 14),
      _section('ملخص الحالات'),
      GridView.count(
        crossAxisCount: MediaQuery.sizeOf(context).width > 720 ? 4 : 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.2,
        children: [
          _metric('واردة', '—', Icons.inbox_outlined),
          _metric('مطابقة', '—', Icons.verified_outlined),
          _metric('اختلافات', '—', Icons.compare_arrows),
          _metric('بانتظار المراجع', '—', Icons.pending_actions),
        ],
      ),
      const SizedBox(height: 12),
      _section('إنشاء سياق التدقيق'),
      _stationSelector(),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: _chooseDate,
        icon: const Icon(Icons.calendar_month),
        label: Text(_periodDate == null ? 'تحديد تاريخ UTC' : _utcDate(_periodDate!)),
      ),
      const SizedBox(height: 10),
      DropdownButtonFormField<String>(
        initialValue: _track,
        decoration: const InputDecoration(labelText: 'مسار التدقيق', border: OutlineInputBorder()),
        items: const [
          DropdownMenuItem(value: 'paper', child: Text('السجل الورقي')),
          DropdownMenuItem(value: 'mechanical', child: Text('المسجل الميكانيكي')),
          DropdownMenuItem(value: 'combined', child: Text('ثلاثي المصادر')),
        ],
        onChanged: (v) => setState(() => _track = v ?? _track),
      ),
      const SizedBox(height: 10),
      TextField(controller: _caseNote, decoration: const InputDecoration(labelText: 'ملاحظة تعريفية للحالة', border: OutlineInputBorder())),
      const SizedBox(height: 10),
      FilledButton.icon(
        onPressed: null,
        icon: const Icon(Icons.lock_outline),
        label: const Text('إنشاء حالة — API غير متاح'),
      ),
      const SizedBox(height: 14),
      _empty('لا توجد حالات معروضة', 'ستظهر هنا الحالات التي يتيحها الخادم ضمن نطاق المحطة والصلاحيات.'),
    ],
  );

  Widget _paperRegister() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      _notice('مسار السجل الورقي: حفظ الأصل وبصمة SHA-256، ثم استخراج الخانات وربط كل قيمة بمربعها على الصورة. الرفع والاستخراج غير مفعّلين لغياب API والتخزين المعتمد.'),
      const SizedBox(height: 14),
      _section('بيانات صفحة السجل'),
      _stationSelector(),
      const SizedBox(height: 10),
      DropdownButtonFormField<String>(
        initialValue: _registerType,
        decoration: const InputDecoration(labelText: 'نوع السجل', border: OutlineInputBorder()),
        items: const [
          DropdownMenuItem(value: 'daily', child: Text('سجل يومي')),
          DropdownMenuItem(value: 'hourly', child: Text('سجل ساعي')),
          DropdownMenuItem(value: 'other', child: Text('نموذج آخر — يتطلب تعريفاً')),
        ],
        onChanged: (v) => setState(() => _registerType = v ?? _registerType),
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(onPressed: _chooseDate, icon: const Icon(Icons.date_range), label: Text(_periodDate == null ? 'تاريخ السجل UTC' : _utcDate(_periodDate!))),
      const SizedBox(height: 10),
      TextField(controller: _pageNumber, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'رقم الصفحة', border: OutlineInputBorder())),
      const SizedBox(height: 14),
      _uploadPlaceholder('صورة أو مسح ضوئي لصفحة السجل'),
      const SizedBox(height: 10),
      FilledButton.icon(onPressed: null, icon: const Icon(Icons.lock_outline), label: const Text('رفع الصفحة — بانتظار API التخزين')),
      _section('بعد الرفع'),
      _step('تصنيف النموذج', 'تحديد القالب مع تأكيد بشري عند الشك.'),
      _step('استخراج الخانات', 'القيم والوحدات والأوقات مع مواضعها على الصورة.'),
      _step('مراجعة بشرية', 'تصحيح القيمة المستخرجة مع تسجيل مصدر التصحيح.'),
    ],
  );

  Widget _mechanicalChart() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      _notice('لا يُفترض أن جميع المخططات لها مقياس واحد. يجب تعريف نوع الجهاز والطراز والمدى والمعايرة قبل رقمنة المنحنى.'),
      const SizedBox(height: 14),
      _section('تعريف الجهاز والمخطط'),
      _stationSelector(),
      const SizedBox(height: 10),
      DropdownButtonFormField<String>(
        initialValue: _instrument,
        decoration: const InputDecoration(labelText: 'نوع المسجل', border: OutlineInputBorder()),
        items: const [
          DropdownMenuItem(value: 'thermograph', child: Text('Thermograph — الحرارة')),
          DropdownMenuItem(value: 'hygrograph', child: Text('Hygrograph — الرطوبة')),
          DropdownMenuItem(value: 'barograph', child: Text('Barograph — الضغط')),
          DropdownMenuItem(value: 'pluviograph', child: Text('Pluviograph — الهطول')),
        ],
        onChanged: (v) => setState(() => _instrument = v ?? _instrument),
      ),
      const SizedBox(height: 10),
      TextField(controller: _calibrationNote, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'مرجع المعايرة / ملاحظات المختص', border: OutlineInputBorder())),
      const SizedBox(height: 14),
      _uploadPlaceholder('صورة مخطط المسجل الميكانيكي'),
      const SizedBox(height: 10),
      FilledButton.icon(onPressed: null, icon: const Icon(Icons.lock_outline), label: const Text('رفع المخطط — بانتظار API التخزين')),
      _section('مراحل الرقمنة'),
      _step('تعريف المحاور', 'وحدات القياس، المدى، اتجاه الزمن، ومعايرة المحور.'),
      _step('تحديد المنحنى', 'استخراج نقاط مع ثقة ومؤشر موضع على الصورة.'),
      _step('المراجعة', 'اعتماد نقاط مرجعية بشرية قبل المقارنة.'),
    ],
  );

  Widget _comparison() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      _notice('المقارنة لا تبدأ قبل توفر مصادر موثقة وفترة متطابقة. لا تُنشأ قيم توضيحية على أنها بيانات فعلية.'),
      const SizedBox(height: 14),
      _section('مصادر المقارنة'),
      CheckboxListTile(value: _paper, title: const Text('السجل الورقي'), onChanged: (v) => setState(() => _paper = v ?? false)),
      CheckboxListTile(value: _mechanical, title: const Text('المسجل الميكانيكي'), onChanged: (v) => setState(() => _mechanical = v ?? false)),
      CheckboxListTile(value: _electronic, title: const Text('الرصد الإلكتروني من METRA'), onChanged: (v) => setState(() => _electronic = v ?? false)),
      const SizedBox(height: 10),
      DropdownButtonFormField<String>(
        initialValue: _alignment,
        decoration: const InputDecoration(labelText: 'قاعدة محاذاة الوقت UTC', border: OutlineInputBorder()),
        items: const [
          DropdownMenuItem(value: 'exact_utc', child: Text('تطابق وقت UTC')),
          DropdownMenuItem(value: 'nearest_sample', child: Text('أقرب عينة وفق سماحية معتمدة')),
          DropdownMenuItem(value: 'window', child: Text('نافذة زمنية وفق سياسة المتغير')),
        ],
        onChanged: (v) => setState(() => _alignment = v ?? _alignment),
      ),
      const SizedBox(height: 14),
      _section('ناتج المقارنة'),
      _empty('لا توجد نتائج مقارنة', 'ستعرض النتائج قيمة كل مصدر والفارق ووحدة القياس وموضع الصورة وإصدار قاعدة التحقق.'),
      FilledButton.icon(onPressed: null, icon: const Icon(Icons.lock_outline), label: const Text('تنفيذ المقارنة — بانتظار خدمة المقارنة')),
    ],
  );

  Widget _readingReview() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      _notice('التصحيح البشري يسجل القيمة السابقة والجديدة والمراجع والوقت UTC. لا يتم تعديل الرصد الإلكتروني الأصلي من شاشة التدقيق.'),
      const SizedBox(height: 14),
      _empty('لا توجد قراءات بانتظار المراجعة', 'قائمة المراجعة ستأتي من API مع صلاحية القراءة والتصحيح.'),
      _section('أنواع النتائج'),
      _step('مطابقة', 'المصادر متوافقة ضمن سماحية المتغير المعتمدة.'),
      _step('اختلاف', 'يوجد فرق يحتاج إلى تفسير ومراجعة.'),
      _step('غير حاسم', 'جودة الصورة أو التوقيت أو المعايرة لا تسمح بالحكم.'),
      _step('مرفوض', 'الصورة غير مقروءة أو خارج القالب المدعوم.'),
      _section('قرار المراجع'),
      const TextField(enabled: false, decoration: InputDecoration(labelText: 'ملاحظة المراجع', border: OutlineInputBorder())),
      const SizedBox(height: 10),
      const FilledButton(onPressed: null, child: Text('حفظ القرار — بانتظار API')),
    ],
  );

  Widget _library() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      _notice('المكتبة لا تُنشأ من افتراضات. تُضاف قوالب السجلات وأجهزة القياس فقط بعد توثيق المصدر والطراز والمقياس والمعايرة.'),
      const SizedBox(height: 14),
      _section('قوالب السجلات'),
      _empty('لا توجد قوالب معتمدة في هذه الواجهة', 'تحتاج المكتبة إلى سجل قوالب موثق وإصدارات وتاريخ اعتماد.'),
      _section('أجهزة القياس'),
      ...['Thermograph', 'Hygrograph', 'Barograph', 'Pluviograph'].map((name) => Card(child: ListTile(leading: const Icon(Icons.settings_input_component_outlined), title: Text(name), subtitle: const Text('تعريف الطراز والمقياس والمعايرة مطلوب')))),
      FilledButton.icon(onPressed: null, icon: const Icon(Icons.lock_outline), label: const Text('إدارة المكتبة — بانتظار صلاحيات وAPI')),
    ],
  );

  Widget _training() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      _notice('التدريب منفصل ومعزول. لا تستخدم مخرجات النموذج غير المعتمدة كوسوم تدريب، ولا يُرقّى نموذج دون مجموعة اختبار مستقلة وموافقة بشرية.'),
      const SizedBox(height: 14),
      _section('مراحل مختبر التدريب'),
      _step('مجموعة البيانات', 'مصدر الصور وبصمتها والمحطات وأجهزة الالتقاط.'),
      _step('الوسوم المرجعية', 'قيمة ومربع الصورة أو نقاط المنحنى مع اعتماد المختص.'),
      _step('تقسيم البيانات', 'تدريب / تحقق / اختبار مع منع تسرب الصور بين المجموعات.'),
      _step('التقييم', 'مقاييس على صور ومحطات لم تدخل التدريب.'),
      _step('ترقية النموذج', 'موافقة مسؤول النموذج مع الإصدار السابق وخطة التراجع.'),
      _empty('لا توجد مجموعات تدريب أو إصدارات', 'تظهر الوظائف بعد تجهيز بيئة التدريب المعزولة وAPI الحوكمة.'),
    ],
  );

  Widget _reports() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      _notice('تقرير التدقيق النهائي يجب أن يحتوي على الأدلة والمصادر والفترة UTC والنتائج وإصدارات النماذج والقواعد والقرار البشري.'),
      const SizedBox(height: 14),
      _empty('لا توجد تقارير تدقيق', 'لا يتم إنشاء تقرير قبل وجود حالة ونتائج موثقة.'),
      _step('ملخص الحالة', 'المحطة والفترة والمسار ومقدم الحالة.'),
      _step('الأدلة', 'أصول الصور وبصمات SHA-256 والنسخ المعالجة.'),
      _step('الفروقات', 'القيم والفوارق ومصدر كل قراءة وموضعها.'),
      _step('القرار', 'اسم المراجع والقرار والسبب ووقت UTC.'),
      FilledButton.icon(onPressed: null, icon: const Icon(Icons.lock_outline), label: const Text('تصدير التقرير — بانتظار API')),
    ],
  );

  Widget _stationSelector() {
    if (_stations == null) {
      return const Text('دليل المحطات غير متاح — افتح هذه الشاشة من التطبيق بعد تهيئة API.');
    }
    return FutureBuilder<List<StationDirectoryItem>>(
      future: _stations,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator();
        }
        if (snapshot.hasError) {
          return const Text('تعذر تحميل المحطات المصرح بها.');
        }
        final stations = snapshot.data ?? const <StationDirectoryItem>[];
        return DropdownButtonFormField<String>(
          initialValue: stations.any((s) => s.id == _stationId) ? _stationId : null,
          decoration: const InputDecoration(labelText: 'المحطة', border: OutlineInputBorder()),
          items: stations.map((s) => DropdownMenuItem(value: s.id, child: Text('${s.nameArabic} — ${s.localCode}'))).toList(),
          onChanged: (v) => setState(() => _stationId = v),
        );
      },
    );
  }

  Widget _notice(String value) => Card(
    color: const Color(0xFFFFF7E8),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.info_outline, color: Color(0xFF9A5B00)),
        const SizedBox(width: 10),
        Expanded(child: Text(value, style: const TextStyle(height: 1.5))),
      ]),
    ),
  );

  Widget _section(String value) => Padding(
    padding: const EdgeInsets.only(bottom: 10, top: 6),
    child: Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _navy)),
  );

  Widget _metric(String title, String value, IconData icon) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: _blue),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(title, textAlign: TextAlign.center),
      ]),
    ),
  );

  Widget _empty(String title, String description) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        const Icon(Icons.inbox_outlined, size: 36, color: Color(0xFF64748B)),
        const SizedBox(height: 8),
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(description, textAlign: TextAlign.center, style: const TextStyle(height: 1.45)),
      ]),
    ),
  );

  Widget _step(String title, String description) => Card(
    child: ListTile(
      leading: const Icon(Icons.checklist_outlined, color: _blue),
      title: Text(title),
      subtitle: Text(description),
    ),
  );

  Widget _uploadPlaceholder(String title) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      border: Border.all(color: const Color(0xFF94A3B8), style: BorderStyle.solid),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(children: [
      const Icon(Icons.cloud_upload_outlined, size: 38, color: _blue),
      const SizedBox(height: 8),
      Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      const Text('لم يتم تفعيل اختيار الملفات قبل اعتماد مخزن الصور وواجهة الرفع.', textAlign: TextAlign.center),
    ]),
  );

  String _utcDate(DateTime value) =>
      '${value.toUtc().year.toString().padLeft(4, '0')}-${value.toUtc().month.toString().padLeft(2, '0')}-${value.toUtc().day.toString().padLeft(2, '0')} UTC';
}
