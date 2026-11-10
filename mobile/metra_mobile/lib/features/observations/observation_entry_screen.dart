import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/api/metra_api_client.dart';

class ObservationEntryScreen extends StatefulWidget {
  const ObservationEntryScreen({super.key, required this.api, required this.stationId});
  final MetraApiClient api;
  final String stationId;
  @override
  State<ObservationEntryScreen> createState() => _ObservationEntryScreenState();
}

class _ObservationEntryScreenState extends State<ObservationEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _payload = TextEditingController(text: '{\n  "temperature": 0\n}');
  String _type = 'hourly';
  DateTime _observedAt = DateTime.now().toUtc();
  bool _submitForReview = true, _busy = false;
  String? _error;
  String? _pendingIdempotencyKey;
  String? _pendingFingerprint;

  @override
  void dispose() { _payload.dispose(); super.dispose(); }

  String _newIdempotencyKey() => List<int>.generate(32, (_) => Random.secure().nextInt(256))
    .map((v) => v.toRadixString(16).padLeft(2, '0')).join();

  String _fingerprint(Map<String, dynamic> payload) => jsonEncode({
    'stationId': widget.stationId,
    'type': _type,
    'observedAt': _observedAt.toUtc().toIso8601String(),
    'payload': payload,
    'submit': _submitForReview,
  });

  Future<void> _save() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    Map<String, dynamic> payload;
    try {
      final decoded = jsonDecode(_payload.text);
      if (decoded is! Map) throw const FormatException();
      payload = Map<String, dynamic>.from(decoded);
    } catch (_) {
      setState(() => _error = 'يجب أن تكون البيانات JSON صحيحة على شكل كائن.');
      return;
    }
    final fingerprint = _fingerprint(payload);
    if (_pendingFingerprint != fingerprint || _pendingIdempotencyKey == null) {
      _pendingFingerprint = fingerprint;
      _pendingIdempotencyKey = _newIdempotencyKey();
    }
    setState(() { _busy = true; _error = null; });
    try {
      await widget.api.submitObservation(
        stationId: widget.stationId,
        idempotencyKey: _pendingIdempotencyKey!,
        observationType: _type,
        observedAt: _observedAt,
        payload: payload,
        submit: _submitForReview,
      );
      _pendingIdempotencyKey = null;
      _pendingFingerprint = null;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('تم حفظ بيانات الرصد وإرسالها إلى الخادم.')));
      Navigator.of(context).pop(true);
    } on MetraApiException catch (error) {
      if (mounted) {
        setState(() => _error = switch (error.statusCode) {
        400 => 'رفض الخادم بنية البيانات أو نوع الرصد.',
        401 => 'انتهت جلسة الدخول. سجّل الدخول مجدداً.',
        403 => 'لا تملك صلاحية إدخال الرصد لهذه المحطة.',
        409 => 'تعارض في مفتاح الإرسال أو حالة الرصد.',
        503 => 'خدمة الرصد غير متاحة حالياً.',
        _ => 'تعذر حفظ الرصد.',
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر الاتصال بخدمة الرصد.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _formatUtc(DateTime value) {
    final utc = value.toUtc();
    String two(int part) => part.toString().padLeft(2, '0');
    return '${utc.year}-${two(utc.month)}-${two(utc.day)} ${two(utc.hour)}:${two(utc.minute)}';
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(title: const Text('إدخال رصد جديد')),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('بيانات الرصد', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'نوع الرصد', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'hourly', child: Text('نشرة ساعية')),
                DropdownMenuItem(value: 'daily', child: Text('نشرة يومية')),
                DropdownMenuItem(value: 'phenomenon', child: Text('بلاغ ظاهرة جوية')),
              ],
              onChanged: (value) => setState(() => _type = value ?? 'hourly'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _busy ? null : () async {
                final picked = await showDatePicker(context: context,
                  initialDate: _observedAt, firstDate: DateTime(2000),
                  lastDate: DateTime.now().toUtc().add(const Duration(days: 2)));
                if (!context.mounted) {
                  return;
                }
                if (picked == null) {
                  return;
                }
                final time = await showTimePicker(context: context,
                  initialTime: TimeOfDay.fromDateTime(_observedAt));
                if (!context.mounted || time == null) {
                  return;
                }
                setState(() => _observedAt = DateTime.utc(
                  picked.year, picked.month, picked.day, time.hour, time.minute));
              },
              icon: const Icon(Icons.schedule),
              label: Text('وقت الرصد: ${_formatUtc(_observedAt)} UTC'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _payload,
              minLines: 8, maxLines: 16,
              keyboardType: TextInputType.multiline,
              decoration: const InputDecoration(
                labelText: 'حمولة الرصد بصيغة JSON',
                helperText: 'أدخل الحقول وفق نموذج الرصد المعتمد. يرسل التطبيق كائن JSON إلى API دون تعديل مخطط قاعدة البيانات.',
                border: OutlineInputBorder(), alignLabelWithHint: true),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return 'أدخل بيانات الرصد';
                try {
                  final decoded = jsonDecode(value);
                  if (decoded is! Map) return 'يجب إدخال كائن JSON وليس قائمة';
                  if (utf8.encode(value).length > 65536) return 'حجم البيانات يتجاوز 64 كيلوبايت';
                } catch (_) { return 'صيغة JSON غير صحيحة'; }
                return null;
              },
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('إرسال للمراجعة بعد الحفظ'),
              subtitle: const Text('عند الإيقاف يُحفظ كرصد غير مرسل إذا كان عقد الخادم يسمح بذلك.'),
              value: _submitForReview,
              onChanged: _busy ? null : (value) => setState(() => _submitForReview = value),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busy ? null : _save,
              icon: _busy ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.cloud_upload_outlined),
              label: Text(_busy ? 'جارٍ الحفظ...' : 'حفظ الرصد'),
            ),
          ]),
        ))),
      ]),
    ),
  );
}
