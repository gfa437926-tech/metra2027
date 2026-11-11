import 'package:flutter/material.dart';

import '../../core/api/metra_api_client.dart';

/// Requests and decisions are submitted to the station-scoped API.
class StationAssignmentScreen extends StatefulWidget {
  const StationAssignmentScreen({
    super.key,
    required this.api,
    required this.stationId,
  });

  final MetraApiClient api;
  final String stationId;

  @override
  State<StationAssignmentScreen> createState() => _StationAssignmentScreenState();
}

class _StationAssignmentScreenState extends State<StationAssignmentScreen> {
  late Future<List<Map<String, dynamic>>> _users;
  late Future<List<Map<String, dynamic>>> _roles;
  final TextEditingController _userIdCtrl = TextEditingController();
  final TextEditingController _reasonCtrl = TextEditingController();
  String _roleCode = '';
  bool _busy = false;
  String? _error;
  String? _feedback;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _userIdCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  String _roleCodeOf(Map<String, dynamic> role) =>
      (role['role_code'] ?? role['roleCode'] ?? '').toString().trim();

  void _load() {
    _error = null;
    _users = widget.api.listStationUsers(widget.stationId);
    _roles = widget.api.listAssignableRoles(widget.stationId).then((roles) {
      final codes = roles.map(_roleCodeOf).where((code) => code.isNotEmpty).toList();
      if (mounted && codes.isNotEmpty && !codes.contains(_roleCode)) {
        setState(() => _roleCode = codes.first);
      }
      return roles;
    });
    if (mounted) setState(() {});
  }

  void _reload() {
    setState(() {
      _error = null;
      _feedback = null;
      _load();
    });
  }

  Future<String?> _askReason({
    required String title,
    required String confirmLabel,
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => _StationAssignmentReasonDialog(
        title: title,
        confirmLabel: confirmLabel,
      ),
    );
  }

  Future<void> _request() async {
    if (_busy ||
        _userIdCtrl.text.trim().isEmpty ||
        _roleCode.isEmpty ||
        _reasonCtrl.text.trim().length < 3) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _feedback = null;
    });
    try {
      await widget.api.requestStationAssignment(
        stationId: widget.stationId,
        userId: _userIdCtrl.text.trim(),
        roleCode: _roleCode,
        reason: _reasonCtrl.text.trim(),
        validFrom: DateTime.now().toUtc().toIso8601String(),
      );
      if (mounted) {
        setState(() => _feedback = 'أُرسل طلب التعيين إلى الخادم.');
        _reload();
      }
    } on MetraApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = switch (e.statusCode) {
            400 => 'بيانات طلب التعيين غير صالحة.',
            403 => 'لا صلاحية لإدارة تعيينات هذه المحطة.',
            409 => 'تعارض في طلب التعيين أو يوجد تعيين متداخل.',
            _ => 'فشل الطلب (HTTP ${e.statusCode}).',
          };
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'فشل إرسال طلب التعيين.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _decide(
    String assignmentId,
    String decision, {
    String? note,
  }) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.decideStationAssignment(
        stationId: widget.stationId,
        assignmentId: assignmentId,
        decision: decision,
        note: note,
      );
      if (mounted) _reload();
    } on MetraApiException catch (e) {
      if (mounted) {
        setState(() => _error = switch (e.statusCode) {
          403 => 'لا صلاحية لاتخاذ قرار التعيين.',
          404 => 'طلب التعيين غير موجود لهذه المحطة.',
          409 => 'تعارض في حالة طلب التعيين.',
          _ => 'فشل القرار (HTTP ${e.statusCode}).',
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'فشل قرار التعيين.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handleDecision(String assignmentId, String decision) async {
    if (_busy) return;
    String? note;
    if (decision == 'reject') {
      note = await _askReason(
        title: 'سبب رفض التعيين',
        confirmLabel: 'تأكيد الرفض',
      );
      if (note == null || note.length < 3 || !mounted) return;
    }
    await _decide(assignmentId, decision, note: note);
  }

  Future<void> _revoke(String assignmentId) async {
    if (_busy) return;
    final reason = await _askReason(
      title: 'سبب إلغاء التعيين',
      confirmLabel: 'تأكيد الإلغاء',
    );
    if (reason == null || reason.length < 3 || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
      _feedback = null;
    });
    try {
      await widget.api.revokeStationAssignment(
        stationId: widget.stationId,
        assignmentId: assignmentId,
        reason: reason,
      );
      if (mounted) {
        setState(() => _feedback = 'سُجل طلب إلغاء التعيين لدى الخادم.');
        _reload();
      }
    } on MetraApiException catch (e) {
      if (mounted) {
        setState(() => _error = switch (e.statusCode) {
          403 => 'لا صلاحية لإلغاء هذا التعيين.',
          404 => 'التعيين غير موجود لهذه المحطة.',
          409 => 'لا يمكن إلغاء التعيين في حالته الحالية.',
          _ => 'فشل الإلغاء (HTTP ${e.statusCode}).',
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'فشل إلغاء التعيين.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _isPending(Map<String, dynamic> row) {
    final status = '${row['status'] ?? row['assignment_status'] ?? ''}'.toLowerCase();
    return status.contains('pending') ||
        status.contains('requested') ||
        status.contains('await') ||
        status == 'submitted';
  }

  bool _isActive(Map<String, dynamic> row) {
    final status = '${row['status'] ?? row['assignment_status'] ?? ''}'.toLowerCase();
    return status == 'active' || status == 'approved' || status == 'assigned';
  }

  String? _assignmentId(Map<String, dynamic> row) {
    final value = row['assignment_id'] ?? row['assignmentId'] ?? row['id'];
    final id = value?.toString().trim();
    return id == null || id.isEmpty ? null : id;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تعيينات المحطة'),
          actions: [
            IconButton(
              onPressed: _busy ? null : _reload,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Card(
              color: Color(0xFFFFF7E8),
              child: ListTile(
                title: Text('إدارة ضمن نطاق المحطة'),
                subtitle: Text('الطلبات والقرارات على API فقط. جميع أوقات السريان UTC.'),
              ),
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Color(0xFF8A1F2D))),
            if (_feedback != null)
              Text(_feedback!, style: const TextStyle(color: Color(0xFF1F6B3C))),
            TextField(
              controller: _userIdCtrl,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'معرّف المستخدم (UUID)'),
            ),
            const SizedBox(height: 8),
            const Text('الدور القابل للتعيين من الخادم'),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _roles,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LinearProgressIndicator();
                }
                if (snapshot.hasError) {
                  return const Text('تعذر تحميل الأدوار القابلة للتعيين.');
                }
                final roles = snapshot.data ?? const <Map<String, dynamic>>[];
                if (roles.isEmpty) {
                  return const Text('لا توجد أدوار قابلة للتعيين لهذه المحطة.');
                }
                return Wrap(
                  spacing: 8,
                  children: [
                    for (final role in roles)
                      if (_roleCodeOf(role).isNotEmpty)
                        ChoiceChip(
                          label: Text(
                            '${role['name_ar'] ?? role['nameAr'] ?? _roleCodeOf(role)}',
                          ),
                          selected: _roleCode == _roleCodeOf(role),
                          onSelected: _busy
                              ? null
                              : (selected) {
                                  if (selected) {
                                    setState(() => _roleCode = _roleCodeOf(role));
                                  }
                                },
                        ),
                  ],
                );
              },
            ),
            TextField(
              controller: _reasonCtrl,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'سبب الطلب'),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _busy ||
                      _userIdCtrl.text.trim().isEmpty ||
                      _roleCode.isEmpty ||
                      _reasonCtrl.text.trim().length < 3
                  ? null
                  : _request,
              child: Text(_busy ? 'جارٍ الإرسال...' : 'طلب تعيين'),
            ),
            const SizedBox(height: 16),
            const Text('مستخدمو المحطة', style: TextStyle(fontWeight: FontWeight.bold)),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _users,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return const Text('تعذر تحميل المستخدمين أو لا صلاحية.');
                }
                final rows = snapshot.data ?? const <Map<String, dynamic>>[];
                if (rows.isEmpty) {
                  return const Text('لا مستخدمين معروضين لهذه المحطة.');
                }
                return Column(
                  children: [
                    for (final row in rows)
                      Card(
                        child: ListTile(
                          title: Text(
                            '${row['user_id'] ?? row['userId'] ?? row['id'] ?? '—'}',
                          ),
                          subtitle: Text(
                            '${row['role_code'] ?? row['roleCode'] ?? ''} · '
                            '${row['status'] ?? row['assignment_status'] ?? '—'}',
                          ),
                          trailing: _busy
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Wrap(
                                  children: [
                                    if (_isPending(row) && _assignmentId(row) != null) ...[
                                      TextButton(
                                        onPressed: () => _handleDecision(
                                          _assignmentId(row)!,
                                          'approve',
                                        ),
                                        child: const Text('اعتماد'),
                                      ),
                                      TextButton(
                                        onPressed: () => _handleDecision(
                                          _assignmentId(row)!,
                                          'reject',
                                        ),
                                        child: const Text('رفض'),
                                      ),
                                    ],
                                    if (_isActive(row) && _assignmentId(row) != null)
                                      TextButton(
                                        onPressed: () => _revoke(_assignmentId(row)!),
                                        child: const Text('إلغاء'),
                                      ),
                                  ],
                                ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}


class _StationAssignmentReasonDialog extends StatefulWidget {
  const _StationAssignmentReasonDialog({
    required this.title,
    required this.confirmLabel,
  });

  final String title;
  final String confirmLabel;

  @override
  State<_StationAssignmentReasonDialog> createState() =>
      _StationAssignmentReasonDialogState();
}

class _StationAssignmentReasonDialogState
    extends State<_StationAssignmentReasonDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(widget.title),
          content: TextField(
            controller: _controller,
            autofocus: true,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'السبب (3 أحرف على الأقل)',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('رجوع'),
            ),
            FilledButton(
              onPressed: () {
                final reason = _controller.text.trim();
                if (reason.length >= 3) {
                  Navigator.of(context).pop(reason);
                }
              },
              child: Text(widget.confirmLabel),
            ),
          ],
        ),
      );
}
