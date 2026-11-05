import 'dart:convert';
import 'package:flutter/material.dart';
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
  String _category = 'أجهزة الرصد';
  String _severity = 'High';
  bool _blocking = false;
  bool _saving = false;
  String? _editingId;
  List<Map<String, dynamic>> _drafts = [];

  @override
  void initState() {
    super.initState();
    _loadDrafts();
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
      if (mounted) setState(() => _drafts = next);
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
    super.dispose();
  }

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
          const Expanded(child: Text('المسودات المحفوظة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          Text('${_drafts.length}'),
        ]),
        const SizedBox(height: 8),
        if (_drafts.isEmpty)
          const Card(child: ListTile(leading: Icon(Icons.inbox_outlined), title: Text('لا توجد بلاغات محلية محفوظة'))),
        ..._drafts.map((draft) => Card(
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
