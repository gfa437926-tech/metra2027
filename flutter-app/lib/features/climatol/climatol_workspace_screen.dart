import 'package:flutter/material.dart';

import '../../core/api/metra_api_client.dart';

/// Climatol front-end workspace. Selection and validation are client-side;
/// processing must run in an isolated server worker once its API is approved.
class ClimatolWorkspaceScreen extends StatefulWidget {
  const ClimatolWorkspaceScreen({super.key, required this.api});

  final MetraApiClient api;

  @override
  State<ClimatolWorkspaceScreen> createState() => _ClimatolWorkspaceScreenState();
}

class _ClimatolWorkspaceScreenState extends State<ClimatolWorkspaceScreen>
    with SingleTickerProviderStateMixin {
  late Future<List<StationDirectoryItem>> _stations;
  late final TabController _tabs;
  final Set<String> _selectedStations = {};
  final Set<String> _selectedVariables = {'temperature'};
  String _referenceMode = 'regional';
  String _method = 'climatol';
  DateTimeRange? _period;
  bool _includeIncomplete = false;

  static const _navy = Color(0xFF071B49);
  static const _variables = <String, String>{
    'temperature': 'درجة الحرارة',
    'pressure': 'الضغط الجوي',
    'precipitation': 'الهطول',
    'humidity': 'الرطوبة النسبية',
    'wind_speed': 'سرعة الرياح',
  };

  @override
  void initState() {
    super.initState();
    _stations = widget.api.getAllStationDirectory();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _reloadStations() {
    setState(() => _stations = widget.api.getAllStationDirectory());
  }

  Future<void> _choosePeriod() async {
    final now = DateTime.now();
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange: _period,
      helpText: 'اختر فترة السلاسل الزمنية',
      saveText: 'اعتماد الفترة',
    );
    if (selected != null) setState(() => _period = selected);
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        title: const Text('تجانس السلاسل المناخية — Climatol'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.tune), text: 'إعداد التحليل'),
            Tab(icon: Icon(Icons.account_tree_outlined), text: 'خطوات المعالجة'),
            Tab(icon: Icon(Icons.analytics_outlined), text: 'التشخيص'),
            Tab(icon: Icon(Icons.history), text: 'الإصدارات'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [_configuration(), _pipeline(), _diagnostics(), _versions()],
      ),
    ),
  );

  Widget _configuration() => FutureBuilder<List<StationDirectoryItem>>(
    future: _stations,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return _messageState(
          Icons.cloud_off_outlined,
          'تعذر تحميل دليل المحطات',
          'لا يمكن إعداد مجموعة التجانس دون كتالوج المحطات المعتمد.',
          action: TextButton.icon(
            onPressed: _reloadStations,
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة المحاولة'),
          ),
        );
      }
      final stations = snapshot.data ?? const <StationDirectoryItem>[];
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _warning(),
          const SizedBox(height: 14),
          _heading('1. المحطات الداخلة في مجموعة التجانس'),
          TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'ابحث باسم المحطة أو رمزها',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => setState(() => _stationSearch = value.trim().toLowerCase()),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: stations.where((s) =>
                '${s.nameArabic} ${s.localCode}'.toLowerCase().contains(_stationSearch)
              ).map((station) => CheckboxListTile(
                value: _selectedStations.contains(station.id),
                title: Text(station.nameArabic),
                subtitle: Text('${station.localCode} • الارتفاع: ${station.elevationM?.toStringAsFixed(0) ?? 'غير متوفر'} م'),
                onChanged: (value) => setState(() {
                  if (value == true) {
                    _selectedStations.add(station.id);
                  } else {
                    _selectedStations.remove(station.id);
                  }
                }),
              )).toList(),
            ),
          ),
          Text('المحطات المحددة: ${_selectedStations.length}', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          _heading('2. المتغيرات المناخية'),
          ..._variables.entries.map((entry) => CheckboxListTile(
            value: _selectedVariables.contains(entry.key),
            title: Text(entry.value),
            onChanged: (value) => setState(() {
              if (value == true) {
                _selectedVariables.add(entry.key);
              } else {
                _selectedVariables.remove(entry.key);
              }
            }),
          )),
          const SizedBox(height: 12),
          _heading('3. الفترة الزمنية'),
          OutlinedButton.icon(
            onPressed: _choosePeriod,
            icon: const Icon(Icons.date_range),
            label: Text(_period == null
              ? 'تحديد بداية ونهاية الفترة'
              : '${_utcDate(_period!.start)} — ${_utcDate(_period!.end)} UTC'),
          ),
          const SizedBox(height: 12),
          _heading('4. طريقة المقارنة'),
          DropdownButtonFormField<String>(
            initialValue: _referenceMode,
            decoration: const InputDecoration(labelText: 'مجموعة المرجع', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'regional', child: Text('محطات إقليمية متقاربة')),
              DropdownMenuItem(value: 'elevation', child: Text('مراعاة نطاقات الارتفاع')),
              DropdownMenuItem(value: 'network', child: Text('شبكة المحطات المختارة')),
            ],
            onChanged: (v) => setState(() => _referenceMode = v ?? _referenceMode),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _method,
            decoration: const InputDecoration(labelText: 'منهج المعالجة', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'climatol', child: Text('Climatol — توحيد وتجانس')),
              DropdownMenuItem(value: 'diagnostic', child: Text('تشخيص أولي فقط')),
            ],
            onChanged: (v) => setState(() => _method = v ?? _method),
          ),
          CheckboxListTile(
            value: _includeIncomplete,
            title: const Text('إظهار السلاسل غير المكتملة ضمن التشخيص'),
            subtitle: const Text('لا يعني قبولها تلقائياً في المعالجة.'),
            onChanged: (v) => setState(() => _includeIncomplete = v ?? false),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: null,
            icon: const Icon(Icons.lock_outline),
            label: const Text('تشغيل التجانس غير متاح — العامل الخادمي غير مربوط'),
          ),
          const SizedBox(height: 8),
          Text(
            'الإعداد الحالي محلي للواجهة فقط: ${_selectedStations.length} محطة، ${_selectedVariables.length} متغير. لم يتم إرسال أو حفظ أي مهمة.',
            style: const TextStyle(color: Color(0xFF64748B)),
          ),
        ],
      );
    },
  );

  String _stationSearch = '';

  Widget _pipeline() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      _warning(),
      const SizedBox(height: 16),
      _heading('سير المعالجة المقترح'),
      _step(1, 'فحص المصدر', 'هوية المحطة، المتغير، الوحدة، التقويم، التوقيت UTC، القيم المفقودة وبصمة الملف.'),
      _step(2, 'فحص جودة السلاسل', 'الاستمرارية، التكرارات، القيم المستحيلة، الفجوات والتغيرات الوصفية.'),
      _step(3, 'اختيار السلاسل المرجعية', 'التقارب الجغرافي، الارتفاع، الارتباط الإحصائي وطول التداخل.'),
      _step(4, 'التشغيل المعزول', 'تنفيذ إصدار محدد من Climatol في عامل منفصل عن API الرئيسي.'),
      _step(5, 'مراجعة التشخيص', 'نقاط الانقطاع، المقاطع غير المتجانسة، المؤشرات وحدود الثقة.'),
      _step(6, 'اعتماد النتائج', 'مراجعة بشرية وحفظ إصدار جديد دون تعديل القيم الأصلية.'),
    ],
  );

  Widget _diagnostics() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      _warning(),
      const SizedBox(height: 16),
      _heading('لوحة التشخيص'),
      _empty(Icons.timeline, 'لا توجد نتائج تشخيص', 'تظهر الرسوم ونقاط الانقطاع بعد تنفيذ مهمة معتمدة واستلام نتائج العامل.'),
      _metric('فجوات البيانات', 'بانتظار نتائج الخادم'),
      _metric('الارتباط بين المحطات', 'بانتظار نتائج الخادم'),
      _metric('نقاط الانقطاع المحتملة', 'بانتظار نتائج الخادم'),
      _metric('مقاطع السلسلة غير المتجانسة', 'بانتظار نتائج الخادم'),
      _metric('بصمة مجموعة البيانات', 'غير متوفرة'),
    ],
  );

  Widget _versions() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      _warning(),
      const SizedBox(height: 16),
      _heading('إصدارات المعالجة'),
      _empty(Icons.inventory_2_outlined, 'لا توجد إصدارات محفوظة', 'يتطلب ذلك API لإدارة المهام والنتائج وبصمات البيانات وإصدارات البرنامج.'),
      _step(1, 'بيانات المصدر', 'معرف مجموعة البيانات وبصمة SHA-256 ومصدر كل سلسلة.'),
      _step(2, 'إعدادات التشغيل', 'إصدار Climatol والوسائط والمعايير وفترة UTC.'),
      _step(3, 'نتائج قابلة للإعادة', 'المخرجات والتشخيصات وسجل التنفيذ.'),
      _step(4, 'اعتماد بشري', 'اسم المعتمد ووقت UTC والنسخة المعتمدة وإمكانية التراجع.'),
    ],
  );

  Widget _warning() => const Card(
    color: Color(0xFFFFF7E8),
    child: Padding(
      padding: EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: Color(0xFF9A5B00)),
          SizedBox(width: 10),
          Expanded(child: Text('واجهة إعداد ومراجعة. لا يوجد عامل Climatol أو API للمهام في النسخة الحالية؛ لذلك لا يتم تشغيل خوارزمية أو عرض نتائج مصطنعة. السجلات الأصلية تبقى دون تعديل.', style: TextStyle(height: 1.45))),
        ],
      ),
    ),
  );

  Widget _heading(String value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _navy)),
  );

  Widget _step(int number, String title, String description) => Card(
    child: ListTile(
      leading: CircleAvatar(child: Text('$number')),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(description),
    ),
  );

  Widget _metric(String title, String value) => Card(
    child: ListTile(
      title: Text(title),
      trailing: Text(value, style: const TextStyle(color: Color(0xFF64748B))),
    ),
  );

  Widget _empty(IconData icon, String title, String description) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        Icon(icon, size: 38, color: const Color(0xFF64748B)),
        const SizedBox(height: 8),
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(description, textAlign: TextAlign.center),
      ]),
    ),
  );

  Widget _messageState(IconData icon, String title, String message, {Widget? action}) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 42),
        const SizedBox(height: 10),
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(message, textAlign: TextAlign.center),
        if (action != null) action,
      ]),
    ),
  );

  String _utcDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
