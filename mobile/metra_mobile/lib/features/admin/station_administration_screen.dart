import 'package:material_ui/material_ui.dart';

import '../../core/api/metra_api_client.dart';
import '../../core/errors/metra_error_presenter.dart';

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

  @override
  void initState() {
    super.initState();
    _refresh();
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

  Future<void> _decide(Map<String, dynamic> record, String decision) async {
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
    if (!confirmed || !mounted) return;

    if (_processingRequestIds.contains(requestId)) return;
    setState(() => _processingRequestIds.add(requestId));

    final note = noteController.text.trim();
    try {
      await widget.api.decideStationRegistrationRequest(
        stationId: widget.stationId,
        requestId: requestId,
        decision: decision,
        note: note.isEmpty ? null : note,
      );
      if (!mounted) return;
      setState(_refresh);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال قرار المراجعة إلى الخادم.')),
      );
    } on MetraApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(MetraErrorPresenter.registrationDecisionMessage(error))),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(MetraErrorPresenter.messageFor(error))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processingRequestIds.remove(requestId));
      }
    }
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
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          final error = snapshot.error;
          final message = error == null
              ? 'تعذر تحميل البيانات. اسحب للأسفل لإعادة المحاولة.'
              : MetraErrorPresenter.messageFor(error);
          return ListView(
            children: [
              const SizedBox(height: 48),
              Center(child: Text(message, textAlign: TextAlign.center)),
            ],
          );
        }
        final records = snapshot.data ?? const <Map<String, dynamic>>[];
        if (records.isEmpty) {
          return ListView(
            children: [
              const SizedBox(height: 48),
              Center(child: Text(emptyMessage)),
            ],
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
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          final error = snapshot.error;
          final message = error == null
              ? 'تعذر تحميل أرصاد المراجعة.'
              : MetraErrorPresenter.queueLoadMessage(error);
          return ListView(
            children: [
              const SizedBox(height: 48),
              Center(child: Text(message, textAlign: TextAlign.center)),
            ],
          );
        }
        final items = snapshot.data ?? const <ObservationQueueItem>[];
        if (items.isEmpty) {
          return ListView(
            children: const [
              SizedBox(height: 48),
              Center(
                  child: Text('لا توجد أرصاد في طابور المراجعة لهذه المحطة.')),
            ],
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
                    _recordsTab(
                      _users,
                      emptyMessage: 'لا توجد حسابات ظاهرة لهذه المحطة.',
                      registrationQueue: false,
                      audit: false,
                    ),
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
