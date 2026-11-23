import 'package:material_ui/material_ui.dart';

import '../../core/api/metra_api_client.dart';
import '../../core/errors/metra_error_presenter.dart';
import '../../core/widgets/metra_async_state.dart';

class StationAdministrationScreen extends StatefulWidget {
  const StationAdministrationScreen({
    super.key,
    required this.api,
    required this.stationId,
  });

  final MetraApiClient api;
  final String stationId;

  @override
  State<StationAdministrationScreen> createState() =>
      _StationAdministrationScreenState();
}

class _StationAdministrationScreenState
    extends State<StationAdministrationScreen> {
  late Future<List<Map<String, dynamic>>> _users;
  late Future<List<Map<String, dynamic>>> _requests;
  late Future<List<Map<String, dynamic>>> _audit;
  late Future<List<ObservationQueueItem>> _observations;
  final Set<String> _processingRequestIds = <String>{};
  final TextEditingController _userFilterController = TextEditingController();
  String _userFilterQuery = '';

  @override
  void initState() {
    super.initState();
    _userFilterController.addListener(() {
      final next = _userFilterController.text.trim();
      if (next == _userFilterQuery) return;
      setState(() => _userFilterQuery = next);
    });
    _refresh();
  }

  @override
  void didUpdateWidget(covariant StationAdministrationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stationId != widget.stationId ||
        oldWidget.api != widget.api) {
      _processingRequestIds.clear();
      _refresh();
    }
  }

  @override
  void dispose() {
    _userFilterController.dispose();
    super.dispose();
  }

  /// Keeps the original error on the Future for FutureBuilder while preventing
  /// an unhandled async error when a TabBarView child is not yet mounted.
  Future<T> _observed<T>(Future<T> future) {
    future.then((_) {}, onError: (_) {});
    return future;
  }

  void _refresh() {
    _users = _observed(widget.api.getStationUsers(widget.stationId));
    _requests =
        _observed(widget.api.getStationRegistrationRequests(widget.stationId));
    _audit = _observed(widget.api.getStationAuditLog(widget.stationId));
    _observations = _observed(widget.api.getReviewQueue(widget.stationId));
  }

  String _firstValue(Map<String, dynamic> record, List<String> keys) {
    for (final key in keys) {
      final value = record[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return '—';
  }

  String _personName(Map<String, dynamic> record) {
    final full = _firstValue(record, ['full_name', 'display_name', 'name_ar']);
    if (full != '—') return full;
    final parts = [
      record['first_name'],
      record['father_name'],
      record['last_name'],
    ].where((part) => part != null && part.toString().trim().isNotEmpty);
    final joined = parts.join(' ');
    return joined.isEmpty ? _firstValue(record, ['email', 'user_id', 'id']) : joined;
  }

  bool _matchesUserFilter(Map<String, dynamic> record) {
    if (_userFilterQuery.isEmpty) return true;
    final haystack = [
      _personName(record),
      _firstValue(record, ['role_code', 'requested_role_code', 'role']),
      _firstValue(record, ['status', 'request_status', 'account_status']),
      _firstValue(record, ['phone', 'email', 'user_id', 'id']),
    ].join(' ').toLowerCase();
    return haystack.contains(_userFilterQuery.toLowerCase());
  }

  Future<void> _decide(Map<String, dynamic> record, String decision) async {
    // Keep the action bound to the station that supplied this queue row.
    final stationId = widget.stationId;
    final requestId = _firstValue(record, ['id', 'request_id']);
    if (requestId == '—') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('معرّف طلب التسجيل غير موجود في الاستجابة.')),
      );
      return;
    }

    final noteController = TextEditingController();
    bool confirmed = false;
    try {
      confirmed = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: Text(
                  decision == 'approve' ? 'اعتماد طلب التسجيل' : 'رفض طلب التسجيل'),
              content: TextField(
                controller: noteController,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: decision == 'reject'
                      ? 'سبب الرفض (إلزامي)'
                      : 'ملاحظة (اختيارية)',
                  border: const OutlineInputBorder(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  onPressed: () {
                    if (decision == 'reject' &&
                        noteController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(content: Text('أدخل سبب الرفض.')),
                      );
                      return;
                    }
                    Navigator.pop(dialogContext, true);
                  },
                  child: const Text('تأكيد'),
                ),
              ],
            ),
          ) ??
          false;
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        noteController.dispose();
      });
    }
    if (!confirmed || !mounted || stationId != widget.stationId) return;

    final processingKey = '$stationId::$requestId';
    if (_processingRequestIds.contains(processingKey)) return;
    setState(() => _processingRequestIds.add(processingKey));

    final note = noteController.text.trim();
    try {
      await widget.api.decideStationRegistrationRequest(
        stationId: stationId,
        requestId: requestId,
        decision: decision,
        note: note.isEmpty ? null : note,
      );
      if (!mounted || stationId != widget.stationId) return;
      setState(_refresh);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال قرار المراجعة إلى الخادم.')),
      );
    } on MetraApiException catch (error) {
      if (!mounted || stationId != widget.stationId) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(MetraErrorPresenter.registrationDecisionMessage(error))),
      );
    } catch (error) {
      if (mounted && stationId == widget.stationId) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(MetraErrorPresenter.messageFor(error))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processingRequestIds.remove(processingKey));
      }
    }
  }

  Widget _usersTab(Future<List<Map<String, dynamic>>> future) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return MetraAsyncStatePanel.loading(
            message: 'جاري تحميل مستخدمي المحطة…',
          );
        }
        if (snapshot.hasError) {
          final error = snapshot.error;
          final message = error == null
              ? 'تعذر تحميل البيانات. تحقق من الاتصال ثم أعد المحاولة.'
              : MetraErrorPresenter.messageFor(error);
          return MetraAsyncStatePanel.error(
            title: 'تعذر تحميل مستخدمي المحطة',
            subtitle: message,
            onRetry: () => setState(_refresh),
          );
        }
        final all = snapshot.data ?? const <Map<String, dynamic>>[];
        if (all.isEmpty) {
          return MetraAsyncStatePanel.empty(
            icon: Icons.group_off_outlined,
            title: 'لا توجد حسابات ظاهرة لهذه المحطة',
            subtitle: 'عند ربط مستخدمين بالمحطة ستظهر أسماؤهم وأدوارهم هنا.',
            action: TextButton(
              onPressed: () => setState(_refresh),
              child: const Text('تحديث'),
            ),
          );
        }
        final records = all.where(_matchesUserFilter).toList(growable: false);
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            TextField(
              controller: _userFilterController,
              decoration: InputDecoration(
                labelText: 'بحث ضمن مستخدمي المحطة',
                hintText: 'الاسم أو الدور أو الحالة أو الهاتف',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: _userFilterQuery.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _userFilterController.clear();
                        },
                        icon: const Icon(Icons.clear),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              records.isEmpty
                  ? 'لا نتائج مطابقة للبحث الحالي.'
                  : 'المعروض: ${records.length} من ${all.length}',
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
            ),
            const SizedBox(height: 8),
            for (var index = 0; index < records.length; index++) ...[
              if (index > 0) const SizedBox(height: 8),
              _userCard(records[index]),
            ],
          ],
        );
      },
    );
  }

  Widget _userCard(Map<String, dynamic> record) {
    final title = _personName(record);
    final subtitle = [
      _firstValue(record, ['role_code', 'requested_role_code', 'role']),
      _firstValue(record, ['status', 'request_status', 'account_status']),
      _firstValue(record, ['phone', 'email']),
    ].where((value) => value != '—').join(' • ');
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(subtitle, style: const TextStyle(color: Color(0xFF64748B))),
            ],
          ],
        ),
      ),
    );
  }

  Widget _recordsTab(
    Future<List<Map<String, dynamic>>> future, {
    required String emptyMessage,
    required bool registrationQueue,
    required bool audit,
  }) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return MetraAsyncStatePanel.loading(
            message: 'جاري تحميل السجلات…',
          );
        }
        if (snapshot.hasError) {
          final error = snapshot.error;
          final message = error == null
              ? 'تعذر تحميل البيانات. تحقق من الاتصال ثم أعد المحاولة.'
              : MetraErrorPresenter.messageFor(error);
          return MetraAsyncStatePanel.error(
            title: 'تعذر تحميل السجلات',
            subtitle: message,
            onRetry: () => setState(_refresh),
          );
        }
        final records = snapshot.data ?? const <Map<String, dynamic>>[];
        if (records.isEmpty) {
          return MetraAsyncStatePanel.empty(
            title: emptyMessage,
            subtitle: 'اسحب للتحديث أو أعد فتح الشاشة بعد توفر بيانات جديدة.',
            action: TextButton(
              onPressed: () => setState(_refresh),
              child: const Text('تحديث'),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: records.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final record = records[index];
            final title = audit
                ? _firstValue(record, ['event_type', 'action', 'event', 'id'])
                : _personName(record);
            final subtitle = audit
                ? [
                    _firstValue(record, ['created_at', 'occurred_at']),
                    _firstValue(record, ['actor_user_id', 'actor_name']),
                  ].where((value) => value != '—').join(' • ')
                : [
                    _firstValue(
                        record, ['role_code', 'requested_role_code', 'role']),
                    _firstValue(record, ['status', 'request_status']),
                    _firstValue(record, ['phone', 'email']),
                  ].where((value) => value != '—').join(' • ');
            return Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(subtitle,
                          style: const TextStyle(color: Color(0xFF64748B))),
                    ],
                    if (registrationQueue) ...[
                      const SizedBox(height: 10),
                      Builder(
                        builder: (context) {
                          final rid = _firstValue(record, ['id', 'request_id']);
                          final busy = _processingRequestIds.contains(rid);
                          return Wrap(
                            spacing: 8,
                            children: [
                              FilledButton.tonal(
                                onPressed: busy
                                    ? null
                                    : () => _decide(record, 'approve'),
                                child: Text(busy ? 'جارٍ...' : 'اعتماد'),
                              ),
                              OutlinedButton(
                                onPressed: busy
                                    ? null
                                    : () => _decide(record, 'reject'),
                                child: const Text('رفض'),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _observationsTab() {
    return FutureBuilder<List<ObservationQueueItem>>(
      future: _observations,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return MetraAsyncStatePanel.loading(
            message: 'جاري تحميل أرصاد المراجعة…',
          );
        }
        if (snapshot.hasError) {
          final error = snapshot.error;
          final message = error == null
              ? 'تعذر تحميل أرصاد المراجعة.'
              : MetraErrorPresenter.queueLoadMessage(error);
          return MetraAsyncStatePanel.error(
            title: 'تعذر تحميل أرصاد المراجعة',
            subtitle: message,
            onRetry: () => setState(_refresh),
          );
        }
        final items = snapshot.data ?? const <ObservationQueueItem>[];
        if (items.isEmpty) {
          return MetraAsyncStatePanel.empty(
            icon: Icons.fact_check_outlined,
            title: 'لا توجد أرصاد في طابور المراجعة',
            subtitle: 'لا توجد عناصر بانتظار القرار لهذه المحطة حالياً.',
            action: TextButton(
              onPressed: () => setState(_refresh),
              child: const Text('تحديث'),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final item = items[index];
            return Card(
              elevation: 0,
              child: ListTile(
                title: Text('${item.observationType} · ${item.status}'),
                subtitle: Text('${item.observedAt.toLocal()} · ${item.id}'),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleRefresh() async {
    setState(_refresh);
    await Future.wait([
      _users.catchError((_) => <Map<String, dynamic>>[]),
      _requests.catchError((_) => <Map<String, dynamic>>[]),
      _audit.catchError((_) => <Map<String, dynamic>>[]),
      _observations.catchError((_) => <ObservationQueueItem>[]),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: DefaultTabController(
        length: 4,
        child: Column(
          children: [
            const Material(
              color: Colors.white,
              child: TabBar(
                isScrollable: true,
                tabs: [
                  Tab(text: 'مستخدمو المحطة'),
                  Tab(text: 'طلبات التسجيل'),
                  Tab(text: 'أرصاد للمراجعة'),
                  Tab(text: 'سجل التدقيق'),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _handleRefresh,
                child: TabBarView(
                  children: [
                    _usersTab(_users),
                    _recordsTab(
                      _requests,
                      emptyMessage: 'لا توجد طلبات تسجيل معلقة.',
                      registrationQueue: true,
                      audit: false,
                    ),
                    _observationsTab(),
                    _recordsTab(
                      _audit,
                      emptyMessage: 'لا توجد أحداث تدقيق معروضة.',
                      registrationQueue: false,
                      audit: true,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
