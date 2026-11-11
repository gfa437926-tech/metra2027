import 'package:flutter/material.dart';

/// AFTN console presentation. Actual message traffic remains server-only until
/// the communication channel, routing policy and message templates are approved.
class AftnConsoleShellScreen extends StatefulWidget {
  const AftnConsoleShellScreen({super.key});

  @override
  State<AftnConsoleShellScreen> createState() => _AftnConsoleShellScreenState();
}

class _AftnConsoleShellScreenState extends State<AftnConsoleShellScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _origin = TextEditingController();
  final _addressees = TextEditingController();
  final _subject = TextEditingController();
  final _body = TextEditingController();
  String _priority = 'FF';
  String? _validation;

  static const _navy = Color(0xFF061B4A);

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _origin.dispose();
    _addressees.dispose();
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  void _preview() {
    final missing = <String>[];
    if (_origin.text.trim().isEmpty) missing.add('جهة الإرسال');
    if (_addressees.text.trim().isEmpty) missing.add('جهة/جهات الاستقبال');
    if (_body.text.trim().isEmpty) missing.add('نص الرسالة');
    setState(() => _validation = missing.isEmpty
      ? 'اكتملت الحقول الأساسية للمعاينة المحلية فقط. لم يتم التحقق من معيار AFTN أو إرسال الرسالة.'
      : 'الحقول الناقصة: ${missing.join('، ')}');
  }

  Future<void> _showPreview() async {
    _preview();
    if (_origin.text.trim().isEmpty ||
        _addressees.text.trim().isEmpty ||
        _body.text.trim().isEmpty) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('معاينة محلية — غير مرسلة'),
        content: SingleChildScrollView(
          child: SelectableText(
            'المرسل: ${_origin.text.trim()}\n'
            'المستقبل: ${_addressees.text.trim()}\n'
            'الأولوية: $_priority\n'
            'الموضوع: ${_subject.text.trim()}\n\n'
            '${_body.text.trim()}',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('إغلاق')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        title: const Text('وحدة AFTN'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.inbox_outlined), text: 'الوارد'),
            Tab(icon: Icon(Icons.outbox_outlined), text: 'الصادر'),
            Tab(icon: Icon(Icons.edit_note), text: 'إنشاء رسالة'),
            Tab(icon: Icon(Icons.rule), text: 'القناة والتدقيق'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [_inbox(), _outbox(), _compose(), _channel()],
      ),
    ),
  );

  Widget _inbox() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      _notice('صندوق الوارد لا يعرض رسائل حتى ربط قناة AFTN الخادمية. لن يتم توليد رسائل تجريبية.'),
      const SizedBox(height: 14),
      _empty(Icons.inbox_outlined, 'لا توجد رسائل واردة', 'سيتم تحميل الرسائل بعد التحقق من هوية المركز وصلاحية الاستقبال.'),
      _filterCard('مرشحات الوارد', ['فترة الاستلام UTC', 'رمز المرسل', 'الأولوية', 'حالة المعالجة']),
    ],
  );

  Widget _outbox() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      _notice('الصادر لا يرسل مباشرة من Flutter. الإرسال يجب أن يمر عبر بوابة خادمية مع اعتماد القناة والتوجيه والتدقيق.'),
      const SizedBox(height: 14),
      _empty(Icons.outbox_outlined, 'لا توجد رسائل صادرة', 'ستظهر هنا حالة الرسائل وإيصالات التسليم بعد الربط.'),
      _filterCard('مرشحات الصادر', ['فترة الإنشاء UTC', 'جهة الاستقبال', 'الأولوية', 'حالة التسليم']),
    ],
  );

  Widget _compose() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      _notice('هذه معاينة محلية لبنية الرسالة فقط. لا يوجد اتصال بمبدّل AFTN ولا اعتماد لقوالب الرسائل في هذه النسخة.'),
      const SizedBox(height: 14),
      const Text('بيانات التوجيه', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      TextField(controller: _origin, decoration: const InputDecoration(labelText: 'جهة الإرسال / Originator', border: OutlineInputBorder())),
      const SizedBox(height: 10),
      TextField(controller: _addressees, decoration: const InputDecoration(labelText: 'جهة أو جهات الاستقبال', border: OutlineInputBorder())),
      const SizedBox(height: 10),
      DropdownButtonFormField<String>(
        initialValue: _priority,
        decoration: const InputDecoration(labelText: 'الأولوية — اختيار أولي فقط', border: OutlineInputBorder()),
        items: const [
          DropdownMenuItem(value: 'SS', child: Text('SS — أعلى')),
          DropdownMenuItem(value: 'DD', child: Text('DD — عاجل')),
          DropdownMenuItem(value: 'FF', child: Text('FF — عادي')),
        ],
        onChanged: (value) => setState(() => _priority = value ?? _priority),
      ),
      const SizedBox(height: 10),
      TextField(controller: _subject, decoration: const InputDecoration(labelText: 'الموضوع (اختياري)', border: OutlineInputBorder())),
      const SizedBox(height: 10),
      TextField(
        controller: _body,
        minLines: 7,
        maxLines: 12,
        decoration: const InputDecoration(
          labelText: 'نص الرسالة',
          alignLabelWithHint: true,
          border: OutlineInputBorder(),
          helperText: 'لا يتم فحص القالب أو ترميز الرسالة قبل اعتماد معيار الرسائل.',
        ),
      ),
      const SizedBox(height: 12),
      if (_validation != null) Text(_validation!, style: const TextStyle(color: Color(0xFF9A5B00))),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: _showPreview,
        icon: const Icon(Icons.preview_outlined),
        label: const Text('معاينة محلية'),
      ),
      const SizedBox(height: 8),
      FilledButton.icon(
        onPressed: null,
        icon: const Icon(Icons.lock_outline),
        label: const Text('إرسال الرسالة غير متاح حتى اعتماد القناة الخادمية'),
      ),
    ],
  );

  Widget _channel() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      _notice('القناة غير متصلة. لا يتم كشف بيانات اعتماد الاتصال أو إعدادات الشبكة داخل تطبيق Flutter.'),
      const SizedBox(height: 14),
      _section('متطلبات التشغيل'),
      _step('قناة خادمية آمنة', 'استقبال وإرسال عبر خدمة موثوقة مع مراقبة الاتصال وإعادة المحاولة.'),
      _step('قوالب معتمدة', 'تعريف صيغ الرسائل والحقول والأولويات وقواعد التحقق.'),
      _step('عزل المركز والمحطة', 'التحقق من نطاق المستخدم قبل قراءة الرسائل أو إنشاء الإرسال.'),
      _step('سجل غير قابل للتلاعب', 'تسجيل المنفذ والتوقيت UTC والرسالة وحالة التسليم والسبب.'),
      _step('مراقبة التسليم', 'معرف الرسالة وإقرار الاستلام وحالات الفشل والتكرار.'),
      _empty(Icons.link_off_outlined, 'القناة غير مهيأة', 'لم يتم الاتصال بأي خادم AFTN من هذه الواجهة.'),
    ],
  );

  Widget _notice(String value) => Card(
    color: const Color(0xFFFFF7ED),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.info_outline, color: Color(0xFF9A5B00)),
        const SizedBox(width: 10),
        Expanded(child: Text(value, style: const TextStyle(height: 1.5))),
      ]),
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

  Widget _filterCard(String title, List<String> fields) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...fields.map((field) => ListTile(
          dense: true,
          leading: const Icon(Icons.filter_alt_outlined),
          title: Text(field),
          subtitle: const Text('يُفعّل عند ربط API'),
        )),
      ]),
    ),
  );

  Widget _section(String value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
  );

  Widget _step(String title, String description) => Card(
    child: ListTile(
      leading: const Icon(Icons.checklist_outlined),
      title: Text(title),
      subtitle: Text(description),
    ),
  );
}
