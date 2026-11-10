import 'package:flutter/material.dart';

import '../../core/api/metra_api_client.dart';

/// Request station role assignments and act on pending assignment rows via API.
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
  String _roleCode = 'observer';
  bool _busy = false;
  String? _error;
  String? _feedback;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _userIdCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _error = null;
      _users = widget.api.listStationUsers(widget.stationId);
      _roles = widget.api.listAssignableRoles(widget.stationId);
    });
  }

  Future<void> _request() async {
    setState(() {
      _busy = true;
      _error = null;
      _feedback = null;
    });
    try {
      final String validFrom = DateTime.now().toUtc().toIso8601String();
      await widget.api.requestStationAssignment(
        stationId: widget.stationId,
        userId: _userIdCtrl.text.trim(),
        roleCode: _roleCode,
        reason: _reasonCtrl.text.trim(),
        validFrom: validFrom,
      );
      if (mounted) {
        setState(() => _feedback = 'أُرسل طلب التعيين إلى الخادم.');
        _reload();
      }
    } on MetraApiException catch (e) {
      setState(() {
        _error = switch (e.statusCode) {
          403 => 'لا صلاحية لإدارة تعيينات هذه المحطة.',
          409 => 'تعارض في طلب التعيين.',
          _ => 'فشل الطلب (HTTP ${e.statusCode}).',
        };
      });
    } catch (_) {
      setState(() => _error = 'فشل إرسال طلب التعيين.');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _decide(String assignmentId, String decision) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.decideStationAssignment(
        stationId: widget.stationId,
        assignmentId: assignmentId,
        decision: decision,
      );
      if (mounted) {
        _reload();
      }
    } on MetraApiException catch (e) {
      setState(() => _error = 'فشل القرار (HTTP ${e.statusCode}).');
    } catch (_) {
      setState(() => _error = 'فشل قرار التعيين.');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _revoke(String assignmentId) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.revokeStationAssignment(
        stationId: widget.stationId,
        assignmentId: assignmentId,
        reason: 'revoked_from_mobile_admin',
      );
      if (mounted) {
        _reload();
      }
    } on MetraApiException catch (e) {
      setState(() => _error = 'فشل الإلغاء (HTTP ${e.statusCode}).');
    } catch (_) {
      setState(() => _error = 'فشل إلغاء التعيين.');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  bool _isPending(Map<String, dynamic> row) {
    final String status = '${row['status'] ?? row['assignment_status'] ?? ''}'.toLowerCase();
    return status.contains('pending') ||
        status.contains('requested') ||
        status.contains('await') ||
        status == 'submitted';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تعيينات المحطة'),
        actions: <Widget>[
          IconButton(onPressed: _busy ? null : _reload, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const Card(
            color: Color(0xFFFFF7E8),
            child: ListTile(
              title: Text('إدارة ضمن نطاق المحطة'),
              subtitle: Text('الطلبات والقرارات على API فقط. UTC لتاريخ السريان.'),
            ),
          ),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Color(0xFF8A1F2D))),
          if (_feedback != null)
            Text(_feedback!, style: const TextStyle(color: Color(0xFF1F6B3C))),
          TextField(
            controller: _userIdCtrl,
            decoration: const InputDecoration(
              labelText: 'معرّف المستخدم (UUID)',
            ),
          ),
          const Text('الدور'),
          Wrap(
            spacing: 8,
            children: <Widget>[
              ChoiceChip(
                label: const Text('راصد'),
                selected: _roleCode == 'observer',
                onSelected: (bool selected) {
                  if (selected) {
                    setState(() => _roleCode = 'observer');
                  }
                },
              ),
              ChoiceChip(
                label: const Text('مدقق محطة'),
                selected: _roleCode == 'station_auditor',
                onSelected: (bool selected) {
                  if (selected) {
                    setState(() => _roleCode = 'station_auditor');
                  }
                },
              ),
            ],
          ),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _roles,
            builder: (
              BuildContext context,
              AsyncSnapshot<List<Map<String, dynamic>>> snapshot,
            ) {
              final List<Map<String, dynamic>> roles =
                  snapshot.data ?? const <Map<String, dynamic>>[];
              if (roles.isEmpty) {
                return const SizedBox.shrink();
              }
              return Wrap(
                spacing: 8,
                children: <Widget>[
                  for (final Map<String, dynamic> role in roles)
                    ChoiceChip(
                      label: Text(
                        '${role['name_ar'] ?? role['nameAr'] ?? role['role_code'] ?? role['roleCode']}',
                      ),
                      selected: _roleCode ==
                          '${role['role_code'] ?? role['roleCode']}',
                      onSelected: (bool selected) {
                        if (selected) {
                          setState(() {
                            _roleCode =
                                '${role['role_code'] ?? role['roleCode']}';
                          });
                        }
                      },
                    ),
                ],
              );
            },
          ),
          TextField(
            controller: _reasonCtrl,
            decoration: const InputDecoration(labelText: 'سبب الطلب'),
            maxLines: 2,
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _busy ||
                    _userIdCtrl.text.trim().isEmpty ||
                    _reasonCtrl.text.trim().length < 3
                ? null
                : _request,
            child: Text(_busy ? 'جارٍ الإرسال...' : 'طلب تعيين'),
          ),
          const SizedBox(height: 16),
          const Text('مستخدمو المحطة', style: TextStyle(fontWeight: FontWeight.bold)),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _users,
            builder: (
              BuildContext context,
              AsyncSnapshot<List<Map<String, dynamic>>> snapshot,
            ) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return const Text('تعذر تحميل المستخدمين أو لا صلاحية.');
              }
              final List<Map<String, dynamic>> rows =
                  snapshot.data ?? const <Map<String, dynamic>>[];
              if (rows.isEmpty) {
                return const Text('لا مستخدمين معروضين لهذه المحطة.');
              }
              return Column(
                children: <Widget>[
                  for (final Map<String, dynamic> row in rows)
                    Card(
                      child: ListTile(
                        title: Text(
                          '${row['user_id'] ?? row['userId'] ?? row['id'] ?? '—'}',
                        ),
                        subtitle: Text(
                          '${row['role_code'] ?? row['roleCode'] ?? ''} · ${row['status'] ?? ''}',
                        ),
                        trailing: _busy
                            ? null
                            : Wrap(
                                children: <Widget>[
                                  if (_isPending(row))
                                    TextButton(
                                      onPressed: () {
                                        final Object? id =
                                            row['assignment_id'] ?? row['id'];
                                        if (id != null) {
                                          _decide(id.toString(), 'approve');
                                        }
                                      },
                                      child: const Text('اعتماد'),
                                    ),
                                  if (_isPending(row))
                                    TextButton(
                                      onPressed: () {
                                        final Object? id =
                                            row['assignment_id'] ?? row['id'];
                                        if (id != null) {
                                          _decide(id.toString(), 'reject');
                                        }
                                      },
                                      child: const Text('رفض'),
                                    ),
                                  TextButton(
                                    onPressed: () {
                                      final Object? id =
                                          row['assignment_id'] ?? row['id'];
                                      if (id != null) {
                                        _revoke(id.toString());
                                      }
                                    },
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
    );
  }
}
