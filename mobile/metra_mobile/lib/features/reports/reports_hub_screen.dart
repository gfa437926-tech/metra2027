import 'package:flutter/material.dart';

class ReportsHubScreen extends StatelessWidget {
  const ReportsHubScreen({super.key, this.onOpenArchive});

  final VoidCallback? onOpenArchive;

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
            Card(
              elevation: 0,
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.analytics_outlined, color: Color(0xFF087CF0), size: 28),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'التقارير والتحليلات',
                            style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    Text(
                      'مركز موحد للتقارير التشغيلية والمناخية. لن تظهر أرقام أو رسوم قبل توفر مصدر بيانات معتمد وعقد قراءة واضح.',
                      style: TextStyle(color: Color(0xFF64748B), height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 10),
            _ReportCapabilityCard(
              icon: Icons.history,
              title: 'الأرشيف التاريخي للرصدات',
              description: 'استعراض الرصدات المقدمة والمعتمدة حسب المحطة والتاريخ، مع تفاصيل السجل وحالة المراجعة.',
              requirement: 'أرشيف مستورد للقراءة فقط، مع تصفية حسب نوع الرصد وتفاصيل السجل.',
              action: onOpenArchive,
              actionLabel: 'فتح الأرشيف',
            ),
            _ReportCapabilityCard(
              icon: Icons.today_outlined,
              title: 'التقارير الساعية واليومية',
              description: 'ملخصات الرصدات حسب الساعة واليوم، مع إمكانية المقارنة بين المحطات.',
              requirement: 'يتطلب عقد قراءة للرصدات المعتمدة وتعريفاً موحداً للتوقيت والحقول الناقصة.',
            ),
            _ReportCapabilityCard(
              icon: Icons.calendar_month_outlined,
              title: 'التقارير الشهرية والسنوية',
              description: 'تجميعات شهرية وسنوية قابلة للتدقيق حسب المحطة والعنصر المناخي.',
              requirement: 'يتطلب عقد تجميع معتمد وقواعد موثقة للمجاميع والمتوسطات والقيم المفقودة.',
            ),
            _ReportCapabilityCard(
              icon: Icons.query_stats,
              title: 'التحليل المناخي والتجانس',
              description: 'مخرجات التحليل الإحصائي والتجانس مع توثيق إصدار البيانات والمنهجية.',
              requirement: 'يتطلب عقد نتائج مُرقّم الإصدارات واعتماد مدخلات ومخرجات Climatol ومراجعتها.',
            ),
            _ReportCapabilityCard(
              icon: Icons.picture_as_pdf_outlined,
              title: 'التصدير والطباعة',
              description: 'إنتاج ملفات PDF وExcel للتقارير بعد اعتماد بياناتها وصلاحيات الوصول.',
              requirement: 'يتطلب عقد تصدير موثقاً يطبق صلاحيات المستخدم ونطاق المحطات.',
            ),
            SizedBox(height: 8),
            Text(
              'ملاحظة: قائمة مراجعة الرصدات وسجل تدقيق المحطة وظيفتان منفصلتان عن أرشيف الرصدات التاريخي.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.5),
            ),
              ],
            ),
          ),
        ),
      );
}

class _ReportCapabilityCard extends StatelessWidget {
  const _ReportCapabilityCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.requirement,
    this.action,
    this.actionLabel,
  });

  final IconData icon;
  final String title;
  final String description;
  final String requirement;
  final VoidCallback? action;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: const Color(0xFF64748B)),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  Text(
                    action == null ? 'بانتظار عقد API' : 'متاح للأرشيف التاريخي',
                    style: TextStyle(color: action == null ? Color(0xFF9A5B00) : Color(0xFF16834A), fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(description, style: const TextStyle(height: 1.45)),
              const SizedBox(height: 8),
              Text(
                requirement,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, height: 1.4),
              ),
              if (action != null) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FilledButton.tonalIcon(
                    onPressed: action,
                    icon: const Icon(Icons.archive_outlined),
                    label: Text(actionLabel ?? 'فتح'),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
}
