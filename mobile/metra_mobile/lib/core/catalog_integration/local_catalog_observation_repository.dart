import '../catalog/observation_field_catalogs.dart';
import '../drafts/observation_draft_store.dart';
import '../widgets/metra_observation_form.dart';
import 'catalog_form_type.dart';
import 'catalog_observation_repository.dart';
import 'catalog_submission_state.dart';
import 'rainfall_soil_local_rules.dart';

/// Local-only catalogue repository.
///
/// - Validates required fields and basic numeric shapes.
/// - Persists session drafts via [ObservationDraftStore] (no secrets).
/// - Never calls the network and never invents API routes.
class LocalCatalogObservationRepository
    implements CatalogObservationRepository {
  LocalCatalogObservationRepository({ObservationDraftStore? draftStore})
    : _drafts = draftStore ?? ObservationDraftStore.instance;

  final ObservationDraftStore _drafts;

  @override
  List<MetraObservationField> fieldsFor(CatalogFormType type) {
    return switch (type) {
      CatalogFormType.agricultural => ObservationFieldCatalogs.agricultural,
      CatalogFormType.hourlyClimate => ObservationFieldCatalogs.hourlyclimate,
      CatalogFormType.rainfall => ObservationFieldCatalogs.rainfall,
      CatalogFormType.soil => ObservationFieldCatalogs.soil,
      CatalogFormType.faultEquipment => ObservationFieldCatalogs.faultequipment,
      CatalogFormType.faultTelecom => ObservationFieldCatalogs.faulttelecom,
      CatalogFormType.faultIt => ObservationFieldCatalogs.faultit,
    };
  }

  @override
  Future<CatalogSubmissionResult> submitLocal({
    required CatalogFormType type,
    required String stationId,
    required Map<String, Object?> values,
  }) async {
    final trimmedStation = stationId.trim();
    if (trimmedStation.isEmpty) {
      return const CatalogSubmissionResult(
        phase: CatalogSubmissionPhase.failed,
        messageAr: 'معرف المحطة غير صالح.',
      );
    }

    final fields = fieldsFor(type);
    final errors = <String, String>{};

    // Domain-specific local rules first (rainfall/soil): do not treat blank
    // optional amounts as zero; require date + agreement.
    if (type == CatalogFormType.rainfall) {
      errors.addAll(RainfallSoilLocalRules.validateRainfall(values));
    } else if (type == CatalogFormType.soil) {
      errors.addAll(RainfallSoilLocalRules.validateSoil(values));
    } else if (values.containsKey('observationDate')) {
      // Shared calendar + not-future rule for other catalogue forms that use the field.
      final date = values['observationDate']?.toString().trim() ?? '';
      if (date.isNotEmpty) {
        if (!RainfallSoilLocalRules.isValidObservationDate(date)) {
          errors['observationDate'] = 'أدخل تاريخاً صالحاً بصيغة YYYY-MM-DD';
        } else if (RainfallSoilLocalRules.isFutureObservationDate(date)) {
          errors['observationDate'] = 'لا يُقبل تاريخ رصد في المستقبل';
        }
      }
    }

    for (final field in fields) {
      if (errors.containsKey(field.id)) continue;
      final raw = values[field.id];
      if (field.kind == MetraFieldKind.boolean) {
        if (field.required && raw != true) {
          errors[field.id] = 'هذا الحقل مطلوب';
        }
        continue;
      }
      if (field.kind == MetraFieldKind.choice) {
        final text = raw?.toString().trim() ?? '';
        if (field.required && text.isEmpty) {
          errors[field.id] = 'هذا الحقل مطلوب';
        } else if (text.isNotEmpty &&
            field.choices.isNotEmpty &&
            !field.choices.contains(text)) {
          errors[field.id] = 'قيمة غير معتمدة في القائمة';
        }
        continue;
      }

      final text = raw?.toString().trim() ?? '';
      if (field.required && text.isEmpty) {
        errors[field.id] = 'هذا الحقل مطلوب';
        continue;
      }
      if (text.isEmpty) continue;

      if (field.kind == MetraFieldKind.integer) {
        final parsed = int.tryParse(text);
        if (parsed == null) {
          errors[field.id] = 'أدخل قيمة رقمية صحيحة';
        } else if (field.minimum != null && parsed < field.minimum!) {
          errors[field.id] = 'القيمة أقل من الحد الأدنى (${field.minimum})';
        } else if (field.maximum != null && parsed > field.maximum!) {
          errors[field.id] = 'القيمة أكبر من الحد الأعلى (${field.maximum})';
        }
      } else if (field.kind == MetraFieldKind.decimal) {
        final parsed = num.tryParse(text);
        if (parsed == null || !parsed.isFinite) {
          errors[field.id] = 'أدخل رقماً منتهياً وصالحاً';
        } else if (field.minimum != null && parsed < field.minimum!) {
          errors[field.id] = 'القيمة أقل من الحد الأدنى (${field.minimum})';
        } else if (field.maximum != null && parsed > field.maximum!) {
          errors[field.id] = 'القيمة أكبر من الحد الأعلى (${field.maximum})';
        }
      }
    }

    if (errors.isNotEmpty) {
      _drafts.save(
        stationId: trimmedStation,
        formType: type.code,
        values: values,
      );
      final first = errors.entries.first;
      return CatalogSubmissionResult(
        phase: CatalogSubmissionPhase.failed,
        messageAr:
            'تحقق من الحقول قبل المتابعة (${errors.length}): ${first.value}',
        values: values,
        validationErrors: errors,
      );
    }

    // Validated values may be stored on-device as local records by the UI.
    // Still no server persistence. Draft retention is owned by the screen.
    return CatalogSubmissionResult(
      phase: CatalogSubmissionPhase.localAccepted,
      messageAr:
          'اكتمل التحقق المحلي لـ«${type.arabicTitle}». السجل محلي على الجهاز فقط — لا إرسال للخادم.',
      values: Map<String, Object?>.from(values),
    );
  }
}
