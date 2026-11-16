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
  final Map<String, bool> _booleans = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    for (final field in widget.fields) {
      final initial = widget.initialValues[field.id];
      if (field.kind == MetraFieldKind.choice && field.choices.isNotEmpty) {
        _choices[field.id] = initial?.toString();
      } else if (field.kind == MetraFieldKind.boolean) {
        _booleans[field.id] = initial == true;
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
      if (parsed is double && !parsed.isFinite) {
        return 'أدخل رقماً منتهياً وصالحاً';
      }
      if (field.kind == MetraFieldKind.integer &&
          !RegExp(r'^-?\d+$').hasMatch(value)) {
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
    if (field.kind == MetraFieldKind.file) return null;
    if (field.kind == MetraFieldKind.boolean) {
      return _booleans[field.id] ?? false;
    }
    if (field.kind == MetraFieldKind.choice && field.choices.isNotEmpty) {
      return _choices[field.id];
    }
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
      if (field.kind == MetraFieldKind.boolean &&
          field.required &&
          !(_booleans[field.id] ?? false)) {
        return;
      }
      if (field.kind == MetraFieldKind.choice &&
          field.choices.isNotEmpty &&
          field.required &&
          _choices[field.id] == null) {
        return;
      }
      values[field.id] = _typedValue(field);
    }
    setState(() => _saving = true);
    try {
      await widget.onSubmit(values);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickFieldValue(MetraObservationField field) async {
    final controller = _controllers[field.id];
    if (controller == null) return;
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    final current = DateTime.tryParse(controller.text) ?? DateTime.now();

    if (field.kind == MetraFieldKind.date || field.kind == MetraFieldKind.datetime) {
      final date = await showDatePicker(
        context: context,
        initialDate: current,
        firstDate: DateTime(1900),
        lastDate: DateTime(2100),
      );
      if (date == null || !mounted) return;
      if (field.kind == MetraFieldKind.date) {
        setState(() {
          controller.text = <String>[
            date.year.toString().padLeft(4, '0'),
            twoDigits(date.month),
            twoDigits(date.day),
          ].join('-');
        });
        return;
      }
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(current),
      );
      if (time == null || !mounted) return;
      setState(() {
        controller.text = DateTime(date.year, date.month, date.day, time.hour, time.minute).toIso8601String();
      });
      return;
    }

    if (field.kind == MetraFieldKind.time) {
      final parts = controller.text.split(':');
      final initial = TimeOfDay(
        hour: int.tryParse(parts.first) ?? current.hour,
        minute: parts.length > 1 ? int.tryParse(parts[1]) ?? current.minute : current.minute,
      );
      final time = await showTimePicker(context: context, initialTime: initial);
      if (time == null || !mounted) return;
      setState(() {
        controller.text = <String>[twoDigits(time.hour), twoDigits(time.minute)].join(':');
      });
    }
  }
  Widget _buildField(MetraObservationField field) {
    if (field.kind == MetraFieldKind.file) {
      return InputDecorator(
        decoration: InputDecoration(
          labelText: field.label,
          helperText: 'رفع الملفات غير متصل حتى اعتماد خدمة التخزين.',
          border: const OutlineInputBorder(),
        ),
        child: const Row(
          children: [Icon(Icons.attach_file), SizedBox(width: 8), Text('غير متاح حالياً')],
        ),
      );
    }
    if (field.kind == MetraFieldKind.boolean) {
      return FormField<bool>(
        initialValue: _booleans[field.id] ?? false,
        validator: (value) =>
            field.required && value != true ? 'هذا الإقرار مطلوب' : null,
        builder: (state) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: state.value ?? false,
              title: Text(field.label),
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: _saving
                  ? null
                  : (value) {
                      final next = value ?? false;
                      _booleans[field.id] = next;
                      state.didChange(next);
                    },
            ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 12),
                child: Text(
                  state.errorText!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    if (field.kind == MetraFieldKind.choice && field.choices.isNotEmpty) {
      return DropdownButtonFormField<String>(
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
        onChanged: _saving
            ? null
            : (value) => setState(() => _choices[field.id] = value),
      );
    }

    final usesPicker = field.kind == MetraFieldKind.date ||
        field.kind == MetraFieldKind.time || field.kind == MetraFieldKind.datetime;
    return TextFormField(
      controller: _controllers[field.id],
      readOnly: usesPicker,
      onTap: usesPicker ? () => _pickFieldValue(field) : null,
      keyboardType: switch (field.kind) {
        MetraFieldKind.integer => TextInputType.number,
        MetraFieldKind.decimal =>
          const TextInputType.numberWithOptions(decimal: true, signed: true),
        MetraFieldKind.date || MetraFieldKind.time || MetraFieldKind.datetime => TextInputType.datetime,
        MetraFieldKind.phone => TextInputType.phone,
        MetraFieldKind.multiline => TextInputType.multiline,
        _ => TextInputType.text,
      },
      minLines: field.kind == MetraFieldKind.multiline ? 3 : 1,
      maxLines: field.kind == MetraFieldKind.multiline ? 5 : 1,
      maxLength: field.maxLength,
      decoration: InputDecoration(
        labelText: field.label,
        suffixText: field.unit,
        helperText: field.kind == MetraFieldKind.choice && field.choices.isEmpty
            ? 'خيارات القائمة الرسمية غير متاحة؛ أدخل الرمز المعتمد فقط.'
            : null,
        border: const OutlineInputBorder(),
      ),
      validator: (value) => _validate(field, value),
    );
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
                  _buildField(field),
                  const SizedBox(height: 14),
                ],
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _saving ? null : _submit,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  label: Text(_saving ? 'جارٍ الحفظ...' : widget.submitLabel),
                ),
              ],
            ),
          ),
        ),
      );
}
