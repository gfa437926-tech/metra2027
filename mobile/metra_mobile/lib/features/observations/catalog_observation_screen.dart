import 'package:material_ui/material_ui.dart';

import '../../core/catalog_integration/catalog_form_type.dart';
import '../../core/catalog_integration/catalog_observation_repository.dart';
import '../../core/catalog_integration/catalog_submission_state.dart';
import '../../core/catalog_integration/local_catalog_observation_repository.dart';
import '../../core/widgets/metra_observation_form.dart';

/// Interactive catalogue form for forms without an approved persistence API.
///
/// Validates locally through [CatalogObservationRepository] and never claims
/// to save or submit to the server.
class CatalogObservationScreen extends StatelessWidget {
  const CatalogObservationScreen({
    super.key,
    required this.title,
    required this.fields,
    this.formCode,
    this.stationId,
    this.formType,
    this.repository,
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

  int get _requiredCount => fields.where((f) => f.required).length;

  CatalogObservationRepository get _repo =>
      repository ?? LocalCatalogObservationRepository();

  Future<void> _onSubmit(
    BuildContext context,
    Map<String, Object?> values,
  ) async {
    if (!context.mounted) return;

    if (formType != null && stationId != null && stationId!.trim().isNotEmpty) {
      final result = await _repo.submitLocal(
        type: formType!,
        stationId: stationId!,
        values: values,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.messageAr)),
      );
      // Explicit guard: repository must never claim server persistence.
      assert(!result.claimsServerPersistence);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'اكتمل التحقق المحلي لـ«$title» (${fields.length} حقلاً). '
          'الإرسال إلى الخادم غير متاح لعدم وجود عقد API معتمد.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
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
                        'عدد الحقول: ${fields.length} · المطلوبة: $_requiredCount'
                        '${formCode == null ? '' : ' · الرمز: $formCode'}. '
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
            title: title,
            fields: fields,
            submitLabel: 'تحقق محلياً',
            onSubmit: (values) => _onSubmit(context, values),
          ),
        ),
      ],
    );
  }
}
