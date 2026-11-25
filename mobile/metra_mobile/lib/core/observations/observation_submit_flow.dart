import 'dart:convert';

import '../api/metra_api_client.dart';
import '../drafts/observation_draft_store.dart';
import '../errors/metra_error_presenter.dart';

/// Result of a connected observation validate+submit attempt.
class ObservationSubmitOutcome {
  const ObservationSubmitOutcome._({
    required this.succeeded,
    required this.messageAr,
    this.clearedDraft = false,
  });

  factory ObservationSubmitOutcome.success(String messageAr) =>
      ObservationSubmitOutcome._(
        succeeded: true,
        messageAr: messageAr,
        clearedDraft: true,
      );

  factory ObservationSubmitOutcome.failure(String messageAr) =>
      ObservationSubmitOutcome._(succeeded: false, messageAr: messageAr);

  final bool succeeded;
  final String messageAr;
  final bool clearedDraft;
}

/// Shared validate → submit → draft-clear flow for hourly/daily/phenomenon.
///
/// Station/generation guards remain the caller's responsibility around this
/// call so a late response never mutates a switched station.
class ObservationSubmitFlow {
  ObservationSubmitFlow({required this.api, ObservationDraftStore? draftStore})
    : _drafts = draftStore ?? ObservationDraftStore.instance;

  final MetraApiClient api;
  final ObservationDraftStore _drafts;

  String? _pendingPayloadFingerprint;
  String? _pendingIdempotencyKey;
  DateTime? _pendingObservedAt;

  void resetPending() {
    _pendingPayloadFingerprint = null;
    _pendingIdempotencyKey = null;
    _pendingObservedAt = null;
  }

  Future<ObservationSubmitOutcome> validateAndSubmit({
    required String formType,
    required String stationId,
    required Map<String, Object?> values,
    required String successMessageAr,
    required String validationFallbackAr,
  }) async {
    try {
      final validation = await api.validateObservation(
        observationType: formType,
        values: values,
      );
      if (!validation.isValid) {
        final message = validation.issues.isEmpty
            ? validationFallbackAr
            : validation.issues.first.message;
        return ObservationSubmitOutcome.failure(message);
      }

      final fingerprint = jsonEncode(values);
      if (_pendingPayloadFingerprint != fingerprint ||
          _pendingIdempotencyKey == null) {
        _pendingPayloadFingerprint = fingerprint;
        _pendingIdempotencyKey = <String>[
          formType,
          stationId,
          DateTime.now().toUtc().microsecondsSinceEpoch.toString(),
        ].join('-');
        _pendingObservedAt = DateTime.now().toUtc();
      }

      await api.submitObservation(
        stationId: stationId,
        idempotencyKey: _pendingIdempotencyKey!,
        observationType: formType,
        observedAt: _pendingObservedAt!,
        payload: values,
        submit: true,
      );

      resetPending();
      _drafts.clear(stationId, formType);
      return ObservationSubmitOutcome.success(successMessageAr);
    } on MetraApiException catch (error) {
      return ObservationSubmitOutcome.failure(
        MetraErrorPresenter.submitMessage(error),
      );
    } catch (error) {
      return ObservationSubmitOutcome.failure(
        MetraErrorPresenter.messageFor(error),
      );
    }
  }
}
