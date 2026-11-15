import 'package:flutter/material.dart';

const _navy = Color(0xFF061B4A);
const _blue = Color(0xFF087CF0);

enum MetraServiceState { liveApi, gated, specificationOnly }

/// Shared RTL workspace shell — banners only; no nested navigation rails.
class MetraWorkspaceShell extends StatelessWidget {
  const MetraWorkspaceShell({
    super.key,
    required this.title,
    required this.state,
    required this.body,
    this.stateMessage,
  });

  final String title;
  final MetraServiceState state;
  final Widget body;
  final String? stateMessage;

  Color get _bannerColor => switch (state) {
        MetraServiceState.liveApi => const Color(0xFF0F766E),
        MetraServiceState.gated => const Color(0xFFB45309),
        MetraServiceState.specificationOnly => const Color(0xFF475569),
      };

  String get _bannerLabel => switch (state) {
        MetraServiceState.liveApi => 'متصل بالخادم ضمن الصلاحيات',
        MetraServiceState.gated => 'موقوف ببوابة على الخادم حتى الاعتماد',
        MetraServiceState.specificationOnly =>
          'مواصفة واجهة — المحرك غير منفّذ',
      };

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _navy,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _bannerColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _bannerColor.withValues(alpha: 0.35)),
            ),
            child: Text(
              stateMessage ?? _bannerLabel,
              style: TextStyle(color: _bannerColor, height: 1.5),
            ),
          ),
          const SizedBox(height: 16),
          body,
        ],
      ),
    );
  }
}

class MetraPlaceholderBody extends StatelessWidget {
  const MetraPlaceholderBody({super.key, required this.lines});
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final line in lines) ...[
              Text(line,
                  style:
                      const TextStyle(color: Color(0xFF475569), height: 1.6)),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 4),
            const Text(
              'لا تُعرض بيانات علمية وهمية. عند توفر المحرك أو الـ API ستُربط هذه الواجهة دون تغيير هيكل التنقل.',
              style: TextStyle(
                  color: _blue, fontWeight: FontWeight.w600, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
