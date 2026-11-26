import 'package:material_ui/material_ui.dart';

import '../../core/catalog_integration/local_catalog_record.dart';
import '../../core/catalog_integration/local_catalog_record_store.dart';
import '../../core/drafts/observation_draft_store.dart';
import '../../core/notifications/local_notification_store.dart';
import '../../core/theme/metra_theme.dart';
import '../../core/widgets/metra_async_state.dart';

/// Operator-facing recovery for unassigned (legacy) on-device data.
///
/// Never auto-claims. Never invents server sync. Active account only.
class LegacyDataRecoveryScreen extends StatefulWidget {
  const LegacyDataRecoveryScreen({super.key});

  @override
  State<LegacyDataRecoveryScreen> createState() =>
      _LegacyDataRecoveryScreenState();
}

class _LegacyDataRecoveryScreenState extends State<LegacyDataRecoveryScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    LocalCatalogRecordStore.instance.addListener(_onChanged);
    ObservationDraftStore.instance.addListener(_onChanged);
    LocalNotificationStore.instance.addListener(_onChanged);
    _bootstrap();
  }

  @override
  void dispose() {
    LocalCatalogRecordStore.instance.removeListener(_onChanged);
    ObservationDraftStore.instance.removeListener(_onChanged);
    LocalNotificationStore.instance.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _bootstrap() async {
    await Future.wait([
      LocalCatalogRecordStore.instance.ensureLoaded(),
      ObservationDraftStore.instance.ensureLoaded(),
      LocalNotificationStore.instance.ensureLoaded(),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  String? get _account => LocalCatalogRecordStore.instance.activeAccountKey;

  List<LocalCatalogRecord> get _records =>
      LocalCatalogRecordStore.instance.listUnassigned();

  List<ObservationDraft> get _drafts =>
      ObservationDraftStore.instance.listUnassignedDrafts();

  Future<void> _claimRecord(LocalCatalogRecord record) async {
    final account = _account;
    if (account == null || account.isEmpty) {
      _toast('لا توجد جلسة حساب صالحة. سجّل الدخول ثم أعد المحاولة.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('استرداد سجل محلي'),
          content: Text(
            'سيتم نسب السجل «${record.id}» (${record.formType}) '
            'إلى حسابك الحالي فقط على هذا الجهاز.\n'
            'لن يُرسل إلى الخادم ولن يُنسب إلى أي حساب آخر.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('تأكيد الاسترداد'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    if (LocalCatalogRecordStore.instance.activeAccountKey != account) {
      _toast('تغير الحساب أثناء التأكيد. لم يتم الاسترداد.');
      return;
    }
    final claimed =
        LocalCatalogRecordStore.instance.claimToAccount(record.id, account);
    if (claimed == null) {
      _toast('تعذر الاسترداد. قد يكون السجل منسوبًا مسبقًا أو غير موجود.');
      return;
    }
    _toast('تم استرداد السجل محليًا إلى حسابك (بدون مزامنة خادمية).');
  }

  Future<void> _claimDraft(ObservationDraft draft) async {
    final account = _account;
    if (account == null || account.isEmpty) {
      _toast('لا توجد جلسة حساب صالحة. سجّل الدخول ثم أعد المحاولة.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('استرداد مسودة محلية'),
          content: Text(
            'سيتم نسب مسودة «${draft.formType}» للمحطة ${draft.stationId} '
            'إلى حسابك الحالي فقط.\n'
            'تبقى مسودة محلية ولن تُرسل تلقائيًا إلى الخادم.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('تأكيد الاسترداد'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    if (ObservationDraftStore.instance.activeAccountKey != account) {
      _toast('تغير الحساب أثناء التأكيد. لم يتم الاسترداد.');
      return;
    }
    final ok = ObservationDraftStore.instance.claimUnassignedDraft(
      draft.stationId,
      draft.formType,
    );
    _toast(
      ok
          ? 'تم استرداد المسودة إلى حسابك (محليًا فقط).'
          : 'تعذر الاسترداد. قد تكون هناك مسودة لنفس النموذج أو لم تعد المسودة حجرية.',
    );
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _openRecordDetail(LocalCatalogRecord record) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _LegacyRecordDetailPage(
          record: record,
          onClaim: () {
            Navigator.of(context).pop();
            _claimRecord(record);
          },
          canClaim: _account != null && _account!.isNotEmpty,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final records = _records;
    final drafts = _drafts;
    final account = _account;
    final total = records.length + drafts.length;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('استرداد بيانات محلية غير منسوبة')),
        body: _loading
            ? MetraAsyncStatePanel.loading(message: 'جاري فحص البيانات المحلية…')
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    color: const Color(0xFFFFF7E8),
                    child: ListTile(
                      leading: const Icon(
                        Icons.warning_amber_outlined,
                        color: Color(0xFF9A6700),
                      ),
                      title: const Text(
                        'بيانات حجرية على هذا الجهاز فقط',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        account == null
                            ? 'سجّل الدخول لاسترداد البيانات إلى حسابك. '
                                'لن تُنسب تلقائيًا.'
                            : 'عدد العناصر غير المنسوبة: $total. '
                                'الاسترداد اختياري وصريح ولن يُرسل إلى الخادم.',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'سجلات كتالوج محلية (${records.length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: MetraColors.navy,
                        ),
                  ),
                  const SizedBox(height: 8),
                  if (records.isEmpty)
                    const Card(
                      child: ListTile(
                        title: Text('لا توجد سجلات حجرية'),
                        subtitle: Text('كل السجلات المحلية منسوبة أو غير موجودة.'),
                      ),
                    )
                  else
                    ...records.map(
                      (r) => Card(
                        child: ListTile(
                          title: Text('${r.formType} · ${r.stationId}'),
                          subtitle: Text(
                            'id: ${r.id}\nحدّث: ${r.updatedAt.toLocal()}',
                          ),
                          isThreeLine: true,
                          onTap: () => _openRecordDetail(r),
                          trailing: account == null
                              ? null
                              : TextButton(
                                  onPressed: () => _claimRecord(r),
                                  child: const Text('استرداد'),
                                ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    'مسودات غير منسوبة (${drafts.length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: MetraColors.navy,
                        ),
                  ),
                  const SizedBox(height: 8),
                  if (drafts.isEmpty)
                    const Card(
                      child: ListTile(
                        title: Text('لا توجد مسودات حجرية'),
                      ),
                    )
                  else
                    ...drafts.map(
                      (d) => Card(
                        child: ListTile(
                          title: Text('${d.formType} · ${d.stationId}'),
                          subtitle: Text(
                            'حقول: ${d.values.length} · '
                            'حُفظت: ${d.savedAt.toLocal()}',
                          ),
                          trailing: account == null
                              ? null
                              : TextButton(
                                  onPressed: () => _claimDraft(d),
                                  child: const Text('استرداد'),
                                ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  const Card(
                    color: Color(0xFFF8FAFC),
                    child: ListTile(
                      leading: Icon(Icons.notifications_off_outlined),
                      title: Text('الإشعارات المحلية'),
                      subtitle: Text(
                        'الإشعارات غير المنسوبة تبقى حجرية ولا تُسترد تلقائيًا، '
                        'حمايةً لخصوصية أي جلسة سابقة على الجهاز.',
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _LegacyRecordDetailPage extends StatelessWidget {
  const _LegacyRecordDetailPage({
    required this.record,
    required this.onClaim,
    required this.canClaim,
  });

  final LocalCatalogRecord record;
  final VoidCallback onClaim;
  final bool canClaim;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('تفاصيل سجل غير منسوب')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Card(
              color: Color(0xFFFFF7E8),
              child: ListTile(
                title: Text('غير منسوب لأي حساب'),
                subtitle: Text('محلي على هذا الجهاز فقط — ليس من الخادم.'),
              ),
            ),
            ListTile(title: const Text('المعرّف'), subtitle: Text(record.id)),
            ListTile(
              title: const Text('المحطة'),
              subtitle: Text(record.stationId),
            ),
            ListTile(
              title: const Text('النوع'),
              subtitle: Text(record.formType),
            ),
            ListTile(
              title: const Text('آخر تحديث'),
              subtitle: Text(record.updatedAt.toLocal().toString()),
            ),
            const Divider(),
            ...record.values.entries.map(
              (e) => ListTile(
                dense: true,
                title: Text(e.key),
                subtitle: Text('${e.value ?? '—'}'),
              ),
            ),
            if (canClaim) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onClaim,
                child: const Text('استرداد إلى حسابي الحالي'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
