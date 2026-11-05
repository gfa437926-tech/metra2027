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
  String _sortOrder = 'الأحدث';
  String _workflowStatus = 'new';
  String _statusFilter = 'الكل';
  bool _blockingOnly = false;
  bool _blocking = false;
  bool _saving = false;
  String? _editingId;
  List<Map<String, dynamic>> _drafts = [];
  final Set<String> _selectedDraftIds = <String>{};

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
        draft['workflowStatus'] = draft['workflowStatus'] ?? 'new';
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
      'updatedAt': DateTime.now().toIso8601String(),
      'resolvedAt': _workflowStatus == 'resolved' ? DateTime.now().toIso8601String() : null,
      'statusHistory': _drafts.where((d) => d['id'] == _editingId).map((d) => List<Map<String, dynamic>>.from((d['statusHistory'] as List? ?? const []).whereType<Map>().map((entry) => Map<String, dynamic>.from(entry)))).firstOrNull ?? [
        {'status': _workflowStatus, 'at': DateTime.now().toIso8601String(), 'note': 'إنشاء البلاغ'}
      ],
      'status': 'local_draft',
      'workflowStatus': _workflowStatus,
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

  Future<void> _updateSelectedWorkflowStatus(String status) async {
    final ids = Set<String>.from(_selectedDraftIds);
    if (ids.isEmpty) return;
    final now = DateTime.now().toIso8601String();
    final next = _drafts.map((draft) {
      if (!ids.contains(draft['id'].toString())) return draft;
      final current = (draft['workflowStatus'] ?? 'new').toString();
      if (current == status) return draft;
      final history = List<Map<String, dynamic>>.from(
        (draft['statusHistory'] as List? ?? const [])
            .whereType<Map>()
            .map((entry) => Map<String, dynamic>.from(entry)),
      );
      history.add({
        'status': status,
        'at': now,
        'note': 'تحديث جماعي لحالة البلاغ',
      });
      return <String, dynamic>{
        ...draft,
        'workflowStatus': status,
        'statusHistory': history,
        'updatedAt': now,
        'resolvedAt': status == 'resolved' ? now : null,
      };
    }).toList();
    try {
      await _storage.write(key: _draftKey, value: jsonEncode(next));
      if (!mounted) return;
      setState(() {
        _drafts = next;
        _selectedDraftIds.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم تحديث حالة البلاغات المحددة إلى «${_workflowStatusArabic(status)}».')),
      );
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تحديث حالات البلاغات المحددة.')),
      );
    }
  }

  void _selectAllFilteredDrafts() {
    final visibleIds = _filteredDrafts().map((draft) => draft['id'].toString()).toSet();
    setState(() {
      if (visibleIds.isNotEmpty && _selectedDraftIds.containsAll(visibleIds)) {
        _selectedDraftIds.removeAll(visibleIds);
      } else {
        _selectedDraftIds.addAll(visibleIds);
      }
    });
  }

  Future<void> _deleteSelectedDrafts() async {
    final ids = Set<String>.from(_selectedDraftIds);
    if (ids.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف البلاغات المحددة'),
        content: Text('سيتم حذف ${ids.length} مسودة محلية نهائياً. هل تريد المتابعة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton.tonal(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('حذف المحدد')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final next = _drafts.where((draft) => !ids.contains(draft['id'].toString())).toList();
    try {
      await _storage.write(key: _draftKey, value: jsonEncode(next));
      if (!mounted) return;
      setState(() {
        _drafts = next;
        _selectedDraftIds.clear();
        if (_editingId != null && ids.contains(_editingId)) _resetFields();
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم حذف ${ids.length} مسودة.')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر حذف البلاغات المحددة.')));
    }
  }

  Future<void> _showStatusHistory(Map<String, dynamic> draft) async {
    final history = (draft['statusHistory'] as List? ?? const [])
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList()
      ..sort((a, b) => (b['at'] ?? '').toString().compareTo((a['at'] ?? '').toString()));
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('سجل معالجة: ${draft['equipment'] ?? 'البلاغ'}'),
        content: SizedBox(
          width: 420,
          child: history.isEmpty
              ? const Text('لا توجد تغييرات مسجلة لهذا البلاغ بعد.')
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: history.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final entry = history[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.history),
                      title: Text(_workflowStatusArabic(entry['status'])),
                      subtitle: Text('${entry['note'] ?? 'تحديث الحالة'}\\n${entry['at'] ?? ''}'),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إغلاق')),
        ],
      ),
    );
  }

  Future<void> _setWorkflowStatus(String id, String status) async {
    final now = DateTime.now().toIso8601String();
    final next = _drafts.map((draft) {
      if (draft['id'].toString() != id) return draft;
      final history = List<Map<String, dynamic>>.from(
        (draft['statusHistory'] as List? ?? const [])
            .whereType<Map>()
            .map((entry) => Map<String, dynamic>.from(entry)),
      );
      if ((draft['workflowStatus'] ?? 'new') != status) {
        history.add({
          'status': status,
          'at': now,
          'note': status == 'resolved' ? 'تم إغلاق البلاغ بعد الإصلاح' : 'تحديث حالة المعالجة',
        });
      }
      return <String, dynamic>{
        ...draft,
        'workflowStatus': status,
        'statusHistory': history,
        'updatedAt': now,
        if (status == 'resolved') 'resolvedAt': now,
        if (status != 'resolved') 'resolvedAt': null,
      };
    }).toList();
    try {
      await _storage.write(key: _draftKey, value: jsonEncode(next));
      if (!mounted) return;
      setState(() => _drafts = next);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم تحديث حالة البلاغ إلى: ${_workflowStatusArabic(status)}')),
      );
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تحديث حالة البلاغ.')),
      );
    }
  }

  Future<void> _duplicateDraft(Map<String, dynamic> source) async {
    final copy = Map<String, dynamic>.from(source);
    copy['id'] = DateTime.now().microsecondsSinceEpoch.toString();
    copy['createdAt'] = DateTime.now().toIso8601String();
    copy['status'] = 'local_draft';
    final next = [copy, ..._drafts];
    try {
      await _storage.write(key: _draftKey, value: jsonEncode(next));
      if (!mounted) return;
      setState(() => _drafts = next);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إنشاء نسخة جديدة من البلاغ؛ عدّلها قبل الحفظ النهائي.')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر إنشاء نسخة من البلاغ.')));
    }
  }

  Future<void> _deleteDraft(String id) async {
    final next = _drafts.where((draft) => draft['id'] != id).toList();
    try {
      await _storage.write(key: _draftKey, value: jsonEncode(next));
      if (mounted) setState(() { _drafts = next; _selectedDraftIds.remove(id); if (_editingId == id) _resetFields(); });
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
      _workflowStatus = 'new';
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

  String _workflowStatusArabic(dynamic status) {
    switch (status) {
      case 'in_progress': return 'قيد المعالجة';
      case 'resolved': return 'تم الإصلاح';
      default: return 'جديد';
    }
  }

  String _severityArabic(dynamic severity) {
    switch (severity) {
      case 'Low': return 'منخفض';
      case 'Medium': return 'متوسط';
      case 'High': return 'عالٍ';
      case 'Critical': return 'حرج';
      default: return severity?.toString() ?? 'غير محدد';
    }
  }

  List<Map<String, dynamic>> _filteredDrafts() {
    final q = _search.text.trim().toLowerCase();
    final result = _drafts.where((draft) {
      final matchesSearch = q.isEmpty || ['equipment', 'category', 'severity', 'description']
          .any((key) => (draft[key] ?? '').toString().toLowerCase().contains(q));
      final matchesSeverity = _severityFilter == 'الكل' || draft['severity'] == _severityFilter;
      final matchesCategory = _categoryFilter == 'الكل' || draft['category'] == _categoryFilter;
      final matchesBlocking = !_blockingOnly || draft['blocking'] == true;
      final matchesStatus = _statusFilter == 'الكل' || (draft['workflowStatus'] ?? 'new') == _statusFilter;
      return matchesSearch && matchesSeverity && matchesCategory && matchesBlocking && matchesStatus;
    }).toList();
    int rank(dynamic severity) => const {'Critical': 4, 'High': 3, 'Medium': 2, 'Low': 1}[severity] ?? 0;
    result.sort((a, b) {
      switch (_sortOrder) {
        case 'الأقدم':
          return (a['createdAt'] ?? '').toString().compareTo((b['createdAt'] ?? '').toString());
        case 'الأشد':
          final bySeverity = rank(b['severity']).compareTo(rank(a['severity']));
          return bySeverity != 0 ? bySeverity : (b['createdAt'] ?? '').toString().compareTo((a['createdAt'] ?? '').toString());
        default:
          return (b['createdAt'] ?? '').toString().compareTo((a['createdAt'] ?? '').toString());
      }
    });
    return result;
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
                DropdownButtonFormField<String>(
                  value: _workflowStatus,
                  decoration: const InputDecoration(labelText: 'حالة معالجة البلاغ'),
                  items: const [
                    DropdownMenuItem(value: 'new', child: Text('جديد')),
                    DropdownMenuItem(value: 'in_progress', child: Text('قيد المعالجة')),
                    DropdownMenuItem(value: 'resolved', child: Text('تم الإصلاح')),
                  ],
                  onChanged: (value) => setState(() => _workflowStatus = value ?? _workflowStatus),
                ),
                const SizedBox(height: 12),
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
            _summaryTile('جديدة', _drafts.where((d) => (d['workflowStatus'] ?? 'new') == 'new').length, const Color(0xFFEAF1FF), const Color(0xFF173B78)),
            _summaryTile('قيد المعالجة', _drafts.where((d) => d['workflowStatus'] == 'in_progress').length, const Color(0xFFFFF2D8), const Color(0xFF805500)),
            _summaryTile('تم إصلاحها', _drafts.where((d) => d['workflowStatus'] == 'resolved').length, const Color(0xFFE5F5EC), const Color(0xFF17643A)),
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
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _statusFilter,
          decoration: const InputDecoration(labelText: 'تصفية حسب حالة المعالجة'),
          items: const [
            DropdownMenuItem(value: 'الكل', child: Text('كل الحالات')),
            DropdownMenuItem(value: 'new', child: Text('جديد')),
            DropdownMenuItem(value: 'in_progress', child: Text('قيد المعالجة')),
            DropdownMenuItem(value: 'resolved', child: Text('تم الإصلاح')),
          ],
          onChanged: (value) => setState(() => _statusFilter = value ?? 'الكل'),
        ),
        const SizedBox(height: 4),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('عرض الأعطال التي توقف العمل فقط'),
          value: _blockingOnly,
          onChanged: (value) => setState(() => _blockingOnly = value),
        ),
        DropdownButtonFormField<String>(
          value: _sortOrder,
          decoration: const InputDecoration(labelText: 'ترتيب البلاغات'),
          items: const [
            DropdownMenuItem(value: 'الأحدث', child: Text('الأحدث أولاً')),
            DropdownMenuItem(value: 'الأقدم', child: Text('الأقدم أولاً')),
            DropdownMenuItem(value: 'الأشد', child: Text('الأعطال الأشد أولاً')),
          ],
          onChanged: (value) => setState(() => _sortOrder = value ?? 'الأحدث'),
        ),
        const SizedBox(height: 8),
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
        if (_drafts.isNotEmpty) ...[
          Card(
            elevation: 0,
            color: const Color(0xFFEAF1FF),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  Text('المحدد: ${_selectedDraftIds.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextButton.icon(
                    onPressed: _selectAllFilteredDrafts,
                    icon: const Icon(Icons.select_all),
                    label: const Text('تحديد نتائج التصفية'),
                  ),
                  PopupMenuButton<String>(
                    enabled: _selectedDraftIds.isNotEmpty,
                    tooltip: 'تغيير حالة المحدد',
                    onSelected: _updateSelectedWorkflowStatus,
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'new', child: Text('تعيين: جديد')),
                      PopupMenuItem(value: 'in_progress', child: Text('تعيين: قيد المعالجة')),
                      PopupMenuItem(value: 'resolved', child: Text('تعيين: تم الإصلاح')),
                    ],
                    child: const Chip(avatar: Icon(Icons.sync_alt), label: Text('تغيير الحالة')),
                  ),
                  OutlinedButton.icon(
                    onPressed: _selectedDraftIds.isEmpty ? null : _deleteSelectedDrafts,
                    icon: const Icon(Icons.delete_sweep_outlined),
                    label: const Text('حذف المحدد'),
                  ),
                ],
              ),
            ),
          ),
        ],
        ..._filteredDrafts().map((draft) => Card(
          elevation: 0,
          child: ListTile(
            onTap: () {
              setState(() {
                _editingId = draft['id'].toString();
                _category = draft['category'] as String? ?? 'أجهزة الرصد';
                _severity = draft['severity'] as String? ?? 'High';
                _blocking = draft['blocking'] == true;
                _workflowStatus = draft['workflowStatus'] as String? ?? 'new';
                _equipment.text = draft['equipment'] as String? ?? '';
                _description.text = draft['description'] as String? ?? '';
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم تحميل المسودة للتعديل؛ اضغط تحديث المسودة.')),
              );
            },
            leading: Checkbox(
              value: _selectedDraftIds.contains(draft['id'].toString()),
              onChanged: (checked) => setState(() {
                final id = draft['id'].toString();
                if (checked == true) { _selectedDraftIds.add(id); } else { _selectedDraftIds.remove(id); }
              }),
            ),
            title: Text('${draft['equipment'] ?? 'جهاز غير محدد'}'),
            subtitle: Text('${draft['category']} • ${_severityArabic(draft['severity'])} • ${_workflowStatusArabic(draft['workflowStatus'])} • ${draft['blocking'] == true ? 'يوقف العمل' : 'لا يوقف العمل'}\\nآخر تحديث: ${draft['updatedAt'] ?? draft['createdAt'] ?? 'غير محدد'} • سجل الحالات: ${(draft['statusHistory'] as List? ?? const []).length}\\n${draft['description']}',
              maxLines: 4, overflow: TextOverflow.ellipsis),
            isThreeLine: true,
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                tooltip: 'نسخ البلاغ',
                icon: const Icon(Icons.copy_outlined),
                onPressed: () => _duplicateDraft(draft),
              ),
              PopupMenuButton<String>(
                tooltip: 'تغيير حالة المعالجة',
                icon: const Icon(Icons.more_vert),
                onSelected: (status) {
                  if (status == 'history') {
                    _showStatusHistory(draft);
                  } else {
                    _setWorkflowStatus(draft['id'].toString(), status);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'history', child: Text('عرض سجل المعالجة')),
                  PopupMenuDivider(),
                  PopupMenuItem(value: 'new', child: Text('إعادة إلى: جديد')),
                  PopupMenuItem(value: 'in_progress', child: Text('نقل إلى: قيد المعالجة')),
                  PopupMenuItem(value: 'resolved', child: Text('إغلاق: تم الإصلاح')),
                ],
              ),
              IconButton(
                tooltip: 'حذف المسودة',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _deleteDraft(draft['id'].toString()),
              ),
            ]),
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
