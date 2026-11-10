import 'package:flutter/material.dart';

import '../../core/api/metra_api_client.dart';

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
    _reload();
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

  Future<void> _decide(String requestId, String decision) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.decideRegistrationRequest(
        stationId: widget.stationId,
        requestId: requestId,
        decision: decision,
        systemStage: _systemStage,
      );
      if (mounted) {
        _reload();
      }
    } on MetraApiException catch (e) {
      setState(() {
        _error = switch (e.statusCode) {
          403 => 'رفض الخادم القرار: لا صلاحية أو محاولة مراجعة ذاتية.',
          404 => 'الطلب غير موجود لهذه المحطة.',
          409 => 'تعارض حالة الطلب.',
          _ => 'فشل القرار (HTTP ${e.statusCode}).',
        };
      });
    } catch (_) {
      setState(() => _error = 'فشل الاتصال أثناء اتخاذ القرار.');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  String _label(Map<String, dynamic> row) {
    final Object? role = row['requested_role_code'] ?? row['requestedRoleCode'];
    final Object? status = row['status'];
    final Object? submitted = row['submitted_at'] ?? row['submittedAt'];
    return '${role ?? '—'} · ${status ?? '—'} · ${submitted ?? ''}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مراجعة طلبات التسجيل'),
        actions: <Widget>[
          IconButton(onPressed: _busy ? null : _reload, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
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
                : (bool value) {
                    setState(() => _systemStage = value);
                    _reload();
                  },
          ),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Color(0xFF8A1F2D))),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _rows,
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
                return const Text('تعذر تحميل الطابور أو لا صلاحية.');
              }
              final List<Map<String, dynamic>> rows =
                  snapshot.data ?? const <Map<String, dynamic>>[];
              if (rows.isEmpty) {
                return const Text('لا طلبات معلّقة في هذه المرحلة لهذه المحطة.');
              }
              return Column(
                children: <Widget>[
                  for (final Map<String, dynamic> row in rows)
                    Card(
                      child: ListTile(
                        title: Text(_label(row)),
                        subtitle: Text(
                          'request: ${row['id'] ?? row['request_id'] ?? '—'}',
                        ),
                        trailing: _busy
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Wrap(
                                spacing: 4,
                                children: <Widget>[
                                  TextButton(
                                    onPressed: () {
                                      final Object? id = row['id'];
                                      if (id != null) {
                                        _decide(id.toString(), 'approve');
                                      }
                                    },
                                    child: const Text('اعتماد'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      final Object? id = row['id'];
                                      if (id != null) {
                                        _decide(id.toString(), 'reject');
                                      }
                                    },
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
    );
  }
}
