import 'package:material_ui/material_ui.dart';

enum MetraFieldKind {
  text,
  integer,
  decimal,
  choice,
  boolean,
  date,
  time,
  datetime,
  phone,
  file,
  multiline,
}

/// A field definition must come from an approved METRA form catalogue.
/// Bounds are enforced only when their source is documented.
class MetraObservationField {
  const MetraObservationField({
    required this.id,
    required this.label,
    this.catalogId,
    this.kind = MetraFieldKind.text,
    this.required = false,
    this.unit,
    this.minimum,
    this.maximum,
    this.maxLength = 500,
    this.choices = const [],
  }) : assert(minimum == null || maximum == null || minimum <= maximum);

  final String id;
  final String label;
  final String? catalogId;
  final MetraFieldKind kind;
  final bool required;
  final String? unit;
  final num? minimum;
  final num? maximum;
  final int maxLength;
  final List<String> choices;
}

/// Reusable RTL entry form. The host supplies approved fields and owns
/// persistence; this component never writes directly to Supabase or a database.
class MetraObservationForm extends StatefulWidget {
  const MetraObservationForm({
    super.key,
    required this.title,
    required this.fields,
    required this.onSubmit,
    this.initialValues = const {},
    this.submitLabel = 'حفظ وإرسال',
    this.onValuesChanged,
    this.draftBanner,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  final String title;
  final List<MetraObservationField> fields;
  final Map<String, Object?> initialValues;
  final Future<void> Function(Map<String, Object?> values) onSubmit;
  final String submitLabel;

  /// Fired whenever the user changes a value (for local draft save).
  final void Function(Map<String, Object?> values)? onValuesChanged;

  /// Optional banner above fields (e.g. local draft restored notice).
  final Widget? draftBanner;

  /// Optional secondary action (e.g. discard local draft).
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  @override
  State<MetraObservationForm> createState() => _MetraObservationFormState();
}
