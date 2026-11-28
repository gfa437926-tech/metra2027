import 'package:material_ui/material_ui.dart';

import '../../core/catalog_integration/catalog_form_type.dart';
import '../../core/catalog_integration/catalog_observation_repository.dart';
import '../../core/catalog_integration/local_catalog_observation_repository.dart';
import '../../core/catalog_integration/local_catalog_record_store.dart';
import '../../core/drafts/observation_draft_store.dart';
import '../../core/drafts/observation_draft_ui.dart';
import '../../core/notifications/local_notification_store.dart';
import '../../core/widgets/metra_observation_form.dart';
import 'local_catalog_records_screen.dart';

/// Interactive catalogue form for forms without an approved persistence API.
///
/// Validates locally through [CatalogObservationRepository] and never claims
/// to save or submit to the server. Session drafts are station-scoped only.
class CatalogObservationScreen extends StatefulWidget {
  const CatalogObservationScreen({
    super.key,
    required this.title,
    required this.fields,
    this.formCode,
    this.stationId,
    this.formType,
    this.repository,
    this.existingRecordId,
    this.initialRecordValues,
  });

  final String title;
  final List<MetraObservationField> fields;

  /// Optional stable code for documentation (e.g. agricultural).
  final String? formCode;

  /// Station scope for session drafts. Drafts never cross stations.
  final String? stationId;

  /// When set, submit goes through the catalogue repository layer.
  final CatalogFormType? formType;

  final CatalogObservationRepository? repository;

  /// When set, successful local save updates this record id (no duplicate).
  final String? existingRecordId;

  /// Seed form values when editing an existing local record.
  final Map<String, Object?>? initialRecordValues;

  @override
  State<CatalogObservationScreen> createState() =>
      _CatalogObservationScreenState();
}

class _CatalogObservationScreenState extends State<CatalogObservationScreen> {
  ObservationDraft? _draft;
  int _formGeneration = 0;

  int get _requiredCount => widget.fields.where((f) => f.required).length;

  CatalogObservationRepository get _repo =>
      widget.repository ?? LocalCatalogObservationRepository();

  /// Draft key: prefer catalogue form type code, else formCode, else title slug.
  String? get _draftFormType {
    if (widget.formType != null) return widget.formType!.code;
    final code = widget.formCode?.trim();
    if (code != null && code.isNotEmpty) return code.toLowerCase();
    return null;
  }

  bool get _canDraft {
    final station = widget.stationId?.trim() ?? '';
    final type = _draftFormType;
    return station.isNotEmpty && type != null && type.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    _loadDraft();
  }

  @override
  void didUpdateWidget(covariant CatalogObservationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final stationChanged =
        oldWidget.stationId?.trim() != widget.stationId?.trim();
    final typeChanged =
        oldWidget.formType != widget.formType ||
        oldWidget.formCode != widget.formCode;
    if (stationChanged || typeChanged) {
      _loadDraft(resetForm: true);
    }
  }

  void _loadDraft({bool resetForm = false}) {
    if (!_canDraft) {
      _draft = null;
      if (resetForm) _formGeneration++;
      return;
    }
    _draft = ObservationDraftStore.instance.get(
      widget.stationId!,
      _draftFormType!,
    );
    if (resetForm) {
      _formGeneration++;
    }
  }

  void _persistDraft(Map<String, Object?> values) {
    if (!_canDraft) return;
    ObservationDraftStore.instance.save(
      stationId: widget.stationId!,
      formType: _draftFormType!,
      values: values,
    );
    if (!mounted) return;
    setState(() {
      _draft = ObservationDraftStore.instance.get(
        widget.stationId!,
        _draftFormType!,
      );
    });
  }

  Future<void> _discardDraft() async {
    if (!_canDraft) return;
    final confirmed = await ObservationDraftUi.confirmDiscard(context);
    if (!confirmed || !mounted) return;
    ObservationDraftStore.instance.clear(widget.stationId!, _draftFormType!);
    setState(() {
      _draft = null;
      _formGeneration++;
    });
    ObservationDraftUi.showDiscardedSnack(context);
  }

  Widget? _draftBanner() => ObservationDraftUi.banner(_draft);

  Future<void> _onSubmit(
    BuildContext context,
    Map<String, Object?> values,
  ) async {
    if (!context.mounted) return;

    if (widget.formType != null &&
        widget.stationId != null &&
        widget.stationId!.trim().isNotEmpty) {
      final accountAtStart =
          LocalCatalogRecordStore.instance.activeAccountKey;
      final result = await _repo.submitLocal(
        type: widget.formType!,
        stationId: widget.stationId!,
        values: values,
      );
      if (!context.mounted) return;
      // Explicit guard: repository must never claim server persistence.
      assert(!result.claimsServerPersistence);

      // Persist on-device for any successful local validation path.
      // awaitingApiContract still means "no server write" — records stay local-only.
      if (result.isSuccess) {
        // Pending save must not land on a different account after switch.
        if (LocalCatalogRecordStore.instance.activeAccountKey !=
            accountAtStart) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            const SnackBar(
              content: Text(
                'تغير الحساب أثناء الحفظ. لم يُكتب السجل تحت الحساب الجديد.',
              ),
            ),
          );
          return;
        }
        await LocalCatalogRecordStore.instance.ensureLoaded();
        final record = LocalCatalogRecordStore.instance.upsert(
          id: widget.existingRecordId,
          stationId: widget.stationId!,
          formType: widget.formType!.code,
          values: values,
          accountKey: accountAtStart,
        );
        LocalNotificationStore.instance.add(
          titleAr: 'سجل محلي جديد',
          bodyAr:
              'حُفظ «${widget.title}» محلياً على المحطة (لا إرسال للخادم).',
          category: widget.formType!.code.contains('fault')
              ? 'fault'
              : 'observation',
          sourceKey: record.id,
        );
        // Clear draft after successful local save to avoid re-submit confusion.
        if (_canDraft) {
          ObservationDraftStore.instance.clear(
            widget.stationId!,
            _draftFormType!,
          );
          if (mounted) {
            setState(() {
              _draft = null;
              _formGeneration++;
            });
          }
        }
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(
              '${result.messageAr} حُفظ السجل محلياً فقط.',
            ),
            action: SnackBarAction(
              label: 'السجلات',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => LocalCatalogRecordsScreen(
                      stationId: widget.stationId!,
                      formType: widget.formType!.code,
                      titleAr: widget.title,
                    ),
                  ),
                );
              },
            ),
          ),
        );
        return;
      }

      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(SnackBar(content: Text(result.messageAr)));
      return;
    }

    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          'اكتمل التحقق المحلي لـ«${widget.title}» (${widget.fields.length} حقلاً). '
          'الإرسال إلى الخادم غير متاح لعدم وجود عقد API معتمد.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        children: [
          Material(
            color: const Color(0xFFFFF7E8),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFF9A6700)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'تحقق محلي فقط — لا حفظ على الخادم',
                          style: TextStyle(
                            color: Color(0xFF9A6700),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'عدد الحقول: ${widget.fields.length} · المطلوبة: $_requiredCount'
                          '${widget.formCode == null ? '' : ' · الرمز: ${widget.formCode}'}. '
                          'الحفظ الإنتاجي يتطلب عقد API معتمداً وموافقة صريحة.',
                          style: const TextStyle(
                            color: Color(0xFF7C5E10),
                            height: 1.45,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: MetraObservationForm(
              key: ValueKey('catalog-form-$_formGeneration'),
              title: widget.title,
              fields: widget.fields,
              submitLabel: 'تحقق محلياً',
              initialValues: _draft?.values ??
                  widget.initialRecordValues ??
                  const {},
              onValuesChanged: _canDraft ? _persistDraft : null,
              draftBanner: _draftBanner(),
              secondaryActionLabel: _draft != null && !_draft!.isEmpty
                  ? ObservationDraftUi.discardActionLabel
                  : null,
              onSecondaryAction: _draft != null && !_draft!.isEmpty
                  ? _discardDraft
                  : null,
              onSubmit: (values) => _onSubmit(context, values),
              embedded: true,
            ),
          ),
        ],
      ),
    );
  }
}
