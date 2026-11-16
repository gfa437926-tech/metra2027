import 'package:material_ui/material_ui.dart';

import '../../core/api/metra_api_client.dart';

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

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    _users = widget.api.getStationUsers(widget.stationId);
    _requests = widget.api.getStationRegistrationRequests(widget.stationId);
    _audit = widget.api.getStationAuditLog(widget.stationId);
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
    return joined.isEmpty
        ? _firstValue(record, ['email', 'user_id', 'id'])
        : joined;
  }

  String _errorMessage(Object? error) {
    if (error is MetraApiException) return error.displayMessage;
    return 'تعذر تحميل البيانات. اسحب للأسفل لإعادة المحاولة.';
  }

  Future<void> _decide(Map<String, dynamic> record, String decision) async {
    final requestId = _firstValue(record, ['id', 'request_id']);
    if (requestId == '—') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('معرّف طلب التسجيل غير موجود في الاستجابة.'),
        ),
      );
      return;
    }

    final noteController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          decision == 'approve' ? 'اعتماد طلب التسجيل' : 'رفض طلب التسجيل',
        ),
        content: TextField(
          controller: noteController,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            labelText:
                decision == 'reject' ? 'سبب الرفض (إلزامي)' : 'ملاحظة (اختيارية)',
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
              if (decision == 'reject' && noteController.text.trim().isEmpty) {
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
    );
    if (confirmed != true || !mounted) {
      noteController.dispose();
      return;
    }

    try {
      await widget.api.decideStationRegistrationRequest(
        stationId: widget.stationId,
        requestId: requestId,
        decision: decision,
        note: noteController.text.trim().isEmpty
            ? null
            : noteController.text.trim(),
      );
      if (!mounted) return;
      setState(_refresh);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال قرار المراجعة إلى الخادم.')),
      );
    } on MetraApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.displayMessage)),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر الاتصال بخدمة مراجعة التسجيل.'),
          ),
        );
      }
    } finally {
      noteController.dispose();
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
          return ListView(
            children: [
              const SizedBox(height: 48),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _errorMessage(snapshot.error),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
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
                      record,
                      ['role_code', 'requested_role_code', 'role'],
                    ),
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
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: const TextStyle(color: Color(0xFF64748B)),
                      ),
                    ],
                    if (registrationQueue) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        children: [
                          FilledButton.tonal(
                            onPressed: () => _decide(record, 'approve'),
                            child: const Text('اعتماد'),
                          ),
                          OutlinedButton(
                            onPressed: () => _decide(record, 'reject'),
                            child: const Text('رفض'),
                          ),
                        ],
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

  Future<void> _handleRefresh() async {
    setState(_refresh);
    await Future.wait(
      [_users, _requests, _audit].map(
        (future) => future.catchError((_) => <Map<String, dynamic>>[]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            const Material(
              color: Colors.white,
              child: TabBar(
                isScrollable: true,
                tabs: [
                  Tab(text: 'مستخدمو المحطة'),
                  Tab(text: 'طلبات التسجيل'),
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
