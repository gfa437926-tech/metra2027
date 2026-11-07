import 'package:flutter/material.dart';
import '../../core/api/metra_api_client.dart';

/// Station-scoped IT/telecom support incident intake backed by the METRA API.
class SupportIncidentScreen extends StatefulWidget {
  const SupportIncidentScreen({
    super.key,
    required this.api,
    required this.stationId,
  });

  final MetraApiClient api;
  final String stationId;

  @override
  State<SupportIncidentScreen> createState() => _SupportIncidentScreenState();
}

class _SupportIncidentScreenState extends State<SupportIncidentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _category = TextEditingController();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _affectedAsset = TextEditingController();
  String _kind = 'InformationTechnology';
  String _severity = 'High';
  bool _impactsOperations = false;
  bool _submitting = false;
  late Future<List<Map<String, dynamic>>> _queue;

  @override
  void initState() {
    super.initState();
    _queue = widget.api.listSupportIncidents(widget.stationId);
  }

  @override
  void dispose() {
    _category.dispose();
    _title.dispose();
    _description.dispose();
    _affectedAsset.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _queue = widget.api.listSupportIncidents(widget.stationId));
    await _queue;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _submitting) return;
    setState(() => _submitting = true);
    try {
      await widget.api.submitSupportIncident(
        stationId: widget.stationId,
        kind: _kind,
        category: _category.text.trim(),
        title: _title.text.trim(),
        description: _description.text.trim(),
        severity: _severity,
        occurredAt: DateTime.now().toUtc(),
        affectedAsset: _affectedAsset.text.trim().isEmpty
            ? null
            : _affectedAsset.text.trim(),
        impactsOperations: _impactsOperations,
      );
      if (!mounted) return;
      _category.clear();
      _title.clear();
      _description.clear();
      _affectedAsset.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال بلاغ الدعم إلى الخادم')),
      );
      await _refresh();
    } on MetraApiException catch (error) {
      if (!mounted) return;
      final message = switch (error.statusCode) {
        400 => 'بيانات البلاغ غير صالحة.',
        401 => 'يلزم تسجيل الدخول أولاً.',
        403 => 'ليست لديك صلاحية تسجيل بلاغات الدعم لهذه المحطة.',
        503 => 'خدمة الدعم غير متاحة حالياً (جداول القاعدة قد تكون غير مفعّلة).',
        _ => 'تعذر إرسال البلاغ.',
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('بلاغات الدعم'),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'نوع البلاغ',
                        border: OutlineInputBorder(),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _kind,
                          items: const [
                            DropdownMenuItem(
                              value: 'InformationTechnology',
                              child: Text('تقنية معلومات'),
                            ),
                            DropdownMenuItem(
                              value: 'Telecommunications',
                              child: Text('اتصالات'),
                            ),
                          ],
                          onChanged: _submitting
                              ? null
                              : (v) {
                                  if (v != null) setState(() => _kind = v);
                                },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _category,
                      decoration: const InputDecoration(
                        labelText: 'التصنيف',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        final t = v?.trim() ?? '';
                        if (t.length < 2 || t.length > 80) {
                          return 'التصنيف من 2 إلى 80 محرفاً';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _title,
                      decoration: const InputDecoration(
                        labelText: 'العنوان',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        final t = v?.trim() ?? '';
                        if (t.length < 5 || t.length > 160) {
                          return 'العنوان من 5 إلى 160 محرفاً';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _description,
                      maxLines: 4,
                      maxLength: 5000,
                      decoration: const InputDecoration(
                        labelText: 'الوصف',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        final t = v?.trim() ?? '';
                        if (t.length < 10) return 'الوصف 10 محارف على الأقل';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _affectedAsset,
                      decoration: const InputDecoration(
                        labelText: 'الجهاز/الخدمة المتأثرة (اختياري)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'الأولوية',
                        border: OutlineInputBorder(),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _severity,
                          items: const [
                            DropdownMenuItem(value: 'Low', child: Text('Low')),
                            DropdownMenuItem(value: 'Normal', child: Text('Normal')),
                            DropdownMenuItem(value: 'High', child: Text('High')),
                            DropdownMenuItem(
                              value: 'Critical',
                              child: Text('Critical'),
                            ),
                          ],
                          onChanged: _submitting
                              ? null
                              : (v) {
                                  if (v != null) setState(() => _severity = v);
                                },
                        ),
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('يؤثر على سير العمل'),
                      value: _impactsOperations,
                      onChanged: _submitting
                          ? null
                          : (v) => setState(() => _impactsOperations = v),
                    ),
                    FilledButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: const Icon(Icons.send),
                      label: Text(
                        _submitting ? 'جارٍ الإرسال...' : 'إرسال إلى الخادم',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _queue,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Card(
                  child: ListTile(
                    title: const Text('تعذر تحميل بلاغات الدعم من الخادم'),
                    trailing: TextButton(
                      onPressed: _refresh,
                      child: const Text('إعادة'),
                    ),
                  ),
                );
              }
              final rows = snapshot.data ?? const <Map<String, dynamic>>[];
              if (rows.isEmpty) {
                return const Card(
                  child: ListTile(title: Text('لا توجد بلاغات دعم مسجّلة')),
                );
              }
              return Column(
                children: [
                  for (final row in rows)
                    Card(
                      child: ListTile(
                        title: Text(
                          '${row['title'] ?? '—'} • ${row['status'] ?? ''}',
                        ),
                        subtitle: Text(
                          '${row['kind'] ?? ''} • ${row['severity'] ?? ''}\n${row['description'] ?? ''}',
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                        isThreeLine: true,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
