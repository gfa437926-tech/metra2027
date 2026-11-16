// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import '../../core/widgets/metra_ui.dart';

/// AI intelligence workspace shell.
/// No synthetic analysis is claimed. Service-unavailable and policy states are explicit.
class AiWorkspaceScreen extends StatefulWidget {
  const AiWorkspaceScreen({super.key});

  @override
  State<AiWorkspaceScreen> createState() => _AiWorkspaceScreenState();
}

class _AiWorkspaceScreenState extends State<AiWorkspaceScreen> {
  final _query = TextEditingController();
  String? _lastStatus;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _runQuery() {
    setState(() {
      _lastStatus =
          'خدمة التحليل غير متاحة حالياً. لا تُعرض نتائج أو توصيات أو مؤشرات ثقة إلا بعد اعتماد بوابة AI وطبقة البيانات المعتمدة.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        const MetraPageHeader(
          title: 'الذكاء الاصطناعي',
          subtitle:
              'واجهة موحدة للاستفسارات والتحليلات. كل نتيجة يجب أن تحمل مصدر البيانات ومؤشر الثقة عند توفرها.',
        ),
        const SizedBox(height: 8),
        const MetraStatusBanner(
          tone: MetraBannerTone.warning,
          message:
              'لا توجد نتائج تحليل حقيقية في هذه النسخة. لا يُسمح بعرض توصيات أو تفسيرات غير مربوطة بمصدر معتمد ومراجعة بشرية.',
        ),
        const SizedBox(height: 14),
        MetraSectionCard(
          title: 'الاستفسار',
          child: Column(
            children: [
              TextField(
                controller: _query,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'اكتب استفسارك التشغيلي أو التحليلي',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: _runQuery,
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: const Text('تشغيل التحليل'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        MetraSectionCard(
          title: 'النتائج والتوصيات',
          child: _lastStatus == null
              ? const MetraEmptyState(
                  icon: Icons.psychology_outlined,
                  title: 'لا توجد نتائج',
                  message:
                      'عند توفر بوابة الذكاء الاصطناعي المعتمدة ستظهر هنا النتائج ومصادر البيانات ومؤشرات الثقة وسجل التحليلات.',
                )
              : MetraStatusBanner(
                  tone: MetraBannerTone.info,
                  message: _lastStatus!,
                ),
        ),
        const SizedBox(height: 12),
        const MetraSectionCard(
          title: 'سجل التحليلات',
          child: MetraEmptyState(
            icon: Icons.history,
            title: 'السجل فارغ',
            message: 'يُحفظ سجل الاستفسارات والنتائج بعد تفعيل الخدمة المعتمدة فقط.',
          ),
        ),
      ],
    );
  }
}
