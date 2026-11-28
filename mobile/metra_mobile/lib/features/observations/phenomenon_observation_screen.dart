import 'package:material_ui/material_ui.dart';

import '../../core/api/metra_api_client.dart';
import '../../core/catalog/phenomenon_field_catalog.dart';
import '../../core/drafts/observation_draft_store.dart';
import '../../core/drafts/observation_draft_ui.dart';
import '../../core/observations/observation_submit_flow.dart';
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

  late final ObservationSubmitFlow _flow = ObservationSubmitFlow(
    api: widget.api,
  );
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
      _flow.resetPending();
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
        _draft = ObservationDraftStore.instance.get(
          widget.stationId,
          _formType,
        );
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

    final stationId = widget.stationId;
    final generation = _formGeneration;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _submitting = true);
    try {
      final outcome = await _flow.validateAndSubmit(
        formType: _formType,
        stationId: stationId,
        values: values,
        stillCurrent: () =>
            mounted &&
            stationId == widget.stationId &&
            generation == _formGeneration,
        successMessageAr:
            'أُرسل بلاغ الظاهرة إلى الخادم. يمكنك متابعته من تبويب المراجعة.',
        validationFallbackAr: 'رفض الخادم بيانات الظاهرة الجوية.',
      );

      if (!mounted ||
          generation != _formGeneration ||
          stationId != widget.stationId) {
        return;
      }

      if (outcome.clearedDraft) {
        setState(() {
          _draft = null;
          _formGeneration++;
        });
      }
      messenger.showSnackBar(SnackBar(content: Text(outcome.messageAr)));
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
      secondaryActionLabel: _draft != null && !_draft!.isEmpty
          ? ObservationDraftUi.discardActionLabel
          : null,
      onSecondaryAction: _draft != null && !_draft!.isEmpty
          ? _discardDraft
          : null,
      submitLabel: _submitting
          ? 'جارٍ الإرسال...'
          : 'التحقق وإرسال بلاغ الظاهرة',
      embedded: true,
    );
  }
}
