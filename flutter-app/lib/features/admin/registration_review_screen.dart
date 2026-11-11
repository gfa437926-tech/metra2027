import 'package:flutter/material.dart';

import '../../core/api/metra_api_client.dart';
import 'admin_api_messages.dart';

/// Station or system stage registration queue with approve/reject against live API.
class RegistrationReviewScreen extends StatefulWidget {
  const RegistrationReviewScreen({
    super.key,
    required this.api,
    required this.stationId,
  });

  final MetraApiClient api;
  final String stationId;

  @override
  State<RegistrationReviewScreen> createState() => _RegistrationReviewScreenState();
}

class _RegistrationReviewScreenState extends State<RegistrationReviewScreen> {
  bool _systemStage = false;
  late Future<List<Map<String, dynamic>>> _rows;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _rows = widget.api.listRegistrationRequests(widget.stationId);
  }

  void _reload() {
    setState(() {
      _error = null;
      _rows = widget.api.listRegistrationRequests(
        widget.stationId,
        systemStage: _systemStage,
      );
    });
  }

  String? _requestId(Map<String, dynamic> row) {
    final value = row['id'] ?? row['request_id'] ?? row['requestId'];
    final id = value?.toString().trim();
    return id == null || id.isEmpty ? null : id;
  }

  String _requester(Map<String, dynamic> row) {
    final name = [
      row['first_name'] ?? row['firstName'],
      row['father_name'] ?? row['fatherName'],
      row['last_name'] ?? row['lastName'],
    ].where((part) => part != null && part.toString().trim().isNotEmpty)
        .map((part) => part.toString().trim()).join(' ');
    return name.isEmpty
        ? (row['email'] ?? row['user_email'] ?? row['userEmail'] ?? 'مستخدم غير مسمى').toString()
        : name;
  }

  String _role(Map<String, dynamic> row) =>
      (row['requested_role_name_ar'] ??
       row['requestedRoleNameAr'] ??
       row['requested_role_code'] ??
       row['requestedRoleCode'] ??
       '—').toString();

  String _submittedAt(Map<String, dynamic> row) {
    final raw = (row['submitted_at'] ?? row['submittedAt'] ?? '').toString();
    final parsed = DateTime.tryParse(raw);
    return parsed == null ? (raw.isEmpty ? 'وقت الإرسال غير متوفر' : raw)
        : parsed.toUtc().toIso8601String();
  }

  Future<String?> _rejectionNote() {
    return showDialog<String>(
      context: context,
      builder: (_) => const _RegistrationRejectionDialog(),
    );
  }

  Future<void> _decide(String requestId, String decision, {String? note}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.decideRegistrationRequest(
        stationId: widget.stationId,
        requestId: requestId,
        decision: decision,
        note: note,
        systemStage: _systemStage,
      );
      if (mounted) _reload();
    } on MetraApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = adminRegistrationDecisionError(e.statusCode);
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'فشل الاتصال أثناء اتخاذ القرار.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handleDecision(Map<String, dynamic> row, String decision) async {
    final requestId = _requestId(row);
    if (requestId == null || _busy) return;
    String? note;
    if (decision == 'reject') {
      note = await _rejectionNote();
      if (note == null || note.length < 3 || !mounted) return;
    }
    await _decide(requestId, decision, note: note);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('مراجعة طلبات التسجيل'),
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
              color: Color(0xFFEEF6FA),
              child: ListTile(
                title: Text('صلاحيات الخادم'),
                subtitle: Text(
                  'القرار يمر عبر API مع عزل المحطة. لا يمكن اعتماد طلب لمحطة أخرى.',
                ),
              ),
            ),
            SwitchListTile(
              title: const Text('مرحلة اعتماد النظام'),
              subtitle: const Text('عند الإيقاف: مرحلة اعتماد المحطة'),
              value: _systemStage,
              onChanged: _busy
                  ? null
                  : (value) {
                      setState(() => _systemStage = value);
                      _reload();
                    },
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Color(0xFF8A1F2D))),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _rows,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return const Text('تعذر تحميل الطابور أو لا صلاحية.');
                }
                final rows = snapshot.data ?? const <Map<String, dynamic>>[];
                if (rows.isEmpty) {
                  return const Text('لا طلبات معلّقة في هذه المرحلة لهذه المحطة.');
                }
                return Column(
                  children: [
                    for (final row in rows)
                      Card(
                        child: ListTile(
                          title: Text(_requester(row)),
                          subtitle: Text(
                            'الدور: ${_role(row)}\n'
                            'الحالة: ${row['status'] ?? '—'}\n'
                            'أُرسل UTC: ${_submittedAt(row)}\n'
                            'معرّف الطلب: ${_requestId(row) ?? 'غير متوفر'}',
                          ),
                          isThreeLine: true,
                          trailing: _busy
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Wrap(
                                  spacing: 4,
                                  children: [
                                    TextButton(
                                      onPressed: _requestId(row) == null
                                          ? null
                                          : () => _handleDecision(row, 'approve'),
                                      child: const Text('اعتماد'),
                                    ),
                                    TextButton(
                                      onPressed: _requestId(row) == null
                                          ? null
                                          : () => _handleDecision(row, 'reject'),
                                      child: const Text('رفض'),
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


class _RegistrationRejectionDialog extends StatefulWidget {
  const _RegistrationRejectionDialog();

  @override
  State<_RegistrationRejectionDialog> createState() =>
      _RegistrationRejectionDialogState();
}

class _RegistrationRejectionDialogState
    extends State<_RegistrationRejectionDialog> {
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
          title: const Text('سبب رفض طلب التسجيل'),
          content: TextField(
            controller: _controller,
            autofocus: true,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'سبب واضح للرفض',
              hintText: 'سيظهر السبب لصاحب الطلب وفق صلاحيات النظام',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                final value = _controller.text.trim();
                if (value.length >= 3) {
                  Navigator.of(context).pop(value);
                }
              },
              child: const Text('تأكيد الرفض'),
            ),
          ],
        ),
      );
}
