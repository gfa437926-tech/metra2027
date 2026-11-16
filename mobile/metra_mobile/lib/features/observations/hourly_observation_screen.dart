import 'package:flutter/material_ui.dart';
import '../../core/api/metra_api_client.dart';
import '../../core/catalog/observation_field_catalogs.dart';
import '../../core/widgets/metra_observation_form.dart';

/// Catalog-driven hourly observation entry.
/// Submission uses the existing API contract; server FeatureGates may return 503.
class HourlyObservationScreen extends StatelessWidget {
  const HourlyObservationScreen({
    super.key,
    required this.api,
    required this.stationId,
  });

  final MetraApiClient api;
  final String stationId;

  Future<void> _submit(BuildContext context, Map<String, Object?> values) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final key =
          'hourly-${stationId}-${DateTime.now().toUtc().millisecondsSinceEpoch}';
      await api.submitObservation(
        stationId: stationId,
        idempotencyKey: key,
        observationType: 'hourly',
        observedAt: DateTime.now().toUtc(),
        payload: values,
        submit: true,
      );
      messenger.showSnackBar(
        const SnackBar(content: Text('أُرسلت الرصدة الساعية إلى الخادم')),
      );
    } on MetraApiException catch (e) {
      final msg = switch (e.statusCode) {
        503 => 'الإرسال غير متاح حالياً (بوابة أو خدمة مغلقة على الخادم).',
        401 => 'يلزم تسجيل الدخول من جديد.',
        403 => 'لا تملك صلاحية الإرسال لهذه المحطة.',
        _ => 'فشل الإرسال ($e.statusCode).',
      };
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
            content: Text('تعذر الإرسال. تحقق من الاتصال وأعد المحاولة.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MetraObservationForm(
      title: 'الرصد الساعي',
      fields: ObservationFieldCatalogs.hourly,
      onSubmit: (values) => _submit(context, values),
      submitLabel: 'إرسال الرصد الساعي',
    );
  }
}
