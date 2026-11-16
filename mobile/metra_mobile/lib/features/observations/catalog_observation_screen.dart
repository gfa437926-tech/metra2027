import 'package:material_ui/material_ui.dart';

import '../../core/widgets/metra_observation_form.dart';

/// Interactive catalogue form for forms without an approved persistence API.
/// It validates locally but deliberately does not claim to save or submit.
class CatalogObservationScreen extends StatelessWidget {
  const CatalogObservationScreen({
    super.key,
    required this.title,
    required this.fields,
  });

  final String title;
  final List<MetraObservationField> fields;

  @override
  Widget build(BuildContext context) {
    return MetraObservationForm(
      title: title,
      fields: fields,
      submitLabel: 'تحقق محلياً',
      onSubmit: (_) async {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'اكتمل التحقق المحلي. الحفظ والإرسال غير متاحين لهذا النموذج لعدم وجود API معتمد.',
            ),
          ),
        );
      },
    );
  }
}
