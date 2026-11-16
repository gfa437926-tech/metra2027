import 'package:material_ui/material_ui.dart';

import '../../core/widgets/metra_observation_form.dart';

/// Interactive catalogue form for forms without an approved persistence API.
/// Validates locally and never claims to save or submit to the server.
class CatalogObservationScreen extends StatelessWidget {
  const CatalogObservationScreen({
    super.key,
    required this.title,
    required this.fields,
    this.formCode,
  });

  final String title;
  final List<MetraObservationField> fields;

  /// Optional stable code for documentation (e.g. agricultural).
  final String? formCode;

  int get _requiredCount => fields.where((f) => f.required).length;

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
                      Text(
                        'تحقق محلي فقط — لا حفظ على الخادم',
                        style: TextStyle(
                          color: const Color(0xFF9A6700),
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
            onSubmit: (_) async {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'اكتمل التحقق المحلي لـ«$title» (${fields.length} حقلاً). '
                    'الإرسال إلى الخادم غير متاح لعدم وجود عقد API معتمد.',
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
