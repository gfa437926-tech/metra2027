import 'package:flutter/material.dart';

/// AFTN operations console shell — no message traffic without approved channel.
class AftnConsoleShellScreen extends StatelessWidget {
  const AftnConsoleShellScreen({super.key});

  static const _navy = Color(0xFF061B4A);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: _navy,
          foregroundColor: Colors.white,
          title: const Text('وحدة AFTN'),
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Card(
              color: Color(0xFFFFF7ED),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'وحدة مستقبل/مرسل AFTN هيكلية. لا استقبال رسائل حية ولا إرسال من هذا التطبيق '
                  'حتى تُعتمد قناة خادمية وقوالب التحقق وعزل المركز/المحطة.',
                  style: TextStyle(height: 1.55),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _row(Icons.inbox_outlined, 'صندوق الوارد', 'غير مفعّل — بلا مصدر رسائل'),
            _row(Icons.outbox_outlined, 'الصادر', 'غير مفعّل — ممنوع الإرسال الوهمي'),
            _row(Icons.rule, 'التحقق من القوالب', 'بعد اعتماد مخطط الرسائل'),
            _row(Icons.history, 'سجل التدقيق', 'بعد ربط التخزين الخادمي'),
          ],
        ),
      ),
    );
  }

  static Widget _row(IconData icon, String title, String subtitle) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF087CF0)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
      ),
    );
  }
}
