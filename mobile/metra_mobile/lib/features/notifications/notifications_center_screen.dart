import 'package:material_ui/material_ui.dart';

import '../../core/theme/metra_theme.dart';
import '../../core/widgets/metra_async_state.dart';

/// Notifications centre — structure complete; feed awaits a real service.
class NotificationsCenterScreen extends StatefulWidget {
  const NotificationsCenterScreen({super.key});

  @override
  State<NotificationsCenterScreen> createState() =>
      _NotificationsCenterScreenState();
}

class _NotificationsCenterScreenState extends State<NotificationsCenterScreen> {
  String _filter = 'all';
  bool _prefObs = false;
  bool _prefReview = false;
  bool _prefFault = false;

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
            'الواجهة جاهزة للقائمة والفلاتر والتفضيلات. لا تُعرض إشعارات وهمية؛ '
            'عند ربط خدمة معتمدة ستُملأ القائمة من الخادم.',
            style: TextStyle(color: MetraColors.muted, height: 1.45),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final e in [
                ('all', 'الكل'),
                ('unread', 'غير مقروء'),
                ('read', 'مقروء'),
              ])
                FilterChip(
                  label: Text(e.$2),
                  selected: _filter == e.$1,
                  onSelected: (_) => setState(() => _filter = e.$1),
                ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: MetraAsyncStatePanel.empty(
              icon: Icons.notifications_none,
              title: 'لا توجد إشعارات',
              subtitle: _filter == 'unread'
                  ? 'لا يوجد غير مقروء — الخدمة غير متصلة بعد.'
                  : 'لا يوجد مصدر إشعارات إنتاجي متصل في هذا الإصدار.',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'التفضيلات (محلية حتى ربط الخدمة)',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: MetraColors.navy,
                ),
          ),
          Card(
            child: SwitchListTile(
              value: _prefObs,
              onChanged: (v) => setState(() => _prefObs = v),
              title: const Text('تنبيهات الرصد'),
              subtitle: const Text('تُحفظ محلياً ولن تُرسل إشعارات فعلية قبل الخدمة'),
            ),
          ),
          Card(
            child: SwitchListTile(
              value: _prefReview,
              onChanged: (v) => setState(() => _prefReview = v),
              title: const Text('تنبيهات المراجعة'),
            ),
          ),
          Card(
            child: SwitchListTile(
              value: _prefFault,
              onChanged: (v) => setState(() => _prefFault = v),
              title: const Text('تنبيهات الأعطال'),
            ),
          ),
        ],
      ),
    );
  }
}
