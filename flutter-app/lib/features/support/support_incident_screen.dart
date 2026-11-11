import 'package:flutter/material.dart';
import '../../core/api/metra_api_client.dart';
import '../ops/ops_api_messages.dart';

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
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _category = TextEditingController();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _affectedAsset = TextEditingController();
  String _kind = 'InformationTechnology';
  String _severity = 'High';
  bool _impactsOperations = false;
  bool _submitting = false;
  late Future<List<Map<String, dynamic>>> _queue;

  static const List<String> _kinds = <String>[
    'InformationTechnology',
    'Telecommunications',
  ];
  static const List<String> _severities = <String>[
    'Low',
    'Normal',
    'High',
    'Critical',
  ];

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
    setState(() {
      _queue = widget.api.listSupportIncidents(widget.stationId);
    });
    await _queue;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _submitting) {
      return;
    }
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
      if (!mounted) {
        return;
      }
      _category.clear();
      _title.clear();
      _description.clear();
      _affectedAsset.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال بلاغ الدعم إلى الخادم')),
      );
      await _refresh();
    } on MetraApiException catch (error) {
      if (!mounted) {
        return;
      }
      final String message = opsSubmitErrorMessage(error.statusCode, resourceAr: 'بلاغ الدعم');
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
    String Function(String value)? labelFor,
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
                label: Text(labelFor == null ? option : labelFor(option)),
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
          {'status': 'InProgress', 'label': 'بدء المعالجة'},
        ];
      case 'InProgress':
        return [
          {'status': 'WaitingForInformation', 'label': 'بانتظار معلومات'},
          {'status': 'Resolved', 'label': 'حل'},
        ];
      case 'WaitingForInformation':
        return [
          {'status': 'InProgress', 'label': 'استئناف'},
          {'status': 'Resolved', 'label': 'حل'},
        ];
      case 'Resolved':
        return [
          {'status': 'Closed', 'label': 'إغلاق'},
        ];
      default:
        return const <Map<String, String>>[];
    }
  }


  Future<void> _openDetail(Map<String, dynamic> row) async {
    final String id = row['id']?.toString() ?? '';
    if (id.isEmpty) {
      return;
    }
    try {
      final Map<String, dynamic> detail = await widget.api.getSupportIncidentById(
        stationId: widget.stationId,
        incidentId: id,
      );
      if (!mounted) {
        return;
      }
      final String stationId = detail['station_id']?.toString() ?? '';
      if (stationId.isNotEmpty && stationId != widget.stationId) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('رُفض عرض بلاغ لا ينتمي إلى محطتك')),
        );
        return;
      }
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (BuildContext sheetContext) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    detail['title']?.toString() ?? 'تفاصيل البلاغ',
                    style: Theme.of(sheetContext).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text('الحالة: ${detail['status'] ?? '—'}'),
                  Text('الأولوية: ${detail['severity'] ?? '—'}'),
                  Text('النوع: ${detail['kind'] ?? '—'}'),
                  Text('التصنيف: ${detail['category'] ?? '—'}'),
                  const SizedBox(height: 8),
                  Text(detail['description']?.toString() ?? ''),
                  const SizedBox(height: 8),
                  Text('المحطة: ${detail['station_id'] ?? '—'}'),
                  Text('المعرّف: ${detail['id'] ?? '—'}'),
                ],
              ),
            ),
          );
        },
      );
    } on MetraApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(opsDetailErrorMessage(error.statusCode, resourceAr: 'بلاغ الدعم'))),
      );
    }
  }

  Future<void> _transition(Map<String, dynamic> row, String toStatus) async {
    String? note;
    if (toStatus == 'Rejected' || toStatus == 'Closed') {
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
      if (entered.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الملاحظة مطلوبة')),
        );
        return;
      }
      note = entered;
    }
    try {
      await widget.api.transitionSupportIncident(
        stationId: widget.stationId,
        incidentId: row['id'].toString(),
        toStatus: toStatus,
        note: note,
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
        SnackBar(content: Text(opsTransitionErrorMessage(error.statusCode, resourceAr: 'بلاغ الدعم'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('بلاغات الدعم'),
        actions: <Widget>[
          IconButton(
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
                    _choiceRow(
                      label: 'نوع البلاغ',
                      options: _kinds,
                      selected: _kind,
                      onSelected: (String value) {
                        setState(() => _kind = value);
                      },
                      labelFor: (String value) =>
                          value == 'InformationTechnology'
                              ? 'تقنية معلومات'
                              : 'اتصالات',
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _category,
                      decoration: const InputDecoration(
                        labelText: 'التصنيف',
                        border: OutlineInputBorder(),
                      ),
                      validator: (String? value) {
                        final String text = value?.trim() ?? '';
                        if (text.length < 2 || text.length > 80) {
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
                      validator: (String? value) {
                        final String text = value?.trim() ?? '';
                        if (text.length < 5 || text.length > 160) {
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
                      validator: (String? value) {
                        final String text = value?.trim() ?? '';
                        if (text.length < 10) {
                          return 'الوصف 10 محارف على الأقل';
                        }
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
                    _choiceRow(
                      label: 'الأولوية',
                      options: _severities,
                      selected: _severity,
                      onSelected: (String value) {
                        setState(() => _severity = value);
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('يؤثر على سير العمل'),
                      value: _impactsOperations,
                      onChanged: _submitting
                          ? null
                          : (bool value) {
                              setState(() => _impactsOperations = value);
                            },
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
            builder: (
              BuildContext context,
              AsyncSnapshot<List<Map<String, dynamic>>> snapshot,
            ) {
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
              final List<Map<String, dynamic>> rows =
                  snapshot.data ?? const <Map<String, dynamic>>[];
              if (rows.isEmpty) {
                return const Card(
                  child: ListTile(title: Text('لا توجد بلاغات دعم مسجّلة')),
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
                              '${row['title'] ?? '—'} • ${row['status'] ?? ''}',
                            ),
                            subtitle: Text(
                              '${row['kind'] ?? ''} • ${row['severity'] ?? ''}\n${row['description'] ?? ''}',
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
                                OutlinedButton(
                                  onPressed: () => _openDetail(row),
                                  child: const Text('تفاصيل من الخادم'),
                                ),
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
