import 'package:flutter/material.dart';

/// Paper / mechanical / electronic record matching workstation shell.
class RecordMatchingShellScreen extends StatelessWidget {
  const RecordMatchingShellScreen({super.key});

  static const _navy = Color(0xFF061B4A);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: _navy,
          foregroundColor: Colors.white,
          title: const Text('مطابقة السجلات'),
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Card(
              color: Color(0xFFFFFBEB),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'واجهة مطابقة السجلات الورقية والمخططات الميكانيكية مع الإرسال الإلكتروني. '
                  'لا OCR ولا استخراج منحنيات ولا تعديل قيم METRA من هنا في هذه المرحلة.',
                  style: TextStyle(height: 1.55),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _step('1', 'اختيار المحطة والجهاز والفترة (UTC)'),
            _step('2', 'رفع صورة السجل/المخطط دون حذف الأصل'),
            _step('3', 'استخراج قيم للمراجعة البشرية'),
            _step('4', 'جلب القيم الإلكترونية المقابلة من METRA'),
            _step('5', 'عرض الفروقات وإصدار تقرير تدقيق'),
            const SizedBox(height: 12),
            const Text(
              'الاعتماد النهائي بشري. لن تُعرض نسب دقة مختلقة.',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _step(String n, String text) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFEEF6FF),
          child: Text(n, style: const TextStyle(color: Color(0xFF061B4A))),
        ),
        title: Text(text),
        subtitle: const Text('غير مفعّل — بانتظار مواصفات التشغيل وAPI'),
      ),
    );
  }
}
