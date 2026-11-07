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
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _equipmentName = TextEditingController();
  final TextEditingController _description = TextEditingController();
  String _category = 'أجهزة الرصد';
  String _severity = 'High';
  bool _blocking = false;
  bool _submitting = false;
  late Future<List<Map<String, dynamic>>> _queue;

  static const List<String> _categories = <String>[
    'أجهزة الرصد',
    'أجهزة الاتصالات',
    'أجهزة القياس',
    'أخرى',
  ];
  static const List<String> _severities = <String>[
    'Low',
    'Medium',
    'High',
    'Critical',
  ];

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
    setState(() {
      _queue = widget.api.listEquipmentFaults(widget.stationId);
    });
    await _queue;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _submitting) {
      return;
    }
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
      if (!mounted) {
        return;
      }
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
      if (!mounted) {
        return;
      }
      final String message = switch (error.statusCode) {
        400 => 'بيانات البلاغ غير صالحة. راجع الحقول وأعد المحاولة.',
        401 => 'يلزم تسجيل الدخول أولاً.',
        403 => 'ليست لديك صلاحية تسجيل أعطال هذه المحطة.',
        503 =>
          'خدمة الأعطال غير متاحة حالياً (قد تكون جداول القاعدة غير مفعّلة بعد).',
        _ => 'تعذر إرسال البلاغ. حاول مجدداً.',
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Widget _choiceRow({
    required String label,
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final String option in options)
              ChoiceChip(
                label: Text(option),
                selected: selected == option,
                onSelected: _submitting
                    ? null
                    : (bool isSelected) {
                        if (isSelected) {
                          onSelected(option);
                        }
                      },
              ),
          ],
        ),
      ],
    );
  }


  List<Map<String, String>> _nextActions(String status) {
    switch (status) {
      case 'Submitted':
        return [
          {'status': 'UnderReview', 'label': 'بدء المراجعة'},
          {'status': 'Rejected', 'label': 'رفض'},
        ];
      case 'UnderReview':
        return [
          {'status': 'Assigned', 'label': 'إسناد'},
          {'status': 'Rejected', 'label': 'رفض'},
        ];
      case 'Assigned':
        return [
          {'status': 'InProgress', 'label': 'بدء الإصلاح'},
        ];
      case 'InProgress':
        return [
          {'status': 'Resolved', 'label': 'تسجيل الحل'},
        ];
      case 'Resolved':
        return [
          {'status': 'Closed', 'label': 'إغلاق'},
        ];
      default:
        return const <Map<String, String>>[];
    }
  }

  Future<void> _transition(Map<String, dynamic> row, String toStatus) async {
    String? note;
    int? progress;
    if (toStatus == 'Rejected' || toStatus == 'Closed' || toStatus == 'Resolved') {
      final TextEditingController controller = TextEditingController();
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: Text(toStatus),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'ملاحظة',
              border: OutlineInputBorder(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('تأكيد'),
            ),
          ],
        ),
      );
      final String entered = controller.text.trim();
      controller.dispose();
      if (!mounted) {
        return;
      }
      if (confirmed != true) {
        return;
      }
      if ((toStatus == 'Rejected' || toStatus == 'Closed') && entered.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الملاحظة مطلوبة')),
        );
        return;
      }
      note = entered.isEmpty ? null : entered;
      if (toStatus == 'Resolved') {
        progress = 100;
      }
    }
    try {
      await widget.api.transitionEquipmentFault(
        stationId: widget.stationId,
        faultId: row['id'].toString(),
        toStatus: toStatus,
        note: note,
        progressPercent: progress,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث حالة البلاغ')),
      );
      await _refresh();
    } on MetraApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر التحديث (${error.statusCode})')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('أعطال المعدات'),
        actions: <Widget>[
          IconButton(
            tooltip: 'تحديث القائمة',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Text(
                      'بلاغ عطل جديد',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _choiceRow(
                      label: 'تصنيف المعدة',
                      options: _categories,
                      selected: _category,
                      onSelected: (String value) {
                        setState(() => _category = value);
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
                      validator: (String? value) {
                        final String text = value?.trim() ?? '';
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
                      validator: (String? value) {
                        final String text = value?.trim() ?? '';
                        if (text.length < 10 || text.length > 5000) {
                          return 'الوصف من 10 إلى 5000 محرف';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    _choiceRow(
                      label: 'درجة الشدة',
                      options: _severities,
                      selected: _severity,
                      onSelected: (String value) {
                        setState(() => _severity = value);
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('يعطل التشغيل التشغيلي للمحطة'),
                      value: _blocking,
                      onChanged: _submitting
                          ? null
                          : (bool value) {
                              setState(() => _blocking = value);
                            },
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
          const Text(
            'بلاغات المحطة من الخادم',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _queue,
            builder: (
              BuildContext context,
              AsyncSnapshot<List<Map<String, dynamic>>> snapshot,
            ) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                final Object? error = snapshot.error;
                final String message = error is MetraApiException
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
              final List<Map<String, dynamic>> rows =
                  snapshot.data ?? const <Map<String, dynamic>>[];
              if (rows.isEmpty) {
                return const Card(
                  child: ListTile(
                    title: Text('لا توجد بلاغات أعطال مسجّلة لهذه المحطة'),
                  ),
                );
              }
              return Column(
                children: <Widget>[
                  for (final Map<String, dynamic> row in rows)
                    Card(
                      child: Column(
                        children: <Widget>[
                          ListTile(
                            title: Text(
                              '${row['equipment_name'] ?? '—'} • ${row['severity'] ?? ''}',
                            ),
                            subtitle: Text(
                              <String>[
                                row['equipment_category']?.toString() ?? '',
                                row['status']?.toString() ?? '',
                                row['description']?.toString() ?? '',
                              ].where((String x) => x.isNotEmpty).join('\n'),
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                            ),
                            isThreeLine: true,
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            child: Wrap(
                              spacing: 8,
                              children: <Widget>[
                                for (final Map<String, String> action
                                    in _nextActions(
                                  row['status']?.toString() ?? '',
                                ))
                                  OutlinedButton(
                                    onPressed: () => _transition(
                                      row,
                                      action['status']!,
                                    ),
                                    child: Text(action['label']!),
                                  ),
                              ],
                            ),
                          ),
                        ],
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
