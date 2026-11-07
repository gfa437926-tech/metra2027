import 'package:flutter/material.dart';
import '../../core/api/metra_api_client.dart';

/// Station-scoped equipment fault intake and queue backed by the METRA API.
class EquipmentFaultScreen extends StatefulWidget {
  const EquipmentFaultScreen({
    super.key,
    required this.api,
    required this.stationId,
  });

  final MetraApiClient api;
  final String stationId;

  @override
  State<EquipmentFaultScreen> createState() => _EquipmentFaultScreenState();
}

class _EquipmentFaultScreenState extends State<EquipmentFaultScreen> {
  final _formKey = GlobalKey<FormState>();
  final _equipmentName = TextEditingController();
  final _description = TextEditingController();
  String _category = 'أجهزة الرصد';
  String _severity = 'High';
  bool _blocking = false;
  bool _submitting = false;
  late Future<List<Map<String, dynamic>>> _queue;

  static const _categories = <String>[
    'أجهزة الرصد',
    'أجهزة الاتصالات',
    'أجهزة القياس',
    'أخرى',
  ];
  static const _severities = <String>['Low', 'Medium', 'High', 'Critical'];

  @override
  void initState() {
    super.initState();
    _queue = widget.api.listEquipmentFaults(widget.stationId);
  }

  @override
  void dispose() {
    _equipmentName.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _queue = widget.api.listEquipmentFaults(widget.stationId));
    await _queue;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _submitting) return;
    setState(() => _submitting = true);
    try {
      await widget.api.submitEquipmentFault(
        stationId: widget.stationId,
        equipmentCategory: _category,
        equipmentName: _equipmentName.text.trim(),
        description: _description.text.trim(),
        severity: _severity,
        occurredAt: DateTime.now().toUtc(),
        isOperationallyBlocking: _blocking,
      );
      if (!mounted) return;
      _equipmentName.clear();
      _description.clear();
      setState(() {
        _blocking = false;
        _severity = 'High';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال بلاغ العطل إلى الخادم')),
      );
      await _refresh();
    } on MetraApiException catch (error) {
      if (!mounted) return;
      final message = switch (error.statusCode) {
        400 => 'بيانات البلاغ غير صالحة. راجع الحقول وأعد المحاولة.',
        401 => 'يلزم تسجيل الدخول أولاً.',
        403 => 'ليست لديك صلاحية تسجيل أعطال هذه المحطة.',
        503 =>
          'خدمة الأعطال غير متاحة حالياً (قد تكون جداول القاعدة غير مفعّلة بعد).',
        _ => 'تعذر إرسال البلاغ. حاول مجدداً.',
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
        title: const Text('أعطال المعدات'),
        actions: [
          IconButton(
            tooltip: 'تحديث القائمة',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
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
                    const Text(
                      'بلاغ عطل جديد',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: ValueKey(_category),
                      initialValue: _category,
                      decoration: const InputDecoration(
                        labelText: 'تصنيف المعدة',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final c in _categories)
                          DropdownMenuItem(value: c, child: Text(c)),
                      ],
                      onChanged: _submitting
                          ? null
                          : (value) {
                              if (value != null) setState(() => _category = value);
                            },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _equipmentName,
                      enabled: !_submitting,
                      decoration: const InputDecoration(
                        labelText: 'اسم المعدة',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.length < 2 || text.length > 120) {
                          return 'اسم المعدة من 2 إلى 120 محرفاً';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _description,
                      enabled: !_submitting,
                      maxLines: 4,
                      maxLength: 5000,
                      decoration: const InputDecoration(
                        labelText: 'وصف العطل',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.length < 10 || text.length > 5000) {
                          return 'الوصف من 10 إلى 5000 محرف';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      key: ValueKey(_severity),
                      initialValue: _severity,
                      decoration: const InputDecoration(
                        labelText: 'درجة الشدة',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final s in _severities)
                          DropdownMenuItem(value: s, child: Text(s)),
                      ],
                      onChanged: _submitting
                          ? null
                          : (value) {
                              if (value != null) setState(() => _severity = value);
                            },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('يعطل التشغيل التشغيلي للمحطة'),
                      value: _blocking,
                      onChanged: _submitting
                          ? null
                          : (value) => setState(() => _blocking = value),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: _submitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                      label: Text(_submitting ? 'جارٍ الإرسال...' : 'إرسال إلى الخادم'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'بلاغات المحطة من الخادم',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _queue,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                final error = snapshot.error;
                final message = error is MetraApiException
                    ? switch (error.statusCode) {
                        401 => 'يلزم تسجيل الدخول أولاً',
                        403 => 'ليست لديك صلاحية قراءة أعطال هذه المحطة',
                        503 =>
                          'قائمة الأعطال غير متاحة (جداول القاعدة قد تكون غير مفعّلة)',
                        _ => 'تعذر تحميل قائمة الأعطال',
                      }
                    : 'تعذر تحميل قائمة الأعطال';
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.cloud_off_outlined),
                    title: Text(message),
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
                  child: ListTile(
                    title: Text('لا توجد بلاغات أعطال مسجّلة لهذه المحطة'),
                  ),
                );
              }
              return Column(
                children: [
                  for (final row in rows)
                    Card(
                      child: ListTile(
                        title: Text(
                          '${row['equipment_name'] ?? '—'} • ${row['severity'] ?? ''}',
                        ),
                        subtitle: Text(
                          [
                            row['equipment_category']?.toString() ?? '',
                            row['status']?.toString() ?? '',
                            row['description']?.toString() ?? '',
                          ].where((x) => x.isNotEmpty).join('\n'),
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
