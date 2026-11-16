import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import '../../core/api/metra_api_client.dart';
import '../../core/catalog/observation_field_catalogs.dart';
import '../../core/widgets/metra_observation_form.dart';

class DailyObservationScreen extends StatefulWidget {
  const DailyObservationScreen({
    super.key,
    required this.api,
    required this.stationId,
  });

  final MetraApiClient api;
  final String stationId;

  @override
  State<DailyObservationScreen> createState() => _DailyObservationScreenState();
}

class _DailyObservationScreenState extends State<DailyObservationScreen> {
  String? _pendingPayloadFingerprint;
  String? _pendingIdempotencyKey;
  DateTime? _pendingObservedAt;

  Future<void> _submit(Map<String, Object?> values) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final validation = await widget.api.validateObservation(
        observationType: 'daily',
        values: values,
      );
      if (!validation.isValid) {
        final message = validation.issues.isEmpty
            ? 'رفض الخادم بيانات الرصد اليومي.'
            : validation.issues.first.message;
        messenger.showSnackBar(SnackBar(content: Text(message)));
        return;
      }

      final fingerprint = jsonEncode(values);
      if (_pendingPayloadFingerprint != fingerprint ||
          _pendingIdempotencyKey == null) {
        _pendingPayloadFingerprint = fingerprint;
        _pendingIdempotencyKey = <String>[
          'daily',
          widget.stationId,
          DateTime.now().toUtc().microsecondsSinceEpoch.toString(),
        ].join('-');
        _pendingObservedAt = DateTime.now().toUtc();
      }

      await widget.api.submitObservation(
        stationId: widget.stationId,
        idempotencyKey: _pendingIdempotencyKey!,
        observationType: 'daily',
        observedAt: _pendingObservedAt!,
        payload: values,
        submit: true,
      );
      _pendingPayloadFingerprint = null;
      _pendingIdempotencyKey = null;
      _pendingObservedAt = null;
      messenger.showSnackBar(
        const SnackBar(content: Text('أُرسلت الرصدة اليومية إلى الخادم')),
      );
    } on MetraApiException catch (error) {
      final message = switch (error.statusCode) {
        503 => 'الإرسال غير متاح حالياً (بوابة أو خدمة مغلقة على الخادم).',
        401 => 'يلزم تسجيل الدخول من جديد.',
        403 => 'لا تملك صلاحية الإرسال لهذه المحطة.',
        _ => <String>['فشل الإرسال (', error.statusCode.toString(), ').'].join(),
      };
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('تعذر الإرسال. تحقق من الاتصال وأعد المحاولة.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MetraObservationForm(
      title: 'الرصد اليومي',
      fields: ObservationFieldCatalogs.daily,
      onSubmit: _submit,
      submitLabel: 'التحقق وإرسال الرصد اليومي',
    );
  }
}
