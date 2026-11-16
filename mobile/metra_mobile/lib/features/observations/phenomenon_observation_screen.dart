import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import '../../core/api/metra_api_client.dart';
import '../../core/catalog/observation_field_catalogs.dart';
import '../../core/widgets/metra_observation_form.dart';

/// Weather phenomenon report screen bound to the approved domain contract:
/// phenomenonType, phenomenonDate (yyyy-MM-dd), startTime/endTime (HH:mm:ss UTC),
/// generalNotes, responsibilityAgreement.
class PhenomenonObservationScreen extends StatefulWidget {
  const PhenomenonObservationScreen({
    super.key,
    required this.api,
    required this.stationId,
  });

  final MetraApiClient api;
  final String stationId;

  @override
  State<PhenomenonObservationScreen> createState() =>
      _PhenomenonObservationScreenState();
}

class _PhenomenonObservationScreenState
    extends State<PhenomenonObservationScreen> {
  String? _pendingPayloadFingerprint;
  String? _pendingIdempotencyKey;
  DateTime? _pendingObservedAt;
  bool _submitting = false;

  Future<void> _submit(Map<String, Object?> values) async {
    if (_submitting) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _submitting = true);
    try {
      final validation = await widget.api.validateObservation(
        observationType: 'phenomenon',
        values: values,
      );
      if (!validation.isValid) {
        final message = validation.issues.isEmpty
            ? 'رفض الخادم بيانات بلاغ الظاهرة.'
            : validation.issues.first.message;
        messenger.showSnackBar(SnackBar(content: Text(message)));
        return;
      }

      final fingerprint = jsonEncode(values);
      if (_pendingPayloadFingerprint != fingerprint ||
          _pendingIdempotencyKey == null) {
        _pendingPayloadFingerprint = fingerprint;
        _pendingIdempotencyKey = <String>[
          'phenomenon',
          widget.stationId,
          DateTime.now().toUtc().microsecondsSinceEpoch.toString(),
        ].join('-');
        _pendingObservedAt = DateTime.now().toUtc();
      }

      await widget.api.submitObservation(
        stationId: widget.stationId,
        idempotencyKey: _pendingIdempotencyKey!,
        observationType: 'phenomenon',
        observedAt: _pendingObservedAt!,
        payload: values,
        submit: true,
      );
      _pendingPayloadFingerprint = null;
      _pendingIdempotencyKey = null;
      _pendingObservedAt = null;
      messenger.showSnackBar(
        const SnackBar(content: Text('أُرسل بلاغ الظاهرة الجوية إلى الخادم')),
      );
    } on MetraApiException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.displayMessage)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('تعذر الإرسال. تحقق من الاتصال وأعد المحاولة.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MetraObservationForm(
      title: 'بلاغ ظاهرة جوية',
      fields: ObservationFieldCatalogs.phenomenon,
      onSubmit: _submit,
      submitLabel: _submitting
          ? 'جارٍ الإرسال...'
          : 'التحقق وإرسال بلاغ الظاهرة',
    );
  }
}
