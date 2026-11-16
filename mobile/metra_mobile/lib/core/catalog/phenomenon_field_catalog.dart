import '../widgets/metra_observation_form.dart';

/// Fields aligned with backend WeatherPhenomenonValidator / phenomena validate API.
/// Not part of the PR #53 174-row matrix; ids match domain request properties.
class PhenomenonFieldCatalog {
  const PhenomenonFieldCatalog._();

  static const List<MetraObservationField> fields = [
    MetraObservationField(
      catalogId: 'FLD-PHENOMENON-001',
      id: 'phenomenonType',
      label: 'نوع الظاهرة الجوية',
      kind: MetraFieldKind.text,
      required: true,
      maxLength: 64,
    ),
    MetraObservationField(
      catalogId: 'FLD-PHENOMENON-002',
      id: 'phenomenonDate',
      label: 'تاريخ الظاهرة',
      kind: MetraFieldKind.date,
      required: true,
    ),
    MetraObservationField(
      catalogId: 'FLD-PHENOMENON-003',
      id: 'startTime',
      label: 'وقت البدء (UTC)',
      kind: MetraFieldKind.time,
      required: true,
      unit: 'HH:mm:ss',
    ),
    MetraObservationField(
      catalogId: 'FLD-PHENOMENON-004',
      id: 'endTime',
      label: 'وقت الانتهاء (UTC) — فارغ إن كانت مستمرة',
      kind: MetraFieldKind.time,
      unit: 'HH:mm:ss',
    ),
    MetraObservationField(
      catalogId: 'FLD-PHENOMENON-005',
      id: 'generalNotes',
      label: 'ملاحظات',
      kind: MetraFieldKind.multiline,
      maxLength: 2000,
    ),
    MetraObservationField(
      catalogId: 'FLD-PHENOMENON-006',
      id: 'responsibilityAgreement',
      label: 'أقر بصحة بيانات بلاغ الظاهرة',
      kind: MetraFieldKind.boolean,
      required: true,
    ),
  ];
}
