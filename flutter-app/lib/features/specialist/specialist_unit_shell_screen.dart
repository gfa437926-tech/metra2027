import 'package:flutter/material.dart';

/// Honest unbound shell for specialist meteorological units without approved aggregate APIs.
class SpecialistUnitShellScreen extends StatelessWidget {
  const SpecialistUnitShellScreen({
    super.key,
    required this.title,
    required this.unitCode,
    required this.description,
    this.requiredBeforeBinding = const <String>[],
    this.plannedFields = const <String>[],
  });

  final String title;
  final String unitCode;
  final String description;
  final List<String> requiredBeforeBinding;
  /// Design-only field names; inputs are disabled and never submitted.
  final List<String> plannedFields;

  static const _navy = Color(0xFF061B4A);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: _navy,
          foregroundColor: Colors.white,
          title: Text(title),
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              color: const Color(0xFFEEF6FF),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _navy)),
                    const SizedBox(height: 8),
                    Text(description, style: const TextStyle(height: 1.55)),
                    const SizedBox(height: 12),
                    Text('رمز الوحدة: $unitCode', style: const TextStyle(fontFamily: 'monospace')),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'لن تُعرض مجاميع أو سلاسل رصد على أنها بيانات حقيقية حتى يعتمد عقد الحقول وواجهة API '
              'ومصدر البيانات. الأصفار أو القيم التجريبية ممنوعة هنا.',
              style: TextStyle(height: 1.5, color: Color(0xFF475569)),
            ),
            if (requiredBeforeBinding.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('متطلبات الربط:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...requiredBeforeBinding.map(
                (item) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.radio_button_unchecked, size: 18),
                  title: Text(item),
                ),
              ),
            ],
            if (plannedFields.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('حقول مخططة (معطّلة — لا إرسال):',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...plannedFields.map(
                (field) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextField(
                    enabled: false,
                    decoration: InputDecoration(
                      labelText: field,
                      border: const OutlineInputBorder(),
                      helperText: 'غير متاح حتى اعتماد API',
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
