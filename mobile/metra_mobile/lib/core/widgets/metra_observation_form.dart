import 'package:flutter/material.dart';

enum MetraFieldKind { text, integer, decimal, choice }

/// A field definition must come from an approved METRA form catalogue.
/// Bounds are enforced for numeric fields; this widget does not invent them.
class MetraObservationField {
  const MetraObservationField({
    required this.id,
    required this.label,
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
  });

  final String title;
  final List<MetraObservationField> fields;
  final Map<String, Object?> initialValues;
  final Future<void> Function(Map<String, Object?> values) onSubmit;
  final String submitLabel;

  @override
  State<MetraObservationForm> createState() => _MetraObservationFormState();
}

class _MetraObservationFormState extends State<MetraObservationForm> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, String?> _choices = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    for (final field in widget.fields) {
      final initial = widget.initialValues[field.id];
      if (field.kind == MetraFieldKind.choice) {
        _choices[field.id] = initial?.toString();
      } else {
        _controllers[field.id] = TextEditingController(
          text: initial?.toString() ?? '',
        );
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _validate(MetraObservationField field, String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return field.required ? 'هذا الحقل مطلوب' : null;
    if (field.kind == MetraFieldKind.integer ||
        field.kind == MetraFieldKind.decimal) {
      final parsed = field.kind == MetraFieldKind.integer
          ? int.tryParse(value)
          : num.tryParse(value);
      if (parsed == null) return 'أدخل قيمة رقمية صحيحة';
      if (field.kind == MetraFieldKind.integer && !RegExp(r'^-?\\d+$').hasMatch(value)) {
        return 'أدخل عدداً صحيحاً دون كسور';
      }
      if (field.minimum != null && parsed < field.minimum!) {
        return 'القيمة أقل من الحد الأدنى (${field.minimum})';
      }
      if (field.maximum != null && parsed > field.maximum!) {
        return 'القيمة أكبر من الحد الأعلى (${field.maximum})';
      }
    }
    if (value.length > field.maxLength) {
      return 'الحد الأقصى ${field.maxLength} محرف';
    }
    return null;
  }

  Object? _typedValue(MetraObservationField field) {
    if (field.kind == MetraFieldKind.choice) return _choices[field.id];
    final value = _controllers[field.id]!.text.trim();
    if (value.isEmpty) return null;
    if (field.kind == MetraFieldKind.integer) return int.parse(value);
    if (field.kind == MetraFieldKind.decimal) return num.parse(value);
    return value;
  }

  Future<void> _submit() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    final values = <String, Object?>{};
    for (final field in widget.fields) {
      values[field.id] = _typedValue(field);
    }
    setState(() => _saving = true);
    try {
      await widget.onSubmit(values);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final field in widget.fields) ...[
              if (field.kind == MetraFieldKind.choice)
                DropdownButtonFormField<String>(
                  initialValue: _choices[field.id],
                  decoration: InputDecoration(
                    labelText: field.label,
                    border: const OutlineInputBorder(),
                  ),
                  items: field.choices
                      .map((choice) => DropdownMenuItem(
                            value: choice,
                            child: Text(choice),
                          ))
                      .toList(),
                  validator: (value) => field.required && value == null
                      ? 'يرجى اختيار قيمة'
                      : null,
                  onChanged: (value) => setState(() => _choices[field.id] = value),
                )
              else
                TextFormField(
                  controller: _controllers[field.id],
                  keyboardType: switch (field.kind) {
                    MetraFieldKind.integer => TextInputType.number,
                    MetraFieldKind.decimal => const TextInputType.numberWithOptions(decimal: true, signed: true),
                    _ => TextInputType.text,
                  },
                  maxLength: field.maxLength,
                  decoration: InputDecoration(
                    labelText: field.label,
                    suffixText: field.unit,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) => _validate(field, value),
                ),
              const SizedBox(height: 14),
            ],
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send),
              label: Text(_saving ? 'جارٍ الحفظ...' : widget.submitLabel),
            ),
          ],
        ),
      ),
    ),
  );
}
