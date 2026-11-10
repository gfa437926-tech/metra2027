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
  late Future<List<Map<String, dynamic>>> _rows;
  Map<String, dynamic>? _summary;
  String _reportKind = 'daily';
  final _fileCtrl = TextEditingController();
  String _fileName = '';
  final _noteCtrl = TextEditingController();
  DateTime _start = DateTime.now().toUtc();
  DateTime _end = DateTime.now().toUtc();
  bool _saving = false;
  String? _error;
  String? _feedback;

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
    final now = DateTime.now().toUtc();
    widget.api
        .archiveMonthlySummary(
          stationId: widget.stationId,
          year: now.year,
          month: now.month,
        )
        .then((value) {
      if (mounted) setState(() => _summary = value);
    }).catchError((_) {
      if (mounted) setState(() => _summary = null);
    });
  }

  String _ymd(DateTime d) {
    final u = d.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${u.year}-${two(u.month)}-${two(u.day)}';
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
        periodStartUtc: _ymd(_start),
        periodEndUtc: _ymd(_end),
        excelFileName: _fileCtrl.text.trim(),
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      );
      _fileCtrl.clear();
      _noteCtrl.clear();
      if (mounted) {
        setState(() => _feedback = 'تم تسجيل تأكيد الأرشفة اليدوية.');
        _reload();
      }
    } on MetraApiException catch (e) {
      setState(() {
        _error = switch (e.statusCode) {
          403 => 'ليست لديك صلاحية تأكيد الأرشفة لهذه المحطة.',
          409 => 'تأكيد مكرر لنفس الملف والفترة والنوع.',
          503 => 'دفتر الأرشفة غير مهيأ بعد على الخادم.',
          _ => 'تعذر تسجيل التأكيد (HTTP ${e.statusCode}).',
        };
      });
    } catch (_) {
      setState(() => _error = 'تعذر تسجيل التأكيد.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تأكيد أرشفة Excel'),
        actions: [
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
              child: Text(_error!, style: const TextStyle(color: Color(0xFF8A1F2D))),
            ),
          if (_feedback != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_feedback!, style: const TextStyle(color: Color(0xFF1F6B3C))),
            ),
          if (_summary != null)
            Card(
              child: ListTile(
                title: const Text('ملخص الشهر الحالي (UTC)'),
                subtitle: Text(
                  'التأكيدات: ${_summary!['confirmationCount'] ?? _summary!['ConfirmationCount'] ?? '—'}',
                ),
              ),
            ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _reportKind,
            decoration: const InputDecoration(labelText: 'نوع التقرير'),
            items: const [
              DropdownMenuItem(value: 'hourly', child: Text('ساعي')),
              DropdownMenuItem(value: 'daily', child: Text('يومي')),
              DropdownMenuItem(value: 'monthly', child: Text('شهري')),
              DropdownMenuItem(value: 'rainfall', child: Text('مطري')),
              DropdownMenuItem(value: 'climate', child: Text('مناخي')),
              DropdownMenuItem(value: 'other', child: Text('أخرى')),
            ],
            onChanged: (v) => setState(() => _reportKind = v ?? 'daily'),
          ),
          TextFormField(
            controller: _fileCtrl,
            decoration: const InputDecoration(labelText: 'اسم ملف Excel'),
            onChanged: (v) => setState(() => _fileName = v.trim()),
          ),
          TextFormField(
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
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return const Text('تعذر تحميل السجل أو لا صلاحية.');
              }
              final rows = snapshot.data ?? const [];
              if (rows.isEmpty) {
                return const Text('لا تأكيدات معروضة لهذه المحطة.');
              }
              return Column(
                children: rows
                    .map(
                      (r) => ListTile(
                        title: Text('${r['reportKind'] ?? r['ReportKind']} · ${r['excelFileName'] ?? r['ExcelFileName']}'),
                        subtitle: Text(
                          '${r['periodStartUtc'] ?? r['PeriodStartUtc']} → ${r['periodEndUtc'] ?? r['PeriodEndUtc']} · ${r['confirmedAtUtc'] ?? r['ConfirmedAtUtc']}',
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
