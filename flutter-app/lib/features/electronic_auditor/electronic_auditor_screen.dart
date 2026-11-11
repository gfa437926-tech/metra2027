import 'package:flutter/material.dart';

/// Scaffold only — Intelligent / Electronic audit workstation on mobile.
/// Spec: docs/requirements/METRA-AI-INTELLIGENT-AUDIT-SYSTEM-SPECIFICATION.md
/// No OCR, no chart digitization, no observation mutation in this revision.
class ElectronicAuditorScreen extends StatelessWidget {
  const ElectronicAuditorScreen({super.key});

  static const _navy = Color(0xFF061B4A);
  static const _blue = Color(0xFF087CF0);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: _navy,
          foregroundColor: Colors.white,
          title: const Text('التدقيق الإلكتروني'),
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              color: const Color(0xFFFFFBEB),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFF59E0B)),
              ),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'هذه شاشة هيكلية فقط. لا يتم رفع مخططات ولا استخراج منحنيات ولا مقارنة تلقائية '
                  'ولا تعديل النشرات الأصلية من هنا. المرجع: مواصفات منظومة التدقيق الذكي.',
                  style: TextStyle(height: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _tile(Icons.description_outlined, 'السجلات الورقية', 'رفع صفحات السجل ومقارنة الإرسال الإلكتروني — غير مفعّل'),
            _tile(Icons.show_chart, 'المسجلات الميكانيكية', 'Thermograph / Hygrograph / Barograph / Pluviograph — غير مفعّل'),
            _tile(Icons.compare_arrows, 'المقارنة الثلاثية', 'ورقي ↔ ميكانيكي ↔ إلكتروني — غير مفعّل'),
            _tile(Icons.rule, 'محركات التحقق', 'فيزيائي ورياضي بإصدارات قواعد موثّقة — غير مفعّل'),
            _tile(Icons.folder_open_outlined, 'ملفات الحالات', 'قائمة حالات تدقيق فارغة حتى يتوفر API — غير مفعّل'),
            _tile(Icons.fact_check_outlined, 'قرارات المدقق', 'اعتماد/رفض بشري بعد الأدلة — غير مفعّل'),
            _tile(Icons.model_training, 'مختبر التدريب', 'تسميات بشرية معتمدة فقط — غير مفعّل على الجهاز'),
            const SizedBox(height: 12),
            Text(
              'صلاحيات decide/promote منفصلة عن صلاحيات الراصد والتنبؤ. الاعتماد النهائي بشري.',
              style: TextStyle(color: Colors.blueGrey.shade700, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _tile(IconData icon, String title, String subtitle) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon, color: _blue),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: _navy)),
        subtitle: Text(subtitle),
      ),
    );
  }
}
