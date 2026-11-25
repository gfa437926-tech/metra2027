import 'package:material_ui/material_ui.dart';

enum MetraFieldKind {
  text,
  phone,
  multiline,
  integer,
  decimal,
  boolean,
  date,
  time,
  datetime,
  choice,
  file,
}

class MetraObservationField {
  const MetraObservationField({
    this.catalogId,
    required this.id,
    required this.label,
    this.kind = MetraFieldKind.text,
    this.required = false,
    this.unit,
    this.minimum,
    this.maximum,
    this.maxLength = 256,
    this.choices = const [],
  });

  final String? catalogId;
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
    this.onValuesChanged,
    this.draftBanner,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.embedded = false,
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

  /// When true (workspace tabs), skip nested [Scaffold]/[AppBar] and render
  /// an in-body title so the parent shell remains the only chrome.
  final bool embedded;

  @override
  State<MetraObservationForm> createState() => _MetraObservationFormState();
}

class _MetraObservationFormState extends State<MetraObservationForm> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, String?> _choices = {};
  final Map<String, bool> _booleans = {};
  bool _saving = false;

  static final RegExp _dateYmd = RegExp(r'^\d{4}-\d{2}-\d{2}$');
  static final RegExp _timeHm = RegExp(r'^\d{2}:\d{2}$');
  static final RegExp _timeHms = RegExp(r'^\d{2}:\d{2}:\d{2}$');

  @override
  void initState() {
    super.initState();
    for (final field in widget.fields) {
      final initial = widget.initialValues[field.id];
      if (field.kind == MetraFieldKind.choice && field.choices.isNotEmpty) {
        final candidate = initial?.toString();
        _choices[field.id] =
            candidate != null && field.choices.contains(candidate)
                ? candidate
                : null;
      } else if (field.kind == MetraFieldKind.boolean) {
        _booleans[field.id] = initial == true;
      } else {
        final controller = TextEditingController(
          text: initial?.toString() ?? '',
        );
        controller.addListener(_notifyValuesChanged);
        _controllers[field.id] = controller;
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.removeListener(_notifyValuesChanged);
      controller.dispose();
    }
    super.dispose();
  }

  Map<String, Object?> _collectValues() {
    final values = <String, Object?>{};
    for (final field in widget.fields) {
      values[field.id] = _typedValue(field);
    }
    return values;
  }

  void _notifyValuesChanged() {
    widget.onValuesChanged?.call(_collectValues());
  }

  bool _isValidCalendarDate(String value) {
    if (!_dateYmd.hasMatch(value)) return false;
    final parts = value.split('-');
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return false;
    if (month < 1 || month > 12 || day < 1 || day > 31) return false;
    try {
      final parsed = DateTime(year, month, day);
      return parsed.year == year && parsed.month == month && parsed.day == day;
    } catch (_) {
      return false;
    }
  }

  bool _isValidClockTime(String value) {
    final normalized =
        _timeHm.hasMatch(value) ? '$value:00' : value;
    if (!_timeHms.hasMatch(normalized)) return false;
    final parts = normalized.split(':');
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    final second = int.tryParse(parts[2]);
    if (hour == null || minute == null || second == null) return false;
    return hour >= 0 &&
        hour <= 23 &&
        minute >= 0 &&
        minute <= 59 &&
        second >= 0 &&
        second <= 59;
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
      if (!parsed.isFinite) {
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

    if (field.kind == MetraFieldKind.date && !_isValidCalendarDate(value)) {
      return 'التاريخ يجب أن يكون بالتنسيق yyyy-MM-dd';
    }

    if (field.kind == MetraFieldKind.time && !_isValidClockTime(value)) {
      return 'الوقت يجب أن يكون بالتنسيق HH:mm أو HH:mm:ss';
    }

    if (field.kind == MetraFieldKind.datetime) {
      // Accept ISO-like local stamps; server paths normalize to UTC separately.
      final parsed = DateTime.tryParse(value);
      if (parsed == null) {
        return 'أدخل تاريخاً ووقتاً صالحين';
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
      values[field.id] = _typedValue(field);
    }
    setState(() => _saving = true);
    try {
      await widget.onSubmit(values);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildField(MetraObservationField field) {
    if (field.kind == MetraFieldKind.file) {
      return const InputDecorator(
        decoration: InputDecoration(
          labelText: 'مرفق',
          border: OutlineInputBorder(),
        ),
        child: Row(
          children: [
            Icon(Icons.attach_file),
            SizedBox(width: 8),
            Text('رفع الملفات غير مفعّل في هذه النسخة'),
          ],
        ),
      );
    }
    if (field.kind == MetraFieldKind.boolean) {
      return FormField<bool>(
        initialValue: _booleans[field.id] ?? false,
        validator: (v) =>
            field.required && v != true ? 'هذا الحقل مطلوب' : null,
        builder: (state) {
          return InputDecorator(
            decoration: InputDecoration(
              labelText: field.label,
              errorText: state.errorText,
              border: const OutlineInputBorder(),
            ),
            child: SwitchListTile(
              contentPadding: const EdgeInsetsDirectional.only(start: 12),
              title: Text(field.label),
              value: state.value ?? false,
              onChanged: (v) {
                setState(() => _booleans[field.id] = v);
                state.didChange(v);
                _notifyValuesChanged();
              },
            ),
          );
        },
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
            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
            .toList(),
        onChanged: (v) {
          setState(() => _choices[field.id] = v);
          _notifyValuesChanged();
        },
        validator: (v) =>
            field.required && (v == null || v.isEmpty) ? 'هذا الحقل مطلوب' : null,
      );
    }
    return TextFormField(
      controller: _controllers[field.id],
      keyboardType: field.kind == MetraFieldKind.integer ||
              field.kind == MetraFieldKind.decimal
          ? const TextInputType.numberWithOptions(decimal: true, signed: true)
          : field.kind == MetraFieldKind.multiline
              ? TextInputType.multiline
              : field.kind == MetraFieldKind.phone
                  ? TextInputType.phone
                  : field.kind == MetraFieldKind.date ||
                          field.kind == MetraFieldKind.time ||
                          field.kind == MetraFieldKind.datetime
                      ? TextInputType.datetime
                      : TextInputType.text,
      maxLines: field.kind == MetraFieldKind.multiline ? 4 : 1,
      maxLength: field.maxLength,
      decoration: InputDecoration(
        labelText: field.label,
        suffixText: field.unit,
        hintText: field.kind == MetraFieldKind.date
            ? 'yyyy-MM-dd'
            : field.kind == MetraFieldKind.time
                ? (field.unit ?? 'HH:mm:ss')
                : null,
        border: const OutlineInputBorder(),
      ),
      validator: (raw) => _validate(field, raw),
      onChanged: (_) => _notifyValuesChanged(),
    );
  }

  Widget _formBody() {
    return Form(
      key: _formKey,
      // Submit stays outside the scrollable body so long catalogues do not
      // leave the action off-stage / unbuilt.
      child: Column(
        children: [
          if (widget.embedded)
            Material(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF061B4A),
                    ),
                  ),
                ),
              ),
            ),
          if (widget.draftBanner != null) widget.draftBanner!,
          Expanded(
            // SingleChildScrollView + Column keeps every FormField mounted
            // so required validators run even when the control is off-screen.
            // A lazy ListView would skip unbuilt required fields on submit.
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final field in widget.fields) ...[
                    _buildField(field),
                    const SizedBox(height: 14),
                  ],
                ],
              ),
            ),
          ),
          SafeArea(
            minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  button: true,
                  label: _saving ? 'جارٍ الإرسال' : widget.submitLabel,
                  enabled: !_saving,
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const Key('metra-observation-submit'),
                      onPressed: _saving ? null : _submit,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                      label: Text(
                        _saving ? 'جارٍ الإرسال...' : widget.submitLabel,
                      ),
                    ),
                  ),
                ),
                if (widget.secondaryActionLabel != null &&
                    widget.onSecondaryAction != null) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      key: const Key('metra-observation-discard-draft'),
                      onPressed: _saving ? null : widget.onSecondaryAction,
                      icon: const Icon(Icons.delete_outline),
                      label: Text(widget.secondaryActionLabel!),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = _formBody();
    return Directionality(
      textDirection: TextDirection.rtl,
      child: widget.embedded
          ? body
          : Scaffold(
              appBar: AppBar(title: Text(widget.title)),
              body: body,
            ),
    );
  }
}
