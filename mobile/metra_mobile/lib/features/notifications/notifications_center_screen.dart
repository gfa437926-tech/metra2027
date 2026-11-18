import 'package:material_ui/material_ui.dart';

import '../../core/theme/metra_theme.dart';
import '../../core/widgets/metra_async_state.dart';

/// Local notifications centre shell — no fabricated push feed.
class NotificationsCenterScreen extends StatelessWidget {
  const NotificationsCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'مركز الإشعارات',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: MetraColors.navy,
                ),
          ),
          const SizedBox(height: 8),
          const Text(
            'عند ربط خدمة إشعارات معتمدة ستظهر هنا تنبيهات الرصد والمراجعة والأعطال.',
            style: TextStyle(color: MetraColors.muted, height: 1.45),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 280,
            child: MetraAsyncStatePanel.empty(
              icon: Icons.notifications_none,
              title: 'لا توجد إشعارات معروضة',
              subtitle:
                  'لا يوجد مصدر إشعارات إنتاجي متصل في هذا الإصدار. لن تُعرض رسائل وهمية.',
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: SwitchListTile(
              value: false,
              onChanged: null,
              title: const Text('تنبيهات الرصد'),
              subtitle: const Text('يُفعَّل بعد اعتماد خدمة الإشعارات'),
            ),
          ),
          Card(
            child: SwitchListTile(
              value: false,
              onChanged: null,
              title: const Text('تنبيهات المراجعة'),
              subtitle: const Text('يُفعَّل بعد اعتماد خدمة الإشعارات'),
            ),
          ),
        ],
      ),
    );
  }
}
