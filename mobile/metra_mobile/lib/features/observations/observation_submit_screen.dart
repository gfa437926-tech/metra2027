import 'package:flutter/material.dart';
import '../../core/api/metra_api_client.dart';

/// Hourly observation intake against the real station-scoped submit API.
class ObservationSubmitScreen extends StatefulWidget {
  const ObservationSubmitScreen({
    super.key,
    required this.api,
    required this.stationId,
  });

  final MetraApiClient api;
  final String stationId;

  @override
  State<ObservationSubmitScreen> createState() =>
      _ObservationSubmitScreenState();
}

class _ObservationSubmitScreenState extends State<ObservationSubmitScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _dryTemp = TextEditingController();
  final TextEditingController _wetTemp = TextEditingController();
  final TextEditingController _windSpeed = TextEditingController();
  final TextEditingController _windDirection = TextEditingController();
  final TextEditingController _relativeHumidity = TextEditingController();
  bool _submitImmediately = true;
  bool _saving = false;

  @override
  void dispose() {
    _dryTemp.dispose();
    _wetTemp.dispose();
    _windSpeed.dispose();
    _windDirection.dispose();
    _relativeHumidity.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) {
      return;
    }
    setState(() => _saving = true);
    final String idempotencyKey =
        'hourly-${widget.stationId}-${DateTime.now().toUtc().millisecondsSinceEpoch}';
    try {
      await widget.api.submitObservation(
        stationId: widget.stationId,
        idempotencyKey: idempotencyKey,
        observationType: 'hourly',
        observedAt: DateTime.now().toUtc(),
        payload: <String, dynamic>{
          'dryTemp': _dryTemp.text.trim(),
          'wetTemp': _wetTemp.text.trim(),
          'windSpeed': _windSpeed.text.trim(),
          'windDirection': _windDirection.text.trim(),
          'relativeHumidity': _relativeHumidity.text.trim(),
        },
        submit: _submitImmediately,
      );
      if (!mounted) {
        return;
      }
      _dryTemp.clear();
      _wetTemp.clear();
      _windSpeed.clear();
      _windDirection.clear();
      _relativeHumidity.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _submitImmediately
                ? 'تم إرسال النشرة للمراجعة'
                : 'تم حفظ مسودة النشرة',
          ),
        ),
      );
    } on MetraApiException catch (error) {
      if (!mounted) {
        return;
      }
      final String message = switch (error.statusCode) {
        400 => 'بيانات النشرة غير صالحة',
        401 => 'يلزم تسجيل الدخول',
        403 => 'ليست لديك صلاحية الإرسال لهذه المحطة',
        409 => 'تعارض مفتاح منع التكرار',
        503 => 'خدمة الرصد غير متاحة حالياً',
        _ => 'تعذر إرسال النشرة (${error.statusCode})',
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إدخال نشرة ساعية')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Text(
              'المحطة: ${widget.stationId}',
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _dryTemp,
              decoration: const InputDecoration(
                labelText: 'الحرارة الجافة',
                border: OutlineInputBorder(),
              ),
              validator: (String? value) {
                final String text = value?.trim() ?? '';
                if (text.isEmpty) {
                  return 'مطلوب';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _wetTemp,
              decoration: const InputDecoration(
                labelText: 'الحرارة الرطبة',
                border: OutlineInputBorder(),
              ),
              validator: (String? value) {
                final String text = value?.trim() ?? '';
                if (text.isEmpty) {
                  return 'مطلوب';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _relativeHumidity,
              decoration: const InputDecoration(
                labelText: 'الرطوبة النسبية',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _windDirection,
              decoration: const InputDecoration(
                labelText: 'اتجاه الرياح',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _windSpeed,
              decoration: const InputDecoration(
                labelText: 'سرعة الرياح',
                border: OutlineInputBorder(),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('إرسال للمراجعة فوراً'),
              subtitle: const Text('إذا أُوقف الحفظ كمسودة فقط'),
              value: _submitImmediately,
              onChanged: _saving
                  ? null
                  : (bool value) {
                      setState(() => _submitImmediately = value);
                    },
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.send),
              label: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ النشرة'),
            ),
          ],
        ),
      ),
    );
  }
}
