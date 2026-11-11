import 'package:flutter/material.dart';

/// AI workspace presentation. All inference and sensitive data access must be
/// routed through the ASP.NET AI gateway; no client-side provider keys or fake
/// meteorological outputs are used here.
class AiWorkspaceScreen extends StatefulWidget {
  const AiWorkspaceScreen({super.key});

  @override
  State<AiWorkspaceScreen> createState() => _AiWorkspaceScreenState();
}

class _AiWorkspaceScreenState extends State<AiWorkspaceScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _prompt = TextEditingController();
  String _task = 'explain';
  String _source = 'authorized_station';
  String _period = 'latest_24h';

  static const _navy = Color(0xFF071B49);
  static const _blue = Color(0xFF1677D2);

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _prompt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: _navy,
          foregroundColor: Colors.white,
          title: const Text('مساحة الذكاء الاصطناعي'),
          bottom: TabBar(
            controller: _tabs,
            isScrollable: true,
            tabs: const [
              Tab(icon: Icon(Icons.dashboard_outlined), text: 'الرئيسية'),
              Tab(icon: Icon(Icons.auto_awesome_outlined), text: 'التحليل'),
              Tab(icon: Icon(Icons.warning_amber_outlined), text: 'الشذوذ'),
              Tab(icon: Icon(Icons.summarize_outlined), text: 'التقارير'),
              Tab(icon: Icon(Icons.policy_outlined), text: 'الحوكمة'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabs,
          children: [
            _overview(),
            _analysis(),
            _anomalies(),
            _reports(),
            _governance(),
          ],
        ),
      ),
    );
  }

  Widget _overview() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      _statusBanner(),
      const SizedBox(height: 16),
      const Text('مسارات العمل', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      _feature(Icons.query_stats, 'تحليل السلاسل الزمنية', 'تحليل القيم والفجوات والاتجاهات ضمن نطاق المحطة المصرح به.'),
      _feature(Icons.rule_folder_outlined, 'تفسير قواعد التحقق', 'شرح سبب إطلاق قاعدة فيزيائية أو رياضية مع إصدار القاعدة.'),
      _feature(Icons.travel_explore, 'اكتشاف القيم الشاذة', 'اقتراح حالات للمراجعة البشرية دون تعديل السجلات الأصلية.'),
      _feature(Icons.summarize, 'تلخيص النشرات', 'تلخيص موثق للمصدر والفترة، مع فصل القياس عن الاستنتاج.'),
      _feature(Icons.insights, 'دعم القرار', 'عرض البدائل والقيود ودرجة عدم اليقين ومصدر كل معلومة.'),
      const SizedBox(height: 16),
      _section('ضوابط الاستخدام'),
      const Text('• لا تُعامل مخرجات النموذج على أنها رصدات فعلية.\n• لا يعتمد النموذج نشرة ولا يعدّلها.\n• كل إجابة يجب أن تتضمن مصدر البيانات وفترتها وإصدار النموذج.\n• القرار النهائي للمختص المخوّل.', style: TextStyle(height: 1.7)),
    ],
  );

  Widget _analysis() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      _statusBanner(),
      const SizedBox(height: 16),
      _section('إعداد طلب التحليل'),
      DropdownButtonFormField<String>(
        value: _task,
        decoration: const InputDecoration(labelText: 'نوع المهمة', border: OutlineInputBorder()),
        items: const [
          DropdownMenuItem(value: 'explain', child: Text('تفسير حالة جوية')),
          DropdownMenuItem(value: 'trend', child: Text('تحليل اتجاه زمني')),
          DropdownMenuItem(value: 'quality', child: Text('تفسير جودة البيانات')),
          DropdownMenuItem(value: 'summary', child: Text('تلخيص نشرة')),
          DropdownMenuItem(value: 'compare', child: Text('مقارنة محطات')),
        ],
        onChanged: (v) => setState(() => _task = v ?? _task),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: _source,
        decoration: const InputDecoration(labelText: 'نطاق مصدر البيانات', border: OutlineInputBorder()),
        items: const [
          DropdownMenuItem(value: 'authorized_station', child: Text('المحطات المصرح بها فقط')),
          DropdownMenuItem(value: 'selected_observations', child: Text('رصدات محددة')),
          DropdownMenuItem(value: 'approved_bulletins', child: Text('نشرات معتمدة')),
        ],
        onChanged: (v) => setState(() => _source = v ?? _source),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: _period,
        decoration: const InputDecoration(labelText: 'الفترة الزمنية (UTC)', border: OutlineInputBorder()),
        items: const [
          DropdownMenuItem(value: 'latest_24h', child: Text('آخر 24 ساعة')),
          DropdownMenuItem(value: 'latest_7d', child: Text('آخر 7 أيام')),
          DropdownMenuItem(value: 'latest_30d', child: Text('آخر 30 يوماً')),
          DropdownMenuItem(value: 'custom', child: Text('فترة مخصصة — تتطلب تحديداً لاحقاً')),
        ],
        onChanged: (v) => setState(() => _period = v ?? _period),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _prompt,
        minLines: 4,
        maxLines: 7,
        decoration: const InputDecoration(
          labelText: 'سؤال المختص أو تعليمات التحليل',
          hintText: 'اكتب السؤال دون إدخال بيانات شخصية أو أسرار تشغيلية...',
          border: OutlineInputBorder(),
          alignLabelWithHint: true,
        ),
      ),
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: null,
        icon: const Icon(Icons.lock_outline),
        label: const Text('تنفيذ التحليل غير متاح حتى ربط AI Gateway'),
      ),
      const SizedBox(height: 8),
      const Text('تم حفظ إعدادات النموذج في هذه الشاشة فقط. لم يتم إرسال السؤال أو قراءة أي بيانات.', style: TextStyle(color: Color(0xFF64748B))),
    ],
  );

  Widget _anomalies() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      _statusBanner(),
      const SizedBox(height: 16),
      _section('مركز الحالات الشاذة'),
      const Text('ستظهر الحالات بعد ربط محرك التحليل الخادمي. لا توجد نتائج تجريبية أو قيم شاذة مصطنعة في هذه الشاشة.'),
      const SizedBox(height: 14),
      _empty(Icons.analytics_outlined, 'لا توجد نتائج متاحة', 'لم يتم تشغيل محرك الشذوذ أو استلام نتائج من الخادم.'),
      _feature(Icons.thermostat, 'القيم الفيزيائية', 'فحص الحدود والعلاقات بين المتغيرات.'),
      _feature(Icons.show_chart, 'الانحراف الزمني', 'مقارنة القيمة بخط الأساس المعتمد والسياق الزمني.'),
      _feature(Icons.compare_arrows, 'الاختلاف المكاني', 'مقارنة المحطات مع مراعاة الارتفاع والإحداثيات وجودة القياس.'),
    ],
  );

  Widget _reports() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      _statusBanner(),
      const SizedBox(height: 16),
      _section('تقارير التحليل'),
      _empty(Icons.description_outlined, 'لا توجد تقارير مولّدة', 'ستعرض التقارير هنا بعد تفعيل API وتسجيل المصدر والفترة وإصدار النموذج.'),
      _feature(Icons.verified_outlined, 'سجل المصادر', 'المحطة، المتغير، فترة UTC، معرف النشرة وبصمة البيانات.'),
      _feature(Icons.model_training_outlined, 'بيانات النموذج', 'اسم النموذج وإصداره وإعدادات التشغيل.'),
      _feature(Icons.rule_outlined, 'القيود وعدم اليقين', 'الافتراضات، مستوى الثقة، البيانات الناقصة والتنبيهات.'),
    ],
  );

  Widget _governance() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      _statusBanner(),
      const SizedBox(height: 16),
      _section('حوكمة الذكاء الاصطناعي'),
      _feature(Icons.key_outlined, 'بوابة الوصول', 'جميع الطلبات تمر عبر ASP.NET Core مع تحقق صلاحيات المحطة.'),
      _feature(Icons.history, 'سجل الاستخدام', 'من نفّذ التحليل ومتى وعلى أي مصدر وبأي نموذج.'),
      _feature(Icons.rule, 'المراجعة البشرية', 'لا اعتماد تلقائياً ولا تعديل على الرصدات.'),
      _feature(Icons.model_training, 'إصدارات النماذج', 'تقييم مستقل، اعتماد مسؤول، وإمكانية الرجوع لإصدار سابق.'),
      _feature(Icons.shield_outlined, 'حماية البيانات', 'منع المفاتيح والأسرار في التطبيق، وتقليل البيانات المرسلة للنموذج.'),
    ],
  );

  Widget _statusBanner() => Card(
    color: const Color(0xFFFFF7E8),
    child: const Padding(
      padding: EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_clock_outlined, color: Color(0xFF9A5B00)),
          SizedBox(width: 10),
          Expanded(child: Text('واجهة العمل جاهزة للمراجعة التصميمية. الربط التشغيلي ينتظر AI Gateway وعقد البيانات والصلاحيات؛ لم تُعرض أي نتائج وهمية.', style: TextStyle(height: 1.45))),
        ],
      ),
    ),
  );

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _navy)),
  );

  Widget _feature(IconData icon, String title, String description) => Card(
    child: ListTile(
      leading: Icon(icon, color: _blue),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(description),
    ),
  );

  Widget _empty(IconData icon, String title, String message) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(icon, size: 36, color: const Color(0xFF64748B)),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF64748B), height: 1.45)),
        ],
      ),
    ),
  );
}
