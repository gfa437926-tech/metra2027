import 'package:flutter/material.dart';
import '../../core/api/metra_api_client.dart';
import 'observation_field_labels.dart';

/// Dialog that shows the reviewer note and editable payload fields, then
/// returns the corrected payload map (or null if cancelled).
Future<Map<String, String>?> showReturnedObservationEditor({
  required BuildContext context,
  required ObservationQueueItem item,
}) {
  return showDialog<Map<String, String>>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => _ReturnedObservationEditorDialog(item: item),
  );
}

class _ReturnedObservationEditorDialog extends StatefulWidget {
  const _ReturnedObservationEditorDialog({required this.item});
  final ObservationQueueItem item;

  @override
  State<_ReturnedObservationEditorDialog> createState() =>
      _ReturnedObservationEditorDialogState();
}

class _ReturnedObservationEditorDialogState
    extends State<_ReturnedObservationEditorDialog> {
  late final List<EditableObservationField> _fields;

  @override
  void initState() {
    super.initState();
    _fields = buildEditableFields(widget.item.payload);
  }

  @override
  void dispose() {
    for (final field in _fields) {
      field.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final note = widget.item.reviewNote?.trim();
    return AlertDialog(
      title: const Text('تصحيح النشرة المُرجَعة'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: note == null || note.isEmpty
                      ? const Color(0xFFF8FAFC)
                      : const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: note == null || note.isEmpty
                        ? const Color(0xFFE2E8F0)
                        : const Color(0xFFFDBA74),
                  ),
                ),
                child: Text(
                  note == null || note.isEmpty
                      ? 'لا توجد ملاحظة مكتوبة من المراجع.'
                      : 'ملاحظة المراجع: $note',
                  style: TextStyle(
                    color: note == null || note.isEmpty
                        ? const Color(0xFF64748B)
                        : const Color(0xFF9A3412),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_fields.isEmpty)
                const Text('لا توجد حقول قابلة للتحرير في حمولة هذه النشرة.')
              else
                ..._fields.map(
                  (field) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TextField(
                      controller: field.controller,
                      decoration: InputDecoration(
                        labelText: field.label == field.key
                            ? field.key
                            : '${field.label} (${field.key})',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _fields.isEmpty
              ? null
              : () => Navigator.pop(context, fieldsToPayload(_fields)),
          child: const Text('حفظ وإعادة التقديم'),
        ),
      ],
    );
  }
}
