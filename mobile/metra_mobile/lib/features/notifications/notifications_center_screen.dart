import 'package:material_ui/material_ui.dart';

import '../../core/preferences/notification_preferences_store.dart';
import '../../core/theme/metra_theme.dart';
import '../../core/widgets/metra_async_state.dart';

/// Notifications centre — structure complete; feed awaits a real service.
///
/// Preferences are local session flags only. No synthetic notification rows.
class NotificationsCenterScreen extends StatefulWidget {
  const NotificationsCenterScreen({super.key});

  @override
  State<NotificationsCenterScreen> createState() =>
      _NotificationsCenterScreenState();
}

class _NotificationsCenterScreenState extends State<NotificationsCenterScreen> {
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    NotificationPreferencesStore.instance.addListener(_onPrefsChanged);
  }

  @override
  void dispose() {
    NotificationPreferencesStore.instance.removeListener(_onPrefsChanged);
    super.dispose();
  }

  void _onPrefsChanged() {
    if (mounted) setState(() {});
  }

  NotificationPreferences get _prefs =>
      NotificationPreferencesStore.instance.current;

  void _setFilter(String value) {
    if (_filter == value) return;
    setState(() => _filter = value);
  }

  void _setObs(bool value) {
    NotificationPreferencesStore.instance.setObservationAlerts(value);
  }

  void _setReview(bool value) {
    NotificationPreferencesStore.instance.setReviewAlerts(value);
  }

  void _setFault(bool value) {
    NotificationPreferencesStore.instance.setFaultAlerts(value);
  }

  String get _emptySubtitle {
    switch (_filter) {
      case 'unread':
        return 'لا يوجد غير مقروء — خدمة الإشعارات غير متصلة بعد.';
      case 'read':
        return 'لا يوجد مقروء — لن تُعرض سجلات وهمية.';
      default:
        return 'لا يوجد مصدر إشعارات إنتاجي متصل في هذا الإصدار.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = _prefs;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Material(
        color: Colors.transparent,
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
            Card(
              color: const Color(0xFFFFF7E8),
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, color: Color(0xFF9A6700)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'وضع عدم الاتصال بالخدمة: التفضيلات محلية فقط ولن تُرسل '
                        'تنبيهات فعلية قبل اعتماد خدمة الإشعارات.'
                        '${prefs.anyEnabled ? ' (مفعّل محلياً: ${prefs.enabledCount})' : ''}',
                        style: const TextStyle(
                          color: Color(0xFF7C5E10),
                          height: 1.4,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in [
                  ('all', 'الكل'),
                  ('unread', 'غير مقروء'),
                  ('read', 'مقروء'),
                ])
                  FilterChip(
                    label: Text(e.$2),
                    selected: _filter == e.$1,
                    onSelected: (_) => _setFilter(e.$1),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: MetraAsyncStatePanel.empty(
                icon: Icons.notifications_none,
                title: 'لا توجد إشعارات',
                subtitle: _emptySubtitle,
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
            const SizedBox(height: 4),
            Card(
              child: SwitchListTile(
                value: prefs.observationAlerts,
                onChanged: _setObs,
                title: const Text('تنبيهات الرصد'),
                subtitle: const Text(
                  'تُحفظ محلياً ولن تُرسل إشعارات فعلية قبل الخدمة',
                ),
              ),
            ),
            Card(
              child: SwitchListTile(
                value: prefs.reviewAlerts,
                onChanged: _setReview,
                title: const Text('تنبيهات المراجعة'),
                subtitle: const Text(
                  'محلي فقط — لا اشتراك خادم في هذا الإصدار',
                ),
              ),
            ),
            Card(
              child: SwitchListTile(
                value: prefs.faultAlerts,
                onChanged: _setFault,
                title: const Text('تنبيهات الأعطال'),
                subtitle: const Text(
                  'محلي فقط — لا اشتراك خادم في هذا الإصدار',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
