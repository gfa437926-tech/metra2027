import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import '../../core/api/metra_api_client.dart';
import '../../core/errors/metra_error_presenter.dart';
import '../../core/catalog/observation_field_catalogs.dart';
import '../../core/drafts/observation_draft_store.dart';
import '../../core/drafts/observation_draft_ui.dart';
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
  static const _formType = 'hourly';

  String? _pendingPayloadFingerprint;
  String? _pendingIdempotencyKey;
  DateTime? _pendingObservedAt;
  bool _submitting = false;
  ObservationDraft? _draft;
  int _formGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadDraftForStation();
  }

  @override
  void didUpdateWidget(covariant HourlyObservationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stationId != widget.stationId) {
      // Station scope changed: drop in-flight idempotency and reload drafts.
      _pendingPayloadFingerprint = null;
      _pendingIdempotencyKey = null;
      _pendingObservedAt = null;
      _submitting = false;
      _loadDraftForStation(resetForm: true);
    }
  }

  void _loadDraftForStation({bool resetForm = false}) {
    _draft = ObservationDraftStore.instance.get(widget.stationId, _formType);
    if (resetForm) {
      _formGeneration++;
    }
  }

  void _persistDraft(Map<String, Object?> values) {
    ObservationDraftStore.instance.save(
      stationId: widget.stationId,
      formType: _formType,
      values: values,
    );
    if (mounted) {
      setState(() {
        _draft =
            ObservationDraftStore.instance.get(widget.stationId, _formType);
      });
    }
  }

  Future<void> _discardDraft() async {
    final confirmed = await ObservationDraftUi.confirmDiscard(context);
    if (!confirmed || !mounted) return;
    ObservationDraftStore.instance.clear(widget.stationId, _formType);
    setState(() {
      _draft = null;
      _formGeneration++;
    });
    ObservationDraftUi.showDiscardedSnack(context);
  }

  Widget? _draftBanner() => ObservationDraftUi.banner(_draft);

  Future<void> _submit(Map<String, Object?> values) async {
    if (_submitting) return;

    // Bind the operation to the station/form generation that initiated it.
    // A late validation or submit response must never mutate the next station.
    final stationId = widget.stationId;
    final generation = _formGeneration;
    final messenger = ScaffoldMessenger.of(context);
    final payload = values;
    setState(() => _submitting = true);
    try {
      final validation = await widget.api.validateObservation(
        observationType: _formType,
        values: payload,
      );

      if (!mounted ||
          generation != _formGeneration ||
          stationId != widget.stationId) {
        return;
      }

      if (!validation.isValid) {
        final message = validation.issues.isEmpty
            ? 'رفض الخادم بيانات الرصد الساعي.'
            : validation.issues.first.message;
        messenger.showSnackBar(SnackBar(content: Text(message)));
        return;
      }

      final fingerprint = jsonEncode(payload);
      if (_pendingPayloadFingerprint != fingerprint ||
          _pendingIdempotencyKey == null) {
        _pendingPayloadFingerprint = fingerprint;
        _pendingIdempotencyKey = <String>[
          _formType,
          stationId,
          DateTime.now().toUtc().microsecondsSinceEpoch.toString(),
        ].join('-');
        _pendingObservedAt = DateTime.now().toUtc();
      }

      final idempotencyKey = _pendingIdempotencyKey!;
      final observedAt = _pendingObservedAt!;

      await widget.api.submitObservation(
        stationId: stationId,
        idempotencyKey: idempotencyKey,
        observationType: _formType,
        observedAt: observedAt,
        payload: payload,
        submit: true,
      );

      if (!mounted ||
          generation != _formGeneration ||
          stationId != widget.stationId) {
        return;
      }

      _pendingPayloadFingerprint = null;
      _pendingIdempotencyKey = null;
      _pendingObservedAt = null;
      ObservationDraftStore.instance.clear(stationId, _formType);
      setState(() {
        _draft = null;
        _formGeneration++;
        _submitting = false;
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('أُرسلت الرصدة الساعية إلى الخادم. يمكنك متابعتها من تبويب المراجعة.')),
      );
    } on MetraApiException catch (error) {
      if (mounted &&
          generation == _formGeneration &&
          stationId == widget.stationId) {
        messenger.showSnackBar(
          SnackBar(content: Text(MetraErrorPresenter.submitMessage(error))),
        );
      }
    } catch (error) {
      if (mounted &&
          generation == _formGeneration &&
          stationId == widget.stationId) {
        messenger.showSnackBar(
          SnackBar(content: Text(MetraErrorPresenter.messageFor(error))),
        );
      }
    } finally {
      if (mounted &&
          generation == _formGeneration &&
          stationId == widget.stationId &&
          _submitting) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MetraObservationForm(
      key: ValueKey('hourly-form-${widget.stationId}-$_formGeneration'),
      title: 'الرصد الساعي',
      fields: ObservationFieldCatalogs.hourly,
      initialValues: _draft?.values ?? const {},
      onSubmit: _submit,
      onValuesChanged: _persistDraft,
      draftBanner: _draftBanner(),
      secondaryActionLabel:
          _draft != null && !_draft!.isEmpty ? ObservationDraftUi.discardActionLabel : null,
      onSecondaryAction:
          _draft != null && !_draft!.isEmpty ? _discardDraft : null,
      submitLabel: _submitting
          ? 'جارٍ الإرسال...'
          : 'التحقق وإرسال الرصد الساعي',
      embedded: true,
    );
  }
}
