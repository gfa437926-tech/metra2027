import 'package:flutter/material.dart';

import '../../core/api/metra_api_client.dart';
import 'admin_api_messages.dart';

/// Station-scoped manual Excel archive confirmation (administrative only).
class ManualArchiveScreen extends StatefulWidget {
  const ManualArchiveScreen({
    super.key,
    required this.api,
    required this.stationId,
  });

  final MetraApiClient api;
  final String stationId;

  @override
  State<ManualArchiveScreen> createState() => _ManualArchiveScreenState();
}

class _ManualArchiveScreenState extends State<ManualArchiveScreen> {
  final TextEditingController _fileCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();
  late Future<List<Map<String, dynamic>>> _rows;
  Map<String, dynamic>? _summary;
  String _reportKind = 'daily';
  String _fileName = '';
  late int _summaryYear;
  late int _summaryMonth;
  late DateTime _periodStartUtc;
  late DateTime _periodEndUtc;
  bool _saving = false;
  String? _error;
  String? _feedback;

  static const List<String> _kinds = <String>[
    'hourly',
    'daily',
    'monthly',
    'rainfall',
    'climate',
    'other',
  ];

  @override
  void initState() {
    super.initState();
    final DateTime now = DateTime.now().toUtc();
    _periodStartUtc = DateTime.utc(now.year, now.month, now.day);
    _periodEndUtc = _periodStartUtc;
    _summaryYear = now.year;
    _summaryMonth = now.month;
    _reload();
  }

  @override
  void dispose() {
    _fileCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _error = null;
      _rows = widget.api.listArchiveConfirmations(widget.stationId);
    });
    _loadSummary();
  }

  void _loadSummary() {
    widget.api
        .archiveMonthlySummary(
          stationId: widget.stationId,
          year: _summaryYear,
          month: _summaryMonth,
        )
        .then((Map<String, dynamic> value) {
      if (mounted) {
        setState(() => _summary = value);
      }
    }).catchError((Object _) {
      if (mounted) {
        setState(() => _summary = null);
      }
    });
  }

  void _changeSummaryMonth(int delta) {
    final DateTime selected = DateTime.utc(_summaryYear, _summaryMonth + delta, 1);
    final DateTime now = DateTime.now().toUtc();
    final DateTime currentMonth = DateTime.utc(now.year, now.month, 1);
    if (selected.isAfter(currentMonth)) return;
    setState(() {
      _summaryYear = selected.year;
      _summaryMonth = selected.month;
      _summary = null;
    });
    _loadSummary();
  }

  String _summaryMonthLabel() {
    const List<String> months = <String>[
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
    ];
    return '${months[_summaryMonth - 1]} $_summaryYear UTC';
  }

  // These are date-only UTC period values. Do not convert local midnight,
  // which could shift the calendar day on devices outside UTC.
  String _ymdUtc(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)}';
  }

  Future<void> _choosePeriodDate({required bool start}) async {
    final DateTime current = start ? _periodStartUtc : _periodEndUtc;
    final DateTime first = start ? DateTime(2000) : _periodStartUtc;
    final DateTime last = start ? _periodEndUtc : DateTime(2100, 12, 31);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(current.year, current.month, current.day),
      firstDate: first,
      lastDate: last,
      helpText: start ? 'بداية فترة التقرير (UTC)' : 'نهاية فترة التقرير (UTC)',
    );
    if (picked == null || !mounted) return;
    setState(() {
      final DateTime utcDate = DateTime.utc(picked.year, picked.month, picked.day);
      if (start) {
        _periodStartUtc = utcDate;
      } else {
        _periodEndUtc = utcDate;
      }
    });
  }

  Future<void> _confirm() async {
    setState(() {
      _error = null;
      _feedback = null;
      _saving = true;
    });
    try {
      await widget.api.confirmManualArchive(
        stationId: widget.stationId,
        reportKind: _reportKind,
        periodStartUtc: _ymdUtc(_periodStartUtc),
        periodEndUtc: _ymdUtc(_periodEndUtc),
        excelFileName: _fileName,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      );
      _fileCtrl.clear();
      _noteCtrl.clear();
      if (mounted) {
        setState(() {
          _fileName = '';
          _feedback = 'تم تسجيل تأكيد الأرشفة اليدوية.';
        });
        _reload();
      }
    } on MetraApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = adminArchiveError(e.statusCode);
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'تعذر تسجيل التأكيد.');
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Object? confirmationCount = _summary == null
        ? null
        : (_summary!['confirmationCount'] ?? _summary!['ConfirmationCount']);

    return Scaffold(
      appBar: AppBar(
        title: const Text('تأكيد أرشفة Excel'),
        actions: <Widget>[
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const Card(
            color: Color(0xFFFFF7E8),
            child: ListTile(
              title: Text('إداري فقط'),
              subtitle: Text(
                'يسجّل أن الملف أُرشف يدوياً. لا ترحيل أرصاد ولا اتصال بقاعدة أرشيف. الأوقات UTC.',
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: const TextStyle(color: Color(0xFF8A1F2D)),
              ),
            ),
          if (_feedback != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _feedback!,
                style: const TextStyle(color: Color(0xFF1F6B3C)),
              ),
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'ملخص الأرشفة — ${_summaryMonthLabel()}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _summary == null
                        ? 'ملخص الشهر غير متاح حالياً'
                        : 'تأكيدات الأرشفة: ${confirmationCount ?? '—'}',
                  ),
                  if (_summary != null && _summary!['reportKinds'] is List)
                    Text('أنواع التقارير: ${(_summary!['reportKinds'] as List).join('، ')}'),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      TextButton.icon(
                        onPressed: () => _changeSummaryMonth(-1),
                        icon: const Icon(Icons.chevron_right),
                        label: const Text('الشهر السابق'),
                      ),
                      TextButton.icon(
                        onPressed: DateTime.utc(_summaryYear, _summaryMonth + 1, 1)
                                .isAfter(DateTime.utc(
                                  DateTime.now().toUtc().year,
                                  DateTime.now().toUtc().month,
                                  1,
                                ))
                            ? null
                            : () => _changeSummaryMonth(1),
                        icon: const Icon(Icons.chevron_left),
                        label: const Text('الشهر التالي'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text('فترة التقرير بالتاريخ UTC'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: _saving ? null : () => _choosePeriodDate(start: true),
                icon: const Icon(Icons.calendar_today),
                label: Text('من: ${_ymdUtc(_periodStartUtc)}'),
              ),
              OutlinedButton.icon(
                onPressed: _saving ? null : () => _choosePeriodDate(start: false),
                icon: const Icon(Icons.event),
                label: Text('إلى: ${_ymdUtc(_periodEndUtc)}'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text('نوع التقرير'),
          Wrap(
            spacing: 8,
            children: <Widget>[
              for (final String kind in _kinds)
                ChoiceChip(
                  label: Text(kind),
                  selected: _reportKind == kind,
                  onSelected: (bool selected) {
                    if (selected) {
                      setState(() => _reportKind = kind);
                    }
                  },
                ),
            ],
          ),
          TextField(
            controller: _fileCtrl,
            decoration: const InputDecoration(labelText: 'اسم ملف Excel'),
            onChanged: (String value) {
              setState(() => _fileName = value.trim());
            },
          ),
          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(labelText: 'ملاحظة (اختياري)'),
            maxLines: 2,
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _saving || _fileName.isEmpty ? null : _confirm,
            child: Text(_saving ? 'جارٍ الحفظ...' : 'تأكيد الأرشفة اليدوية'),
          ),
          const SizedBox(height: 16),
          const Text('السجل', style: TextStyle(fontWeight: FontWeight.bold)),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _rows,
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
                return const Text('تعذر تحميل السجل أو لا صلاحية.');
              }
              final List<Map<String, dynamic>> rows =
                  snapshot.data ?? const <Map<String, dynamic>>[];
              if (rows.isEmpty) {
                return const Text('لا تأكيدات معروضة لهذه المحطة.');
              }
              return Column(
                children: <Widget>[
                  for (final Map<String, dynamic> row in rows)
                    ListTile(
                      title: Text(
                        '${row['reportKind'] ?? row['ReportKind']} · ${row['excelFileName'] ?? row['ExcelFileName']}',
                      ),
                      subtitle: Text(
                        '${row['periodStartUtc'] ?? row['PeriodStartUtc']} → ${row['periodEndUtc'] ?? row['PeriodEndUtc']} · ${row['confirmedAtUtc'] ?? row['ConfirmedAtUtc']}',
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
