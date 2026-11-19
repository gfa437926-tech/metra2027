import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import '../../core/api/metra_api_client.dart';
import '../../core/errors/metra_error_presenter.dart';
import '../../core/catalog/phenomenon_field_catalog.dart';
import '../../core/drafts/observation_draft_store.dart';
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

  void _discardDraft() {
    ObservationDraftStore.instance.clear(widget.stationId, _formType);
    setState(() {
      _draft = null;
      _formGeneration++;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم تجاهل المسودة المحلية')),
    );
  }

  Widget? _draftBanner() {
    if (_draft == null || _draft!.isEmpty) return null;
    final local = _draft!.savedAt.toLocal();
    final stamp =
        '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    return Material(
      color: const Color(0xFFE8F4FF),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          children: [
            const Icon(Icons.edit_note, color: Color(0xFF087CF0)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'مسودة محلية فقط — لم تُرسل إلى الخادم · حُفظت $stamp',
                style: const TextStyle(fontSize: 12, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit(Map<String, Object?> values) async {
    if (_submitting) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _submitting = true);
    final normalized = _normalize(values);
    try {
      final validation = await widget.api.validateObservation(
        observationType: _formType,
        values: normalized,
      );
      if (!validation.isValid) {
        final message = validation.issues.isEmpty
            ? 'رفض الخادم بيانات بلاغ الظاهرة.'
            : validation.issues.first.message;
        messenger.showSnackBar(SnackBar(content: Text(message)));
        return;
      }

      final fingerprint = jsonEncode(normalized);
      if (_pendingPayloadFingerprint != fingerprint ||
          _pendingIdempotencyKey == null) {
        _pendingPayloadFingerprint = fingerprint;
        _pendingIdempotencyKey = <String>[
          _formType,
          widget.stationId,
          DateTime.now().toUtc().microsecondsSinceEpoch.toString(),
        ].join('-');
        _pendingObservedAt = DateTime.now().toUtc();
      }

      await widget.api.submitObservation(
        stationId: widget.stationId,
        idempotencyKey: _pendingIdempotencyKey!,
        observationType: _formType,
        observedAt: _pendingObservedAt!,
        payload: normalized,
        submit: true,
      );
      _pendingPayloadFingerprint = null;
      _pendingIdempotencyKey = null;
      _pendingObservedAt = null;
      ObservationDraftStore.instance.clear(widget.stationId, _formType);
      if (mounted) {
        setState(() {
          _draft = null;
          _formGeneration++;
        });
      }
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'أُرسل بلاغ الظاهرة إلى الخادم. يمكنك متابعته من تبويب المراجعة.',
          ),
        ),
      );
    } on MetraApiException catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(MetraErrorPresenter.submitMessage(error))),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(MetraErrorPresenter.messageFor(error))),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
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
          _draft != null && !_draft!.isEmpty ? 'تجاهل المسودة المحلية' : null,
      onSecondaryAction:
          _draft != null && !_draft!.isEmpty ? _discardDraft : null,
      submitLabel: _submitting
          ? 'جارٍ الإرسال...'
          : 'التحقق وإرسال بلاغ الظاهرة',
      embedded: true,
    );
  }
}
