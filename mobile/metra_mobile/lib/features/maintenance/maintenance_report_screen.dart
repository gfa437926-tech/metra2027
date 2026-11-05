import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Maintenance intake is saved on-device until the approved server contract exists.
class MaintenanceReportScreen extends StatefulWidget {
  const MaintenanceReportScreen({super.key});
  @override
  State<MaintenanceReportScreen> createState() => _MaintenanceReportScreenState();
}

class _MaintenanceReportScreenState extends State<MaintenanceReportScreen> {
  static const _storage = FlutterSecureStorage();
  static const _draftKey = 'metra.maintenance.drafts.v1';
  final _formKey = GlobalKey<FormState>();
  final _equipment = TextEditingController();
  final _description = TextEditingController();
  final _search = TextEditingController();
  String _category = 'أجهزة الرصد';
  String _severity = 'High';
  String _severityFilter = 'الكل';
  String _categoryFilter = 'الكل';
  bool _blockingOnly = false;
  bool _blocking = false;
  bool _saving = false;
  String? _editingId;
  List<Map<String, dynamic>> _drafts = [];

  @override
  void initState() {
    super.initState();
    _loadDrafts();
  }

  Future<void> _exportDrafts() async {
    if (_drafts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا توجد بلاغات لتصديرها.')));
      return;
    }
    await Clipboard.setData(ClipboardData(text: const JsonEncoder.withIndent('  ').convert({
      'format': 'metra-maintenance-drafts-v1',
      'exportedAt': DateTime.now().toIso8601String(),
      'drafts': _drafts,
    })));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم نسخ نسخة JSON من البلاغات إلى الحافظة.')),
    );
  }

  Future<void> _importDraftsFromClipboard() async {
    try {
      final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
      final raw = clipboard?.text;
      if (raw == null || raw.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الحافظة فارغة؛ انسخ ملف JSON أولاً.')));
        return;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> || decoded['format'] != 'metra-maintenance-drafts-v1' || decoded['drafts'] is! List) {
        throw const FormatException('Invalid METRA backup format');
      }
      final imported = <Map<String, dynamic>>[];
      for (final item in decoded['drafts'] as List) {
        if (item is! Map) continue;
        final draft = Map<String, dynamic>.from(item);
        final id = draft['id']?.toString();
        final equipment = draft['equipment']?.toString().trim() ?? '';
        final description = draft['description']?.toString().trim() ?? '';
        if (id == null || id.isEmpty || equipment.length < 2 || description.length < 10) continue;
        draft['id'] = id;
        draft['status'] = 'local_draft';
        imported.add(draft);
      }
      if (imported.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لم يتضمن ملف النسخة الاحتياطية بلاغات صالحة.')));
        return;
      }
      final existingIds = _drafts.map((draft) => draft['id'].toString()).toSet();
      final updates = imported.where((draft) => existingIds.contains(draft['id'].toString())).length;
      final additions = imported.length - updates;
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('تأكيد استيراد البلاغات'),
          content: Text('سيتم إضافة $additions بلاغ جديد وتحديث $updates بلاغ موجود. هل تريد المتابعة؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('استيراد')),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      final byId = <String, Map<String, dynamic>>{for (final draft in _drafts) draft['id'].toString(): draft};
      for (final draft in imported) { byId[draft['id'].toString()] = draft; }
      final merged = byId.values.toList()
        ..sort((a, b) => (b['createdAt'] ?? '').toString().compareTo((a['createdAt'] ?? '').toString()));
      await _storage.write(key: _draftKey, value: jsonEncode(merged));
      if (!mounted) return;
      setState(() => _drafts = merged);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('اكتمل الاستيراد: $additions جديد، $updates تحديث.')),
      );
    } on FormatException {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('صيغة النسخة الاحتياطية غير صحيحة أو غير متوافقة.')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر استيراد البلاغات من الحافظة.')));
    }
  }

  Future<void> _loadDrafts() async {
    try {
      final raw = await _storage.read(key: _draftKey);
      final decoded = raw == null ? [] : jsonDecode(raw) as List<dynamic>;
      if (mounted) setState(() => _drafts = decoded.cast<Map<String, dynamic>>());
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر قراءة البلاغات المحلية.')),
        );
      }
    }
  }

  Future<void> _saveDraft() async {
    if (!_formKey.currentState!.validate()) return;
    if (_blocking && _severity == 'Low') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('العطل الذي يوقف العمل يجب أن يكون متوسطاً أو أعلى.')),
      );
      return;
    }
    setState(() => _saving = true);
    final draft = <String, dynamic>{
      'id': _editingId ?? DateTime.now().microsecondsSinceEpoch.toString(),
      'category': _category,
      'equipment': _equipment.text.trim(),
      'severity': _severity,
      'blocking': _blocking,
      'description': _description.text.trim(),
      'createdAt': _drafts.where((d) => d['id'] == _editingId).map((d) => d['createdAt']).firstOrNull ?? DateTime.now().toIso8601String(),
      'status': 'local_draft',
    };
    try {
      final next = _editingId == null ? [draft, ..._drafts] : _drafts.map((item) => item['id'] == _editingId ? draft : item).toList();
      await _storage.write(key: _draftKey, value: jsonEncode(next));
      if (!mounted) return;
      setState(() { _drafts = next; _saving = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حُفظ البلاغ على هذا الجهاز بشكل آمن.')),
      );
      _resetFields();
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل حفظ البلاغ محلياً؛ لم يتم حذف البيانات من النموذج.')),
        );
      }
    }
  }

  Future<void> _deleteDraft(String id) async {
    final next = _drafts.where((draft) => draft['id'] != id).toList();
    try {
      await _storage.write(key: _draftKey, value: jsonEncode(next));
      if (mounted) setState(() { _drafts = next; if (_editingId == id) _resetFields(); });
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر حذف المسودة المحلية.')),
      );
    }
  }

  void _resetFields() {
    _formKey.currentState?.reset();
    _equipment.clear();
    _description.clear();
    setState(() {
      _category = 'أجهزة الرصد';
      _severity = 'High';
      _blocking = false;
      _editingId = null;
    });
  }

  @override
  void dispose() {
    _equipment.dispose();
    _description.dispose();
    _search.dispose();
    super.dispose();
  }

  Widget _summaryTile(String label, int count, Color background, Color foreground) => Container(
    constraints: const BoxConstraints(minWidth: 105),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(14)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(count.toString(), style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: foreground)),
      const SizedBox(height: 3),
      Text(label, style: TextStyle(fontSize: 12, color: foreground)),
    ]),
  );

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Card(
          elevation: 0,
          color: const Color(0xFF061B4A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: const Padding(
            padding: EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.build_circle_outlined, color: Colors.white, size: 34),
              SizedBox(height: 12),
              Text('بلاغ عطل وصيانة', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('أنشئ البلاغ واحفظه محلياً بأمان حتى يتوفر الربط الخادمي المعتمد.',
                style: TextStyle(color: Color(0xFFD6E8FF))),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Form(
              key: _formKey,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                DropdownButtonFormField<String>(
                  value: _category,
                  decoration: const InputDecoration(labelText: 'تصنيف المعدة'),
                  items: const [
                    DropdownMenuItem(value: 'أجهزة الرصد', child: Text('أجهزة الرصد')),
                    DropdownMenuItem(value: 'الاتصالات', child: Text('الاتصالات')),
                    DropdownMenuItem(value: 'الحاسب والشبكة', child: Text('الحاسب والشبكة')),
                    DropdownMenuItem(value: 'الكهرباء والطاقة', child: Text('الكهرباء والطاقة')),
                    DropdownMenuItem(value: 'أخرى', child: Text('أخرى')),
                  ],
                  onChanged: (value) => setState(() => _category = value ?? _category),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _equipment,
                  decoration: const InputDecoration(labelText: 'اسم الجهاز', hintText: 'مثال: مقياس الحرارة'),
                  textInputAction: TextInputAction.next,
                  validator: (value) => (value == null || value.trim().length < 2)
                    ? 'أدخل اسم الجهاز (محرفان على الأقل).' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _severity,
                  decoration: const InputDecoration(labelText: 'شدة العطل'),
                  items: const [
                    DropdownMenuItem(value: 'Low', child: Text('منخفض')),
                    DropdownMenuItem(value: 'Medium', child: Text('متوسط')),
                    DropdownMenuItem(value: 'High', child: Text('عالٍ')),
                    DropdownMenuItem(value: 'Critical', child: Text('حرج')),
                  ],
                  onChanged: (value) => setState(() => _severity = value ?? _severity),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('العطل يوقف العمل'),
                  value: _blocking,
                  onChanged: (value) => setState(() => _blocking = value),
                ),
                TextFormField(
                  controller: _description,
                  minLines: 4,
                  maxLines: 6,
                  maxLength: 4000,
                  decoration: const InputDecoration(labelText: 'وصف العطل', hintText: 'صف المشكلة ووقت ظهورها وأثرها على العمل.'),
                  validator: (value) => (value == null || value.trim().length < 10)
                    ? 'الوصف يجب ألا يقل عن 10 محارف.' : null,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _saving ? null : _saveDraft,
                  icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'جارٍ الحفظ...' : (_editingId == null ? 'حفظ البلاغ محلياً' : 'تحديث المسودة')),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _resetFields,
                  icon: const Icon(Icons.refresh),
                  label: const Text('مسح النموذج'),
                ),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(children: [
          const Expanded(child: Text('ملخص البلاغات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          Text('${_drafts.length} إجمالي'),
        ]),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _summaryTile('كل البلاغات', _drafts.length, const Color(0xFFEAF1FF), const Color(0xFF173B78)),
            _summaryTile('أعطال حرجة', _drafts.where((d) => d['severity'] == 'Critical').length, const Color(0xFFFFE9E7), const Color(0xFF9A2D25)),
            _summaryTile('توقف العمل', _drafts.where((d) => d['blocking'] == true).length, const Color(0xFFFFF2D8), const Color(0xFF805500)),
          ],
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _exportDrafts,
          icon: const Icon(Icons.content_copy_outlined),
          label: const Text('نسخ نسخة احتياطية JSON'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: _importDraftsFromClipboard, icon: const Icon(Icons.file_download_outlined), label: const Text('استيراد نسخة JSON من الحافظة')),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _categoryFilter,
          decoration: const InputDecoration(labelText: 'تصفية حسب التصنيف'),
          items: const [
            DropdownMenuItem(value: 'الكل', child: Text('كل التصنيفات')),
            DropdownMenuItem(value: 'أجهزة الرصد', child: Text('أجهزة الرصد')),
            DropdownMenuItem(value: 'الاتصالات', child: Text('الاتصالات')),
            DropdownMenuItem(value: 'الحاسب والشبكة', child: Text('الحاسب والشبكة')),
            DropdownMenuItem(value: 'الكهرباء والطاقة', child: Text('الكهرباء والطاقة')),
            DropdownMenuItem(value: 'أخرى', child: Text('أخرى')),
          ],
          onChanged: (value) => setState(() => _categoryFilter = value ?? 'الكل'),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _severityFilter,
          decoration: const InputDecoration(labelText: 'تصفية حسب شدة العطل'),
          items: const [
            DropdownMenuItem(value: 'الكل', child: Text('كل الشدات')),
            DropdownMenuItem(value: 'Low', child: Text('منخفض')),
            DropdownMenuItem(value: 'Medium', child: Text('متوسط')),
            DropdownMenuItem(value: 'High', child: Text('عالٍ')),
            DropdownMenuItem(value: 'Critical', child: Text('حرج')),
          ],
          onChanged: (value) => setState(() => _severityFilter = value ?? 'الكل'),
        ),
        const SizedBox(height: 4),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('عرض الأعطال التي توقف العمل فقط'),
          value: _blockingOnly,
          onChanged: (value) => setState(() => _blockingOnly = value),
        ),
        TextField(
          controller: _search,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            labelText: 'بحث في البلاغات المحفوظة',
            suffixIcon: IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _search.clear())),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        if (_drafts.isEmpty)
          const Card(child: ListTile(leading: Icon(Icons.inbox_outlined), title: Text('لا توجد بلاغات محلية محفوظة'))),
        ..._drafts.where((draft) {
          final q = _search.text.trim().toLowerCase();
          final matchesSearch = q.isEmpty || ['equipment', 'category', 'severity', 'description'].any((key) => (draft[key] ?? '').toString().toLowerCase().contains(q));
          final matchesSeverity = _severityFilter == 'الكل' || draft['severity'] == _severityFilter;
          final matchesCategory = _categoryFilter == 'الكل' || draft['category'] == _categoryFilter;
          final matchesBlocking = !_blockingOnly || draft['blocking'] == true;
          return matchesSearch && matchesSeverity && matchesCategory && matchesBlocking;
        }).map((draft) => Card(
          elevation: 0,
          child: ListTile(
            onTap: () {
              setState(() {
                _editingId = draft['id'].toString();
                _category = draft['category'] as String? ?? 'أجهزة الرصد';
                _severity = draft['severity'] as String? ?? 'High';
                _blocking = draft['blocking'] == true;
                _equipment.text = draft['equipment'] as String? ?? '';
                _description.text = draft['description'] as String? ?? '';
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم تحميل المسودة للتعديل؛ اضغط تحديث المسودة.')),
              );
            },
            leading: Icon(draft['blocking'] == true ? Icons.warning_amber_rounded : Icons.build_outlined),
            title: Text('${draft['equipment'] ?? 'جهاز غير محدد'}'),
            subtitle: Text('${draft['category']} • ${draft['severity']}\\n${draft['description']}',
              maxLines: 3, overflow: TextOverflow.ellipsis),
            isThreeLine: true,
            trailing: IconButton(
              tooltip: 'حذف المسودة',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _deleteDraft(draft['id'].toString()),
            ),
          ),
        )),
        const Padding(
          padding: EdgeInsets.only(top: 10),
          child: Text('هذه المسودات محفوظة على الجهاز فقط. لم يتم إرسالها إلى Supabase أو أي خادم.',
            style: TextStyle(color: Colors.black54)),
        ),
      ],
    ),
  );
}
