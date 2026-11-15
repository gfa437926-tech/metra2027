import 'package:flutter/material.dart';
import '../../core/widgets/metra_ui.dart';

/// Field workspace for paper/mechanical records and three-source comparison.
/// File ingestion and OCR stay disabled until the secured API is connected.
class RecordsReviewWorkspaceScreen extends StatefulWidget {
  const RecordsReviewWorkspaceScreen({super.key});

  @override
  State<RecordsReviewWorkspaceScreen> createState() =>
      _RecordsReviewWorkspaceScreenState();
}

class _RecordsReviewWorkspaceScreenState
    extends State<RecordsReviewWorkspaceScreen> {
  int _section = 0;
  static const _recordTypes = [
    ('السجلات الورقية', Icons.menu_book_outlined, 'صور دفاتر الرصد والنماذج الورقية'),
    ('Thermograph', Icons.device_thermostat_outlined, 'مخططات درجة الحرارة'),
    ('Hygrograph', Icons.water_drop_outlined, 'مخططات الرطوبة'),
    ('Barograph', Icons.speed_outlined, 'مخططات الضغط الجوي'),
    ('Pluviograph', Icons.grain_outlined, 'مخططات الهطول المطري'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        const MetraPageHeader(
          title: 'أرشيف السجلات ومقارنة مصادر الرصد',
          subtitle:
              'مساحة ميدانية لحفظ السجلات المصورة ومراجعة القراءات المستخرجة ومقارنتها بالرصد الإلكتروني.',
        ),
        const SizedBox(height: 8),
        const MetraStatusBanner(
          tone: MetraBannerTone.warning,
          message:
              'رفع الصور وOCR ورقمنة المنحنيات غير مفعّلة حتى ربط التخزين الخاص وخدمات الاستخراج. لن تُعرض قراءات مولدة أو نتائج مقارنة وهمية.',
        ),
        const SizedBox(height: 14),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, label: Text('الأرشيف'), icon: Icon(Icons.folder_outlined)),
            ButtonSegment(value: 1, label: Text('المقارنة الثلاثية'), icon: Icon(Icons.compare_arrows)),
          ],
          selected: {_section},
          onSelectionChanged: (value) => setState(() => _section = value.first),
        ),
        const SizedBox(height: 14),
        if (_section == 0) ...[
          const Text('أنواع السجلات', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 10),
          ..._recordTypes.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: MetraSectionCard(
                  title: item.$1,
                  child: Row(
                    children: [
                      Icon(item.$2, color: metraBlue, size: 26),
                      const SizedBox(width: 12),
                      Expanded(child: Text(item.$3)),
                      const Chip(label: Text('رفع غير مفعّل')),
                    ],
                  ),
                ),
              )),
          const MetraSectionCard(
            title: 'بيانات تعريف السجل المطلوبة',
            child: Text(
              'المحطة · نوع الجهاز · العنصر المناخي · تاريخ ووقت بداية/نهاية المخطط · رقم الصفحة · بصمة الملف · اسم الرافع · حالة المراجعة',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: null,
            icon: const Icon(Icons.upload_file),
            label: const Text('إضافة صورة سجل — بانتظار خدمة التخزين'),
          ),
        ] else ...[
          const Text('مصادر القراءة الثلاثة', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 10),
          const MetraSectionCard(
            title: '1 · السجل الورقي',
            child: Text('القيمة المكتوبة يدوياً مع الصفحة وموضع القراءة وصورة المصدر.'),
          ),
          const MetraSectionCard(
            title: '2 · المسجل الميكانيكي',
            child: Text('القيمة المستخرجة من المنحنى مع معايرة المحاور وإحداثيات البكسل وعدم اليقين.'),
          ),
          const MetraSectionCard(
            title: '3 · الرصد الإلكتروني',
            child: Text('القيمة الرقمية المعتمدة للمحطة والعنصر والفترة الزمنية نفسها.'),
          ),
          const SizedBox(height: 10),
          const MetraSectionCard(
            title: 'نتيجة المطابقة',
            child: MetraEmptyState(
              icon: Icons.compare_arrows,
              title: 'لا توجد مقارنة محمّلة',
              message:
                  'بعد ربط المصادر ستظهر الفروقات المطلقة والنسبية والتسامحات وتراكب الصور وقرار المراجع مع سبب الاعتماد أو الرفض.',
            ),
          ),
          const SizedBox(height: 10),
          const MetraStatusBanner(
            tone: MetraBannerTone.info,
            message:
                'أي قيمة مستخرجة تبقى مقترحاً يحتاج مراجعة بشرية. تحفظ القيمة الأصلية ولا تستبدل تلقائياً.',
          ),
        ],
      ],
    );
  }
}
