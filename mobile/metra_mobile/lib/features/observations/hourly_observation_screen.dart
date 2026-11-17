import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import '../../core/api/metra_api_client.dart';
import '../../core/errors/metra_error_presenter.dart';
import '../../core/catalog/observation_field_catalogs.dart';
import '../../core/drafts/observation_draft_store.dart';
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
  State<HourlyObservationScreen> createState() => _HourlyObservationScreenState();
}

class _HourlyObservationScreenState extends State<HourlyObservationScreen> {
  static const _formType = 'hourly';
  ObservationDraft? _draft;
  int _formGeneration = 0;
  String? _pendingIdempotencyKey;
  String? _pendingPayloadFingerprint;
  DateTime? _pendingObservedAt;

  @override
  void initState() {
    super.initState();
    _draft = ObservationDraftStore.instance.get(widget.stationId, _formType);
  }

  void _persistDraft(Map<String, Object?> values) {
    ObservationDraftStore.instance.save(
      stationId: widget.stationId,
      formType: _formType,
      values: values,
    );
    _draft = ObservationDraftStore.instance.get(widget.stationId, _formType);
  }

  void _discardDraft() {
    ObservationDraftStore.instance.clear(widget.stationId, _formType);
    setState(() {
      _draft = null;
      _formGeneration++;
      _pendingIdempotencyKey = null;
      _pendingPayloadFingerprint = null;
      _pendingObservedAt = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم تجاهل المسودة المحلية')),
    );
  }

  Widget? _draftBanner() {
    final draft = _draft;
    if (draft == null || draft.isEmpty) return null;
    final stamp = draft.savedAt.toLocal().toString().split('.').first;
    return Material(
      color: const Color(0xFFE8F1FF),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          children: [
            const Icon(Icons.history, color: Color(0xFF0B3D91)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'مسودة محلية فقط — لم تُرسل إلى الخادم · حُفظت $stamp',
                style: const TextStyle(fontSize: 12, height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit(Map<String, Object?> values) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final validation = await widget.api.validateObservation(
        observationType: _formType,
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
        payload: values,
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
            'أُرسلت الرصدة الساعية إلى الخادم. يمكنك متابعتها من تبويب المراجعة.',
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return MetraObservationForm(
      key: ValueKey('hourly-form-$_formGeneration'),
      title: 'الرصد الساعي',
      fields: ObservationFieldCatalogs.hourly,
      initialValues: _draft?.values ?? const {},
      onSubmit: _submit,
      onValuesChanged: _persistDraft,
      draftBanner: _draftBanner(),
      secondaryActionLabel:
          _draft != null && !_draft!.isEmpty ? 'تجاهل المسودة المحلية' : null,
      onSecondaryAction:
          _draft != null && !_draft!.isEmpty ? _discardDraft : null,
      submitLabel: 'التحقق وإرسال الرصد الساعي',
    );
  }
}
