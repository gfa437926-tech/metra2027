// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import '../../core/widgets/metra_ui.dart';

/// Climatol / climate homogenization workspace.
/// Jobs remain server-side; UI does not claim execution or alter raw series.
class ClimatolWorkspaceScreen extends StatefulWidget {
  const ClimatolWorkspaceScreen({super.key});

  @override
  State<ClimatolWorkspaceScreen> createState() => _ClimatolWorkspaceScreenState();
}

class _ClimatolWorkspaceScreenState extends State<ClimatolWorkspaceScreen> {
  String? _station;
  String? _variable;
  String? _status;

  final _stations = const ['اختر محطة', 'محطة مرجعية 1', 'محطة مرجعية 2'];
  final _variables = const ['درجة الحرارة', 'الهطول', 'الضغط'];

  void _prepareJob() {
    setState(() {
      _status =
          'تم إعداد طلب التحليل محلياً فقط. تشغيل Climatol الفعلي يحدث على الخادم المعزول بعد اعتماد عقود البيانات والوظائف. السلاسل الخام لا تُعدّل من الواجهة.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        const MetraPageHeader(
          title: 'Climatol والتجانس المناخي',
          subtitle:
              'واجهة إعداد ومراقبة وظائف التجانس. النتائج والرسوم واكتشاف الشاذات تظهر بعد توفر الخدمة المعتمدة.',
        ),
        const SizedBox(height: 8),
        const MetraStatusBanner(
          tone: MetraBannerTone.info,
          message:
              'الواجهة جاهزة لإعداد الطلبات. لا يتم تشغيل تحليل أو تعديل السلاسل الخام من العميل. التصدير والتقارير تُفعّل بعد عقود الخادم.',
        ),
        const SizedBox(height: 14),
        MetraSectionCard(
          title: 'إعداد التحليل',
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                initialValue: _station ?? _stations.first,
                items: _stations
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => setState(() => _station = v),
                decoration: const InputDecoration(labelText: 'المحطة'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _variable ?? _variables.first,
                items: _variables
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => setState(() => _variable = v),
                decoration: const InputDecoration(labelText: 'المتغير'),
              ),
              const SizedBox(height: 10),
              const TextField(
                decoration: InputDecoration(
                  labelText: 'الفترة الزمنية (من - إلى)',
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: _prepareJob,
                  icon: const Icon(Icons.science_outlined),
                  label: const Text('إعداد طلب التحليل'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        MetraSectionCard(
          title: 'حالة المعالجة والنتائج',
          child: _status == null
              ? const MetraEmptyState(
                  icon: Icons.timeline,
                  title: 'لا توجد مهمة نشطة',
                  message:
                      'بعد تشغيل الخدمة ستظهر هنا حالة المعالجة والنتائج والرسوم البيانية واكتشاف القيم الشاذة وتقارير التجانس ومقارنة السلاسل.',
                )
              : MetraStatusBanner(tone: MetraBannerTone.info, message: _status!),
        ),
        const SizedBox(height: 12),
        const MetraSectionCard(
          title: 'سجل العمليات',
          child: MetraEmptyState(
            icon: Icons.history,
            title: 'السجل فارغ',
            message: 'يُعرض سجل الوظائف المعتمدة بعد تفعيل مسار الخادم.',
          ),
        ),
      ],
    );
  }
}
