import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import '../../core/api/metra_api_client.dart';
import '../../core/errors/metra_error_presenter.dart';
import '../../core/catalog/phenomenon_field_catalog.dart';
import '../../core/drafts/observation_draft_store.dart';
import '../../core/drafts/observation_draft_ui.dart';
import '../../core/widgets/metra_observation_form.dart';

/// Weather phenomenon report bound to WeatherPhenomenonValidator contract.
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
  static const _formType = 'phenomenon';

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
  void didUpdateWidget(covariant PhenomenonObservationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stationId != widget.stationId) {
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

  /// Form time pickers yield HH:mm; domain contract requires HH:mm:ss UTC.
  Map<String, Object?> _normalize(Map<String, Object?> values) {
    final next = Map<String, Object?>.from(values);
    for (final key in ['startTime', 'endTime']) {
      final raw = next[key]?.toString().trim();
      if (raw == null || raw.isEmpty) continue;
      if (RegExp(r'^\d{2}:\d{2}$').hasMatch(raw)) {
        next[key] = '$raw:00';
      }
    }
    return next;
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
    final normalized = _normalize(values);
    final payload = normalized;
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
            ? 'رفض الخادم بيانات بلاغ الظاهرة.'
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
        const SnackBar(content: Text('أُرسل بلاغ الظاهرة إلى الخادم. يمكنك متابعته من تبويب المراجعة.')),
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
      key: ValueKey('phenomenon-form-${widget.stationId}-$_formGeneration'),
      title: 'بلاغ ظاهرة جوية',
      fields: PhenomenonFieldCatalog.fields,
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
          : 'التحقق وإرسال بلاغ الظاهرة',
      embedded: true,
    );
  }
}
