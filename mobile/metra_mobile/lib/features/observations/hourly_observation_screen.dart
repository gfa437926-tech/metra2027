import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import '../../core/api/metra_api_client.dart';
import '../../core/catalog/observation_field_catalogs.dart';
import '../../core/widgets/metra_observation_form.dart';

/// Hourly observation entry bound to the approved .NET validation/submit API.
class HourlyObservationScreen extends StatefulWidget {
  const HourlyObservationScreen({
    super.key,
    required this.api,
    required this.stationId,
  });

  final MetraApiClient api;
  final String stationId;

  @override
  State<HourlyObservationScreen> createState() =>
      _HourlyObservationScreenState();
}

class _HourlyObservationScreenState extends State<HourlyObservationScreen> {
  String? _pendingPayloadFingerprint;
  String? _pendingIdempotencyKey;
  DateTime? _pendingObservedAt;

  Future<void> _submit(Map<String, Object?> values) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final validation = await widget.api.validateObservation(
        observationType: 'hourly',
        values: values,
      );
      if (!validation.isValid) {
        final message = validation.issues.isEmpty
            ? 'رفض الخادم بيانات الرصد الساعي.'
            : validation.issues.first.message;
        messenger.showSnackBar(SnackBar(content: Text(message)));
        return;
      }

      final fingerprint = jsonEncode(values);
      if (_pendingPayloadFingerprint != fingerprint ||
          _pendingIdempotencyKey == null) {
        _pendingPayloadFingerprint = fingerprint;
        _pendingIdempotencyKey = <String>[
          'hourly',
          widget.stationId,
          DateTime.now().toUtc().microsecondsSinceEpoch.toString(),
        ].join('-');
        _pendingObservedAt = DateTime.now().toUtc();
      }

      await widget.api.submitObservation(
        stationId: widget.stationId,
        idempotencyKey: _pendingIdempotencyKey!,
        observationType: 'hourly',
        observedAt: _pendingObservedAt!,
        payload: values,
        submit: true,
      );
      _pendingPayloadFingerprint = null;
      _pendingIdempotencyKey = null;
      _pendingObservedAt = null;
      messenger.showSnackBar(
        const SnackBar(content: Text('أُرسلت الرصدة الساعية إلى الخادم')),
      );
    } on MetraApiException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.displayMessage)));
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
      title: 'الرصد الساعي',
      fields: ObservationFieldCatalogs.hourly,
      onSubmit: _submit,
      submitLabel: 'التحقق وإرسال الرصد الساعي',
    );
  }
}
