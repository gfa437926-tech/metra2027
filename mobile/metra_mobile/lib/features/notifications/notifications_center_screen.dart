import 'package:material_ui/material_ui.dart';

import '../../core/notifications/local_notification_store.dart';
import '../../core/preferences/notification_preferences_store.dart';
import '../../core/theme/metra_theme.dart';
import '../../core/widgets/metra_async_state.dart';

/// Notifications centre — local feed only until a server contract exists.
///
/// Items come from on-device events (e.g. local catalogue saves). Preferences
/// remain session/local flags and do not enable push delivery.
class NotificationsCenterScreen extends StatefulWidget {
  const NotificationsCenterScreen({super.key});

  @override
  State<NotificationsCenterScreen> createState() =>
      _NotificationsCenterScreenState();
}

class _NotificationsCenterScreenState extends State<NotificationsCenterScreen> {
  String _filter = 'all';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    NotificationPreferencesStore.instance.addListener(_onChanged);
    LocalNotificationStore.instance.addListener(_onChanged);
    _bootstrap();
  }

  @override
  void dispose() {
    NotificationPreferencesStore.instance.removeListener(_onChanged);
    LocalNotificationStore.instance.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _bootstrap() async {
    await LocalNotificationStore.instance.ensureLoaded();
    if (mounted) setState(() => _loading = false);
  }

  NotificationPreferences get _prefs =>
      NotificationPreferencesStore.instance.current;

  void _setFilter(String value) {
    if (_filter == value) return;
    setState(() => _filter = value);
  }

  @override
  Widget build(BuildContext context) {
    final prefs = _prefs;
    final items = LocalNotificationStore.instance.filtered(_filter);
    final unread = LocalNotificationStore.instance.unreadCount;

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
              'وضع عدم الاتصال بالخدمة: القائمة محلية على هذا الجهاز فقط ولا يوجد مصدر إشعارات خادمي متصل.',
              style: TextStyle(color: Color(0xFF64748B), height: 1.4),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('تنبيهات الرصد'),
                    value: prefs.observationAlerts,
                    onChanged: (v) => NotificationPreferencesStore.instance
                        .setObservationAlerts(v),
                  ),
                  SwitchListTile(
                    title: const Text('تنبيهات المراجعة'),
                    value: prefs.reviewAlerts,
                    onChanged: (v) => NotificationPreferencesStore.instance
                        .setReviewAlerts(v),
                  ),
                  SwitchListTile(
                    title: const Text('تنبيهات الأعطال'),
                    value: prefs.faultAlerts,
                    onChanged: (v) =>
                        NotificationPreferencesStore.instance.setFaultAlerts(v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('الكل'),
                  selected: _filter == 'all',
                  onSelected: (_) => _setFilter('all'),
                ),
                ChoiceChip(
                  label: Text('غير مقروء ($unread)'),
                  selected: _filter == 'unread',
                  onSelected: (_) => _setFilter('unread'),
                ),
                ChoiceChip(
                  label: const Text('مقروء'),
                  selected: _filter == 'read',
                  onSelected: (_) => _setFilter('read'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(
                  onPressed: unread == 0
                      ? null
                      : () => LocalNotificationStore.instance.markAllRead(),
                  child: const Text('تعليميز الكل كمقروء'),
                ),
                TextButton(
                  onPressed: items.isEmpty
                      ? null
                      : () => LocalNotificationStore.instance.clearAll(),
                  child: const Text('مسح القائمة المحلية'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_loading)
              MetraAsyncStatePanel.loading(message: 'جاري تحميل الإشعارات المحلية…')
            else if (items.isEmpty)
              MetraAsyncStatePanel.empty(
                icon: Icons.notifications_none,
                title: 'لا توجد إشعارات',
                subtitle: _filter == 'unread'
                    ? 'لا يوجد غير مقروء. ستظهر إشعارات عند حفظ سجلات كتالوج محلية.'
                    : _filter == 'read'
                        ? 'لا يوجد مقروء. الأحداث المحلية فقط تُعرض هنا.'
                        : 'لا يوجد مصدر خادمي. الأحداث المحلية فقط تُعرض هنا.',
              )
            else
              ...items.map(
                (item) => Card(
                  elevation: 0,
                  color: item.read
                      ? Colors.white
                      : const Color(0xFFF0F7FF),
                  child: ListTile(
                    leading: Icon(
                      item.read
                          ? Icons.mark_email_read_outlined
                          : Icons.mark_email_unread_outlined,
                      color: MetraColors.navy,
                    ),
                    title: Text(
                      item.titleAr,
                      style: TextStyle(
                        fontWeight:
                            item.read ? FontWeight.w500 : FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      '${item.bodyAr}\n${item.createdAt.toLocal()}',
                    ),
                    isThreeLine: true,
                    onTap: () =>
                        LocalNotificationStore.instance.markRead(item.id),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
