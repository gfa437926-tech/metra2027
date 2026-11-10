import 'package:flutter/material.dart';

import '../../core/api/metra_api_client.dart';

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
    final DateTime now = DateTime.now().toUtc();
    widget.api
        .archiveMonthlySummary(
          stationId: widget.stationId,
          year: now.year,
          month: now.month,
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

  String _ymdUtc(DateTime value) {
    final DateTime utc = value.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${utc.year}-${two(utc.month)}-${two(utc.day)}';
  }

  Future<void> _confirm() async {
    setState(() {
      _error = null;
      _feedback = null;
      _saving = true;
    });
    final DateTime today = DateTime.now().toUtc();
    try {
      await widget.api.confirmManualArchive(
        stationId: widget.stationId,
        reportKind: _reportKind,
        periodStartUtc: _ymdUtc(today),
        periodEndUtc: _ymdUtc(today),
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
        _error = switch (e.statusCode) {
          403 => 'ليست لديك صلاحية تأكيد الأرشفة لهذه المحطة.',
          409 => 'تأكيد مكرر لنفس الملف والفترة والنوع.',
          503 => 'دفتر الأرشفة غير مهيأ بعد على الخادم.',
          _ => 'تعذر تسجيل التأكيد (HTTP ${e.statusCode}).',
        };
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
          if (_summary != null)
            Card(
              child: ListTile(
                title: const Text('ملخص الشهر الحالي (UTC)'),
                subtitle: Text('التأكيدات: ${confirmationCount ?? '—'}'),
              ),
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
