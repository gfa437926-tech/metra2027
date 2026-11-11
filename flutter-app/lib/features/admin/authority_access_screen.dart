import 'package:flutter/material.dart';
import '../../core/api/metra_api_client.dart';

class AuthorityAccessScreen extends StatefulWidget {
  const AuthorityAccessScreen({super.key, required this.api});
  final MetraApiClient api;
  @override
  State<AuthorityAccessScreen> createState() => _AuthorityAccessScreenState();
}

class _AuthorityAccessScreenState extends State<AuthorityAccessScreen> {
  List<Map<String, dynamic>> _authorities = const [];
  String? _authorityId;
  Future<List<Map<String, dynamic>>>? _pendingMemberships;
  Future<List<Map<String, dynamic>>>? _activeMemberships;
  Future<List<Map<String, dynamic>>>? _pendingGrants;
  Future<List<Map<String, dynamic>>>? _activeGrants;
  Future<List<Map<String, dynamic>>>? _audit;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String? _feedback;

  @override
  void initState() {
    super.initState();
    _loadAuthorities();
  }

  Future<void> _loadAuthorities() async {
    setState(() { _loading = true; _error = null; });
    try {
      final rows = await widget.api.getAuthorities();
      if (!mounted) return;
      setState(() {
        _authorities = rows;
        _authorityId = rows.isEmpty ? null : rows.first['id']?.toString();
        _loading = false;
      });
      _refreshQueues();
    } on MetraApiException catch (e) {
      if (mounted) setState(() { _loading = false; _error = _apiError(e.statusCode); });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = 'تعذر تحميل قائمة الجهات.'; });
    }
  }

  void _refreshQueues() {
    if (!mounted) return;
    final id = _authorityId;
    if (id == null) return;
    setState(() {
      _pendingMemberships = widget.api.getAuthorityAccessQueue(id, kind: 'membership');
      _activeMemberships = widget.api.getAuthorityAccessQueue(id, kind: 'membership_active');
      _pendingGrants = widget.api.getAuthorityAccessQueue(id, kind: 'permission_grant');
      _activeGrants = widget.api.getAuthorityAccessQueue(id, kind: 'permission_grant_active');
      _audit = widget.api.getAuthorityAccessAudit(id);
      _error = null;
      _feedback = null;
    });
  }

  String _apiError(int code) => switch (code) {
    401 => 'انتهت الجلسة. سجّل الدخول مجدداً.',
    403 => 'ليست لديك صلاحية لهذا الإجراء ضمن الجهة المحددة.',
    404 => 'الجهة أو سجل الوصول غير موجود.',
    409 => 'تغيرت حالة الطلب. حدّث القائمة قبل المتابعة.',
    503 => 'خدمة إدارة الصلاحيات غير متاحة حالياً.',
    _ => 'تعذر إكمال الطلب (HTTP $code).',
  };

  String _shortId(Object? value) {
    final id = value?.toString() ?? '';
    if (id.isEmpty) return 'غير متوفر';
    return id.length > 14 ? '${id.substring(0, 10)}…' : id;
  }

  String _utc(Object? value) {
    if (value is! String) return 'غير متوفر';
    final parsed = DateTime.tryParse(value);
    return parsed == null ? 'غير متوفر' : '${parsed.toUtc().toIso8601String()} UTC';
  }

  Future<String?> _reason(String title) => showDialog<String>(
    context: context,
    builder: (_) => _AuthorityReasonDialog(title: title),
  );

  Future<String?> _selectCode({
    required String title,
    required List<Map<String, dynamic>> rows,
    required String key,
    required String labelKey,
    bool requestableOnly = false,
  }) async {
    final choices = rows.where((row) =>
      (row[key]?.toString().isNotEmpty ?? false) &&
      (!requestableOnly || row['is_requestable'] == true)).toList();
    if (choices.isEmpty) {
      if (mounted) setState(() => _feedback = 'لا توجد خيارات متاحة من الخادم لهذا الطلب.');
      return null;
    }
    var selected = choices.first[key].toString();
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, refresh) => AlertDialog(
          title: Text(title),
          content: DropdownButtonFormField<String>(
            initialValue: selected,
            isExpanded: true,
            items: choices.map((row) => DropdownMenuItem<String>(
              value: row[key].toString(),
              child: Text((row[labelKey] ?? row[key]).toString()),
            )).toList(),
            onChanged: (value) { if (value != null) refresh(() => selected = value); },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(ctx, selected), child: const Text('متابعة')),
          ],
        ),
      ),
    );
  }

  Future<void> _request(bool membership) async {
    final authorityId = _authorityId;
    if (_busy || authorityId == null) return;
    setState(() { _busy = true; _error = null; _feedback = null; });
    try {
      final options = membership
          ? await widget.api.getAuthorityMembershipRoles(authorityId)
          : await widget.api.getAuthorityPermissionOptions(authorityId);
      if (!mounted) return;
      final code = await _selectCode(
        title: membership ? 'طلب عضوية جهة' : 'طلب منح صلاحية',
        rows: options,
        key: membership ? 'role_code' : 'permission_code',
        labelKey: membership ? 'name_ar' : 'permission_code',
        requestableOnly: membership,
      );
      if (code == null || !mounted) return;
      final reason = await _reason(membership ? 'سبب طلب العضوية' : 'سبب طلب الصلاحية');
      if (reason == null || !mounted) return;
      final from = DateTime.now().toUtc().toIso8601String();
      if (membership) {
        await widget.api.requestAuthorityMembership(
          authorityId: authorityId, roleCode: code, reason: reason, validFrom: from,
        );
      } else {
        await widget.api.requestAuthorityPermissionGrant(
          authorityId: authorityId, permissionCode: code, reason: reason, validFrom: from,
        );
      }
      _refreshQueues();
      if (mounted) setState(() => _feedback = 'أُرسل الطلب إلى الخادم للمراجعة.');
    } on MetraApiException catch (e) {
      if (mounted) setState(() => _error = _apiError(e.statusCode));
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر إرسال الطلب.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _act(Map<String, dynamic> row, {
    required bool membership,
    required bool active,
    required String decision,
  }) async {
    final authorityId = _authorityId;
    final id = row['id']?.toString() ?? '';
    if (_busy || authorityId == null || id.isEmpty) return;
    final reason = await _reason(active ? 'سبب إلغاء الوصول' :
      decision == 'approve' ? 'سبب اعتماد الطلب' : 'سبب رفض الطلب');
    if (reason == null || !mounted) return;
    setState(() { _busy = true; _error = null; _feedback = null; });
    try {
      if (active) {
        if (membership) {
          await widget.api.revokeAuthorityMembership(authorityId: authorityId, membershipId: id, reason: reason);
        } else {
          await widget.api.revokeAuthorityPermissionGrant(authorityId: authorityId, grantId: id, reason: reason);
        }
      } else if (membership) {
        await widget.api.decideAuthorityMembership(authorityId: authorityId, membershipId: id, decision: decision, reason: reason);
      } else {
        await widget.api.decideAuthorityPermissionGrant(authorityId: authorityId, grantId: id, decision: decision, reason: reason);
      }
      _refreshQueues();
      if (mounted) setState(() => _feedback = active ? 'تم إلغاء الوصول عبر الخادم.' : 'تم تسجيل قرار المراجعة عبر الخادم.');
    } on MetraApiException catch (e) {
      if (mounted) setState(() => _error = _apiError(e.statusCode));
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر تنفيذ الإجراء.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _queue(Future<List<Map<String, dynamic>>>? future, {
    required String title,
    required bool membership,
    required bool active,
  }) {
    if (future == null) return const Text('اختر جهة أولاً.');
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Padding(padding: const EdgeInsets.all(12), child: Text('تعذر تحميل $title أو لا توجد صلاحية لهذا النطاق.'));
        }
        final rows = snapshot.data ?? const <Map<String, dynamic>>[];
        if (rows.isEmpty) return Padding(padding: const EdgeInsets.all(12), child: Text('لا توجد سجلات في $title.'));
        return Column(children: rows.map((row) {
          final code = membership ? row['role_code'] : row['permission_code'];
          final reason = row['reason']?.toString() ?? '';
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(code?.toString() ?? 'غير محدد', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('المستخدم: ${_shortId(row['user_id'])}'),
                Text('الحالة: ${row['status'] ?? 'غير محددة'}'),
                Text('بداية السريان: ${_utc(row['valid_from'])}'),
                Text('نهاية السريان: ${row['valid_to'] == null ? 'مفتوح' : _utc(row['valid_to'])}'),
                if (reason.isNotEmpty) Text('السبب: $reason'),
                if (active)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: _busy ? null : () => _act(row, membership: membership, active: true, decision: ''),
                      icon: const Icon(Icons.block), label: const Text('إلغاء'),
                    ),
                  )
                else
                  Wrap(spacing: 8, children: [
                    TextButton(
                      onPressed: _busy ? null : () => _act(row, membership: membership, active: false, decision: 'approve'),
                      child: const Text('اعتماد'),
                    ),
                    TextButton(
                      onPressed: _busy ? null : () => _act(row, membership: membership, active: false, decision: 'reject'),
                      child: const Text('رفض'),
                    ),
                  ]),
              ]),
            ),
          );
        }).toList());
      },
    );
  }

  Widget _auditPanel() {
    final future = _audit;
    if (future == null) return const Center(child: Text('اختر جهة لعرض سجل التدقيق.'));
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return const Center(child: Text('تعذر تحميل سجل التدقيق أو لا توجد صلاحية.'));
        final rows = snapshot.data ?? const <Map<String, dynamic>>[];
        if (rows.isEmpty) return const Center(child: Text('لا توجد أحداث تدقيق لهذه الجهة.'));
        return ListView.separated(
          padding: const EdgeInsets.all(12), itemCount: rows.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final row = rows[i];
            return Card(child: ListTile(
              title: Text('${row['target_kind'] ?? ''} · ${row['action_code'] ?? ''}'),
              subtitle: Text(
                'صاحب الطلب: ${_shortId(row['subject_user_id'])}\n'
                'المنفذ: ${_shortId(row['actor_user_id'])}\n'
                'الوقت: ${_utc(row['occurred_at'])}\n'
                'السبب: ${row['reason'] ?? ''}',
              ),
            ));
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('إدارة العضويات والصلاحيات'),
            actions: [
              IconButton(tooltip: 'تحديث', onPressed: _busy ? null : _loadAuthorities, icon: const Icon(Icons.refresh)),
            ],
            bottom: const TabBar(isScrollable: true, tabs: [
              Tab(text: 'العضويات'), Tab(text: 'الصلاحيات'), Tab(text: 'سجل التدقيق'),
            ]),
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : _authorities.isEmpty
                  ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error ?? 'لا توجد جهات فعالة متاحة.')))
                  : Column(children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: DropdownButtonFormField<String>(
                          initialValue: _authorityId, isExpanded: true,
                          decoration: const InputDecoration(labelText: 'الجهة', border: OutlineInputBorder()),
                          items: _authorities.map((row) => DropdownMenuItem<String>(
                            value: row['id']?.toString() ?? '',
                            child: Text((row['name_ar'] ?? row['authority_code'] ?? 'جهة').toString()),
                          )).where((item) => item.value?.isNotEmpty == true).toList(),
                          onChanged: _busy ? null : (value) {
                            if (value == null) return;
                            setState(() => _authorityId = value);
                            _refreshQueues();
                          },
                        ),
                      ),
                      if (_error != null) Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Text(_error!, style: const TextStyle(color: Colors.red)),
                      ),
                      if (_feedback != null) Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Text(_feedback!, style: const TextStyle(color: Colors.green)),
                      ),
                      Wrap(spacing: 8, children: [
                        OutlinedButton.icon(
                          onPressed: _busy ? null : () => _request(true),
                          icon: const Icon(Icons.group_add_outlined), label: const Text('طلب عضوية لنفسي'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _busy ? null : () => _request(false),
                          icon: const Icon(Icons.security_outlined), label: const Text('طلب صلاحية'),
                        ),
                      ]),
                      Expanded(child: TabBarView(children: [
                        ListView(padding: const EdgeInsets.all(12), children: [
                          const Text('طلبات العضوية المعلقة', style: TextStyle(fontWeight: FontWeight.bold)),
                          _queue(_pendingMemberships, title: 'طلبات العضوية', membership: true, active: false),
                          const Divider(height: 28),
                          const Text('العضويات السارية أو المجدولة', style: TextStyle(fontWeight: FontWeight.bold)),
                          _queue(_activeMemberships, title: 'العضويات السارية', membership: true, active: true),
                        ]),
                        ListView(padding: const EdgeInsets.all(12), children: [
                          const Text('طلبات الصلاحيات المعلقة', style: TextStyle(fontWeight: FontWeight.bold)),
                          _queue(_pendingGrants, title: 'طلبات الصلاحيات', membership: false, active: false),
                          const Divider(height: 28),
                          const Text('منح الصلاحيات السارية أو المجدولة', style: TextStyle(fontWeight: FontWeight.bold)),
                          _queue(_activeGrants, title: 'منح الصلاحيات السارية', membership: false, active: true),
                        ]),
                        _auditPanel(),
                      ])),
                    ]),
        ),
      ),
    );
  }
}


class _AuthorityReasonDialog extends StatefulWidget {
  const _AuthorityReasonDialog({required this.title});

  final String title;

  @override
  State<_AuthorityReasonDialog> createState() => _AuthorityReasonDialogState();
}

class _AuthorityReasonDialogState extends State<_AuthorityReasonDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _controller,
      autofocus: true,
      maxLength: 2000,
      maxLines: 3,
      onChanged: (_) => setState(() {}),
      decoration: const InputDecoration(labelText: 'السبب (5 أحرف على الأقل)'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('إلغاء'),
      ),
      FilledButton(
        onPressed: _controller.text.trim().length < 5
            ? null
            : () => Navigator.of(context).pop(_controller.text.trim()),
        child: const Text('تأكيد'),
      ),
    ],
  );
}
