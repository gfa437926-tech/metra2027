import 'dart:convert';

// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../../core/api/metra_api_client.dart';

class ObservationArchiveScreen extends StatefulWidget {
  const ObservationArchiveScreen({
    super.key,
    required this.api,
    required this.stationId,
  });

  final MetraApiClient api;
  final String? stationId;

  @override
  State<ObservationArchiveScreen> createState() => _ObservationArchiveScreenState();
}

class _ObservationArchiveScreenState extends State<ObservationArchiveScreen> {
  static const _pageSize = 50;
  static const _types = <String, String>{
    '': 'كل أنواع الرصد',
    'hourly': 'رصد ساعي',
    'daily': 'رصد يومي',
    'climate': 'بيانات مناخية',
    'soil': 'رصد التربة',
    'agricultural': 'رصد زراعي',
    'phenomenon': 'ظواهر جوية',
    'fieldclimate': 'مناخ حقلي',
  };

  ObservationArchivePage? _page;
  String? _selectedType;
  DateTime? _fromUtc;
  DateTime? _toUtc;
  String? _error;
  bool _loading = false;
  bool _loadingMore = false;
  int _requestGeneration = 0;

  @override
  void initState() {
    super.initState();
    if (widget.stationId != null) {
      _load();
    }
  }

  @override
  void didUpdateWidget(covariant ObservationArchiveScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stationId != widget.stationId) {
      // Invalidate any in-flight response before switching the station. A
      // previous station's response must never be rendered under the new scope.
      _requestGeneration++;
      _page = null;
      _error = null;
      if (widget.stationId != null) {
        _load();
      } else {
        _loading = false;
        _loadingMore = false;
      }
    }
  }

  Future<void> _load({bool append = false}) async {
    final stationId = widget.stationId;
    if (stationId == null) return;
    final requestGeneration = ++_requestGeneration;
    setState(() {
      if (append) {
        _loadingMore = true;
      } else {
        _loading = true;
        _error = null;
      }
    });
    try {
      final next = await widget.api.getObservationArchive(
        stationId,
        observationType: _selectedType,
        fromUtc: _fromUtc,
        toUtc: _toUtc,
        limit: _pageSize,
        cursor: append ? _page?.nextCursor : null,
      );
      if (!mounted || requestGeneration != _requestGeneration) return;
      setState(() {
        _page = append && _page != null
            ? ObservationArchivePage(
                items: [..._page!.items, ...next.items],
                hasMore: next.hasMore,
                nextCursor: next.nextCursor,
              )
            : next;
        _error = null;
      });
    } on MetraApiException catch (error) {
      if (!mounted || requestGeneration != _requestGeneration) return;
      setState(() => _error = switch (error.statusCode) {
        401 => 'انتهت الجلسة أو يلزم تسجيل الدخول.',
        403 => 'لا يملك حسابك صلاحية قراءة أرشيف هذه المحطة.',
        404 => 'لم يتم العثور على المحطة أو السجل المطلوب.',
        503 => 'خدمة الأرشيف غير متاحة حالياً. حاول لاحقاً.',
        _ => 'تعذر تحميل الأرشيف (رمز ${error.statusCode}).',
      });
    } catch (_) {
      if (!mounted || requestGeneration != _requestGeneration) return;
      setState(() => _error = 'تعذر قراءة بيانات الأرشيف. تحقق من الاتصال ثم أعد المحاولة.');
    } finally {
      if (mounted && requestGeneration == _requestGeneration) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.stationId == null) {
      return const _ArchiveMessage(
        icon: Icons.location_on_outlined,
        title: 'اختر محطة أولاً',
        message: 'افتح دليل المحطات وحدد المحطة التي تريد استعراض أرشيفها. سيطبق الخادم صلاحيات حسابك على المحطة المختارة.',
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text('الأرشيف التاريخي للرصدات',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                IconButton(
                  tooltip: 'تحديث',
                  onPressed: _loading || _loadingMore ? null : () => _load(),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loading ? null : _pickFromDate,
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    label: Text(_fromUtc == null ? 'من تاريخ' : 'من ${_formatDate(_fromUtc!)}'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loading ? null : _pickToDate,
                    icon: const Icon(Icons.event_outlined, size: 18),
                    label: Text(_toUtc == null ? 'حتى تاريخ' : 'حتى ${_formatDate(_toUtc!.subtract(const Duration(days: 1)))}'),
                  ),
                ),
                IconButton(
                  tooltip: 'مسح التاريخ',
                  onPressed: _loading || (_fromUtc == null && _toUtc == null)
                      ? null
                      : () {
                          setState(() {
                            _fromUtc = null;
                            _toUtc = null;
                            _page = null;
                          });
                          _load();
                        },
                  icon: const Icon(Icons.clear),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: DropdownButtonFormField<String>(
              initialValue: _selectedType ?? '',
              decoration: const InputDecoration(
                labelText: 'نوع الرصد',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: _types.entries.map((entry) => DropdownMenuItem(
                value: entry.key,
                child: Text(entry.value),
              )).toList(),
              onChanged: _loading ? null : (value) {
                setState(() {
                  _selectedType = value == null || value.isEmpty ? null : value;
                  _page = null;
                });
                _load();
              },
            ),
          ),
          if (_loading && _page == null)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_error != null && _page == null)
            Expanded(child: _ArchiveMessage(
              icon: Icons.cloud_off_outlined,
              title: 'تعذر تحميل الأرشيف',
              message: _error!,
              action: FilledButton.tonalIcon(
                onPressed: () => _load(),
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ))
          else if (_page?.items.isEmpty ?? true)
            const Expanded(child: _ArchiveMessage(
              icon: Icons.inventory_2_outlined,
              title: 'لا توجد سجلات مطابقة',
              message: 'لا توجد سجلات أرشيف مرتبطة بهذه المحطة وفق المرشحات المحددة.',
            ))
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _load(),
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _page!.items.length + (_page!.hasMore ? 1 : 0),
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    if (_page!.hasMore && index == _page!.items.length) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: _loadingMore
                              ? const CircularProgressIndicator()
                              : OutlinedButton(
                                  onPressed: () => _load(append: true),
                                  child: const Text('تحميل المزيد'),
                                ),
                        ),
                      );
                    }
                    final item = _page!.items[index];
                    return Card(
                      elevation: 0,
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.history)),
                        title: Text(_types[item.observationType] ?? item.observationType),
                        subtitle: Text(
                          item.observedAtUtc == null
                              ? 'وقت الرصد غير متوفر'
                              : 'وقت الرصد: ${_formatUtc(item.observedAtUtc!)} UTC',
                        ),
                        trailing: const Icon(Icons.chevron_left),
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => ObservationArchiveDetailScreen(
                            api: widget.api,
                            stationId: widget.stationId!,
                            observationId: item.id,
                          ),
                        )),
                      ),
                    );
                  },
                ),
              ),
            ),
          if (_error != null && _page != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
        ],
      ),
    );
  }


  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromUtc ?? DateTime.now().toUtc(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _fromUtc = DateTime.utc(picked.year, picked.month, picked.day);
      if (_toUtc != null && !_fromUtc!.isBefore(_toUtc!)) {
        _toUtc = null;
      }
      _page = null;
    });
    _load();
  }

  Future<void> _pickToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toUtc?.subtract(const Duration(days: 1)) ?? DateTime.now().toUtc(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    final exclusiveEnd = DateTime.utc(picked.year, picked.month, picked.day)
        .add(const Duration(days: 1));
    if (_fromUtc != null && !_fromUtc!.isBefore(exclusiveEnd)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب أن يكون تاريخ النهاية بعد تاريخ البداية.')),
      );
      return;
    }
    setState(() {
      _toUtc = exclusiveEnd;
      _page = null;
    });
    _load();
  }

  static String _formatDate(DateTime value) {
    final date = value.toUtc();
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static String _formatUtc(DateTime value) {
    final utc = value.toUtc();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${utc.year}-${two(utc.month)}-${two(utc.day)} ${two(utc.hour)}:${two(utc.minute)}';
  }
}

class ObservationArchiveDetailScreen extends StatefulWidget {
  const ObservationArchiveDetailScreen({
    super.key,
    required this.api,
    required this.stationId,
    required this.observationId,
  });
  final MetraApiClient api;
  final String stationId;
  final String observationId;

  @override
  State<ObservationArchiveDetailScreen> createState() => _ObservationArchiveDetailScreenState();
}

class _ObservationArchiveDetailScreenState extends State<ObservationArchiveDetailScreen> {
  ObservationArchiveItem? _item;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final item = await widget.api.getObservationArchiveDetail(
        widget.stationId, widget.observationId);
      if (mounted) {
        setState(() => _item = item);
      }
    } on MetraApiException catch (error) {
      if (mounted) {
        setState(() => _error = error.statusCode == 403
            ? 'لا تملك صلاحية قراءة هذا السجل.'
            : error.statusCode == 404
                ? 'السجل غير موجود ضمن أرشيف هذه المحطة.'
                : 'تعذر تحميل تفاصيل السجل.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'تعذر تحميل تفاصيل السجل.');
      }
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(title: const Text('تفاصيل الرصد التاريخي')),
      body: _item == null
          ? Center(child: _error == null
              ? const CircularProgressIndicator()
              : Padding(padding: const EdgeInsets.all(24), child: Text(_error!)))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _detail('نوع الرصد', _item!.observationType),
                _detail('معرّف السجل', _item!.id),
                _detail('النظام المصدر', _item!.sourceSystem),
                _detail('الجدول المصدر', _item!.sourceTable),
                _detail('معرّف السجل المصدر', _item!.sourceRecordId),
                _detail('وقت الرصد UTC', _item!.observedAtUtc?.toUtc().toIso8601String() ?? 'غير متوفر'),
                _detail('وقت الاستيراد UTC', _item!.importedAtUtc.toUtc().toIso8601String()),
                const SizedBox(height: 12),
                const Text('محتوى الرصد الأصلي', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SelectableText(
                  const JsonEncoder.withIndent('  ').convert(_item!.payload),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ],
            ),
    ),
  );

  Widget _detail(String label, String value) => Card(
    elevation: 0,
    child: ListTile(title: Text(label, style: const TextStyle(fontSize: 12)),
      subtitle: SelectableText(value)),
  );
}

class _ArchiveMessage extends StatelessWidget {
  const _ArchiveMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 42, color: const Color(0xFF64748B)),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF64748B), height: 1.5)),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    ),
  );
}
