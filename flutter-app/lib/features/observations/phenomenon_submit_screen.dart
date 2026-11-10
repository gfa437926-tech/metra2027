import 'package:flutter/material.dart';

import '../../core/api/metra_api_client.dart';

/// Station-scoped weather phenomenon submit via live observation API (UTC).
class PhenomenonSubmitScreen extends StatefulWidget {
  const PhenomenonSubmitScreen({
    super.key,
    required this.api,
    required this.stationId,
  });

  final MetraApiClient api;
  final String stationId;

  @override
  State<PhenomenonSubmitScreen> createState() => _PhenomenonSubmitScreenState();
}

class _PhenomenonSubmitScreenState extends State<PhenomenonSubmitScreen> {
  final TextEditingController _typeCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();
  DateTime? _startedAtUtc;
  bool _busy = false;
  String? _error;
  String? _receiptId;

  @override
  void dispose() {
    _typeCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _start() {
    if (_typeCtrl.text.trim().isEmpty) {
      setState(() => _error = 'أدخل نوع الظاهرة.');
      return;
    }
    setState(() {
      _error = null;
      _receiptId = null;
      _startedAtUtc = DateTime.now().toUtc();
    });
  }

  Future<void> _endAndSubmit() async {
    final DateTime? start = _startedAtUtc;
    if (start == null) {
      setState(() => _error = 'ابدأ الظاهرة أولاً.');
      return;
    }
    final DateTime end = DateTime.now().toUtc();
    final Duration d = end.difference(start);
    final String duration =
        '${d.inHours.toString().padLeft(2, '0')}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

    setState(() {
      _busy = true;
      _error = null;
      _receiptId = null;
    });
    try {
      final Map<String, dynamic> receipt = await widget.api.submitObservation(
        stationId: widget.stationId,
        idempotencyKey:
            'phenomenon-${widget.stationId}-${start.millisecondsSinceEpoch}',
        observationType: 'phenomenon',
        observedAt: start,
        payload: <String, dynamic>{
          'values': <String, dynamic>{
            'phenomenonType': _typeCtrl.text.trim(),
            'phenomenonDate':
                '${start.year.toString().padLeft(4, '0')}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}',
            'startTime':
                '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}:${start.second.toString().padLeft(2, '0')}',
            'endTime':
                '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}:${end.second.toString().padLeft(2, '0')}',
            'duration': duration,
            'status': 'منتهية',
            'notes': _notesCtrl.text.trim(),
          },
        },
        submit: true,
      );
      if (mounted) {
        setState(() {
          _receiptId = receipt['id'] as String?;
          _startedAtUtc = null;
        });
      }
    } on MetraApiException catch (e) {
      setState(() {
        _error = switch (e.statusCode) {
          403 => 'لا صلاحية لإرسال ظاهرة لهذه المحطة.',
          401 => 'يلزم تسجيل الدخول.',
          _ => 'فشل الإرسال (HTTP ${e.statusCode}).',
        };
      });
    } catch (_) {
      setState(() => _error = 'تعذر الإرسال أو لم يُستلم إيصال حفظ.');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ظاهرة جوية')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const Card(
            color: Color(0xFFEEF6FA),
            child: ListTile(
              title: Text('UTC فقط'),
              subtitle: Text(
                'البدء والإنهاء يُسجَّلان بالتوقيت العالمي. الحفظ عبر API مع إيصال id.',
              ),
            ),
          ),
          TextField(
            controller: _typeCtrl,
            decoration: const InputDecoration(labelText: 'نوع الظاهرة'),
            enabled: _startedAtUtc == null && !_busy,
          ),
          TextField(
            controller: _notesCtrl,
            decoration: const InputDecoration(labelText: 'ملاحظات'),
            maxLines: 2,
            enabled: !_busy,
          ),
          const SizedBox(height: 12),
          if (_startedAtUtc != null)
            Text('بدء UTC: ${_startedAtUtc!.toIso8601String()}'),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Color(0xFF8A1F2D))),
          if (_receiptId != null)
            Text(
              'إيصال الحفظ: $_receiptId',
              style: const TextStyle(color: Color(0xFF1F6B3C)),
            ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy || _startedAtUtc != null ? null : _start,
                  child: const Text('بدء'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _busy || _startedAtUtc == null ? null : _endAndSubmit,
                  child: Text(_busy ? 'جارٍ الحفظ...' : 'إنهاء وحفظ'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
