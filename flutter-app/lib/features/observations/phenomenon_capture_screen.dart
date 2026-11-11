import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/api/metra_api_client.dart';
import 'observation_api_messages.dart';

/// Captures one phenomenon locally, then validates and submits it through the
/// station-scoped observation API. The client never writes directly to storage.
class PhenomenonCaptureScreen extends StatefulWidget {
  const PhenomenonCaptureScreen({
    super.key,
    required this.api,
    required this.stationId,
  });

  final MetraApiClient api;
  final String stationId;

  @override
  State<PhenomenonCaptureScreen> createState() => _PhenomenonCaptureScreenState();
}

class _PhenomenonCaptureScreenState extends State<PhenomenonCaptureScreen> {
  final _type = TextEditingController();
  final _notes = TextEditingController();
  final _watch = Stopwatch();
  Timer? _ticker;
  DateTime? _startedAtUtc;
  DateTime? _endedAtUtc;
  String? _idempotencyKey;
  String? _savedId;
  String? _error;
  String? _validationMessage;
  bool _paused = false;
  bool _saving = false;
  Duration _elapsed = Duration.zero;

  bool get _started => _startedAtUtc != null;
  bool get _ended => _endedAtUtc != null;
  bool get _canStart => !_started && !_saving && _type.text.trim().isNotEmpty;

  @override
  void dispose() {
    _ticker?.cancel();
    _watch.stop();
    _type.dispose();
    _notes.dispose();
    super.dispose();
  }

  String _utcTime(DateTime value) => value.toUtc().toIso8601String().substring(11, 19);
  String _utcDate(DateTime value) => value.toUtc().toIso8601String().substring(0, 10);

  String _duration(Duration value) {
    final hours = value.inHours.toString().padLeft(2, '0');
    final minutes = (value.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (value.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  String _newIdempotencyKey() {
    final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    final suffix = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return 'phenomenon-$suffix';
  }

  void _start() {
    if (!_canStart) return;
    setState(() {
      _startedAtUtc = DateTime.now().toUtc();
      _idempotencyKey = _newIdempotencyKey();
      _elapsed = Duration.zero;
      _paused = false;
      _endedAtUtc = null;
      _savedId = null;
      _error = null;
      _validationMessage = null;
      _watch
        ..reset()
        ..start();
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_paused && !_ended) {
        setState(() => _elapsed = _watch.elapsed);
      }
    });
  }

  void _togglePause() {
    if (!_started || _ended || _saving) return;
    setState(() {
      if (_paused) {
        _watch.start();
      } else {
        _watch.stop();
        _elapsed = _watch.elapsed;
      }
      _paused = !_paused;
    });
  }

  Future<void> _finish() async {
    if (!_started || _ended || _saving) return;
    _watch.stop();
    _ticker?.cancel();
    setState(() {
      _endedAtUtc = DateTime.now().toUtc();
      _elapsed = _watch.elapsed;
      _paused = false;
      _error = null;
    });
    await _save();
  }

  Future<void> _save() async {
    final start = _startedAtUtc;
    final end = _endedAtUtc;
    if (start == null || end == null || _savedId != null || _saving) return;

    if (widget.stationId.trim().isEmpty) {
      setState(() => _error = 'لا توجد محطة محددة. ارجع إلى دليل المحطات واختر المحطة أولاً.');
      return;
    }
    if (_utcDate(start) != _utcDate(end)) {
      setState(() => _error =
          'انتهت الظاهرة في يوم UTC تالٍ. عقد التحقق الحالي لا يحتوي تاريخ انتهاء منفصلاً؛ لم يُرسل السجل.');
      return;
    }
    if (!widget.api.isConfigured) {
      setState(() => _error = 'واجهة API غير مهيأة؛ لم يتم حفظ الظاهرة.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
      _validationMessage = null;
    });
    try {
      final type = _type.text.trim();
      final notes = _notes.text.trim();
      final date = _utcDate(start);
      final startTime = _utcTime(start);
      final endTime = _utcTime(end);

      final validation = await widget.api.validateWeatherPhenomenon(
        phenomenonType: type,
        phenomenonDate: date,
        startTime: startTime,
        endTime: endTime,
        generalNotes: notes,
      );
      if (validation['isValid'] != true) {
        final issues = validation['issues'];
        final messages = issues is List
            ? issues.whereType<Map>().map((item) =>
                (item['message'] ?? item['Message'] ?? 'حقل غير صالح').toString()).toList()
            : <String>[];
        if (mounted) {
          setState(() => _validationMessage = messages.isEmpty
              ? 'رفض الخادم التحقق من بيانات الظاهرة.'
              : messages.join('\n'));
        }
        return;
      }

      final receipt = await widget.api.submitObservation(
        stationId: widget.stationId,
        idempotencyKey: _idempotencyKey!,
        observationType: 'phenomenon',
        observedAt: start,
        payload: {
          'values': {
            'phenomenonType': type,
            'phenomenonDate': date,
            'startTime': startTime,
            'endTime': endTime,
            'duration': _duration(_elapsed),
            'status': 'منتهية',
            'notes': notes,
          },
        },
        submit: true,
      );
      if (mounted) {
        setState(() {
          _savedId = receipt['id']?.toString();
          _validationMessage = null;
          _error = _savedId == null || _savedId!.isEmpty
              ? 'لم يُرجع الخادم معرّف إيصال صالحاً.'
              : null;
        });
      }
    } on MetraApiException catch (e) {
      if (mounted) {
        setState(() => _error = observationSubmitErrorMessage(e.statusCode));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'تعذر التحقق أو حفظ الظاهرة. بقيت بيانات الجلسة ويمكن إعادة المحاولة.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _reset() {
    _ticker?.cancel();
    _watch
      ..stop()
      ..reset();
    setState(() {
      _startedAtUtc = null;
      _endedAtUtc = null;
      _idempotencyKey = null;
      _savedId = null;
      _elapsed = Duration.zero;
      _paused = false;
      _error = null;
      _validationMessage = null;
      _type.clear();
      _notes.clear();
    });
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('تسجيل ظاهرة جوية'),
            actions: [
              IconButton(
                onPressed: _saving || !_started ? null : _save,
                tooltip: 'إعادة محاولة الحفظ',
                icon: const Icon(Icons.cloud_upload_outlined),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.location_on_outlined),
                  title: const Text('المحطة المحددة'),
                  subtitle: SelectableText(widget.stationId),
                ),
              ),
              const Card(
                child: ListTile(
                  leading: Icon(Icons.shield_outlined),
                  title: Text('حفظ موثوق عبر الخادم'),
                  subtitle: Text(
                    'يُسجل المؤقت محلياً أثناء الظاهرة. عند الإنهاء تُرسل البيانات إلى API بعد التحقق؛ لا يُعد السجل محفوظاً قبل استلام معرّف الإيصال.',
                  ),
                ),
              ),
              TextField(
                controller: _type,
                enabled: !_started || (_ended && _savedId == null),
                maxLength: 64,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'نوع الظاهرة الجوية',
                  hintText: 'مثال: مطر خفيف، ضباب، عاصفة رعدية',
                ),
              ),
              TextField(
                controller: _notes,
                enabled: _savedId == null,
                maxLength: 2000,
                onChanged: (_) => setState(() {}),
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'ملاحظات إضافية'),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      Text(
                        _savedId != null
                            ? 'تم حفظ الظاهرة'
                            : _ended
                                ? 'انتهت الظاهرة — بانتظار الحفظ'
                                : _paused
                                    ? 'التسجيل متوقف مؤقتاً'
                                    : _started
                                        ? 'الظاهرة قيد التسجيل'
                                        : 'لا توجد ظاهرة نشطة',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _duration(_elapsed),
                        style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      if (_startedAtUtc != null)
                        _timeRow('وقت البدء UTC', _startedAtUtc!),
                      if (_endedAtUtc != null)
                        _timeRow('وقت الانتهاء UTC', _endedAtUtc!),
                      if (_startedAtUtc != null)
                        _timeRow('وقت الجهاز عند البدء', _startedAtUtc!, local: true),
                      const SizedBox(height: 16),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (!_started)
                            FilledButton.icon(
                              onPressed: _canStart ? _start : null,
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('بدء الظاهرة'),
                            ),
                          if (_started && !_ended)
                            OutlinedButton.icon(
                              onPressed: _saving ? null : _togglePause,
                              icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
                              label: Text(_paused ? 'استئناف' : 'إيقاف مؤقت'),
                            ),
                          if (_started && !_ended)
                            FilledButton.icon(
                              onPressed: _saving ? null : _finish,
                              icon: const Icon(Icons.stop),
                              label: const Text('إنهاء والتحقق والحفظ'),
                            ),
                          if (_ended && _savedId == null)
                            FilledButton.icon(
                              onPressed: _saving ? null : _save,
                              icon: const Icon(Icons.refresh),
                              label: const Text('إعادة محاولة الحفظ'),
                            ),
                          if (_savedId != null)
                            OutlinedButton.icon(
                              onPressed: _reset,
                              icon: const Icon(Icons.add),
                              label: const Text('تسجيل ظاهرة جديدة'),
                            ),
                          if (_ended && _savedId == null && !_saving)
                            TextButton.icon(
                              onPressed: _reset,
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('إلغاء المعاينة المحلية'),
                            ),
                        ],
                      ),
                      if (_saving) const Padding(
                        padding: EdgeInsets.only(top: 14),
                        child: LinearProgressIndicator(),
                      ),
                    ],
                  ),
                ),
              ),
              if (_validationMessage != null)
                _notice(_validationMessage!, isError: true),
              if (_error != null) _notice(_error!, isError: true),
              if (_savedId != null)
                Card(
                  color: const Color(0xFFEAF7EF),
                  child: ListTile(
                    leading: const Icon(Icons.verified_outlined, color: Colors.green),
                    title: const Text('إيصال الحفظ من الخادم'),
                    subtitle: SelectableText(_savedId!),
                  ),
                ),
              const Text(
                'ملاحظة التوقيت: الوقت المعروض محلياً هو توقيت الجهاز فقط، وليس إعداد المنطقة الزمنية الرسمية للمحطة.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      );

  Widget _timeRow(String label, DateTime value, {bool local = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            Text(local ? value.toLocal().toString() : value.toUtc().toIso8601String()),
          ],
        ),
      );

  Widget _notice(String message, {bool isError = false}) => Card(
        color: isError ? const Color(0xFFFFEEEE) : const Color(0xFFEAF7EF),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(message,
              style: TextStyle(color: isError ? Colors.red.shade900 : Colors.green.shade900)),
        ),
      );
}
