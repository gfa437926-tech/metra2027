import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import '../../core/api/metra_api_client.dart';
import '../../core/errors/metra_error_presenter.dart';
import '../../core/catalog/observation_field_catalogs.dart';
import '../../core/drafts/observation_draft_store.dart';
import '../../core/widgets/metra_observation_form.dart';

/// Daily observation entry bound to the approved .NET validation/submit API.
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
  static const _formType = 'daily';

  String? _pendingPayloadFingerprint;
  String? _pendingIdempotencyKey;
  DateTime? _pendingObservedAt;
  ObservationDraft? _draft;
  int _formGeneration = 0;

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
    final messenger = ScaffoldMessenger.of(context);
    try {
      final validation = await widget.api.validateObservation(
        observationType: _formType,
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
            'أُرسلت الرصدة اليومية إلى الخادم. يمكنك متابعتها من تبويب المراجعة.',
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
      key: ValueKey('daily-form-$_formGeneration'),
      title: 'الرصد اليومي',
      fields: ObservationFieldCatalogs.daily,
      initialValues: _draft?.values ?? const {},
      onSubmit: _submit,
      onValuesChanged: _persistDraft,
      draftBanner: _draftBanner(),
      secondaryActionLabel:
          _draft != null && !_draft!.isEmpty ? 'تجاهل المسودة المحلية' : null,
      onSecondaryAction:
          _draft != null && !_draft!.isEmpty ? _discardDraft : null,
      submitLabel: 'التحقق وإرسال الرصد اليومي',
    );
  }
}
