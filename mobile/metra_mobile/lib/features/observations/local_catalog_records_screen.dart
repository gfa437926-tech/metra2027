import 'package:material_ui/material_ui.dart';

import '../../core/catalog_integration/local_catalog_record.dart';
import '../../core/catalog_integration/local_catalog_record_store.dart';
import '../../core/widgets/metra_async_state.dart';

/// Lists on-device catalogue records for one station + form type.
///
/// Does not call the network and never presents rows as server-backed.
class LocalCatalogRecordsScreen extends StatefulWidget {
  const LocalCatalogRecordsScreen({
    super.key,
    required this.stationId,
    required this.formType,
    required this.titleAr,
  });

  final String stationId;
  final String formType;
  final String titleAr;

  @override
  State<LocalCatalogRecordsScreen> createState() =>
      _LocalCatalogRecordsScreenState();
}

class _LocalCatalogRecordsScreenState extends State<LocalCatalogRecordsScreen> {
  final _query = TextEditingController();
  bool _loading = true;
  bool _includeArchived = false;

  @override
  void initState() {
    super.initState();
    LocalCatalogRecordStore.instance.addListener(_onStore);
    _bootstrap();
  }

  @override
  void dispose() {
    LocalCatalogRecordStore.instance.removeListener(_onStore);
    _query.dispose();
    super.dispose();
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  Future<void> _bootstrap() async {
    await LocalCatalogRecordStore.instance.ensureLoaded();
    if (mounted) setState(() => _loading = false);
  }

  List<LocalCatalogRecord> get _rows => LocalCatalogRecordStore.instance.list(
        stationId: widget.stationId,
        formType: widget.formType,
        query: _query.text,
        includeArchived: _includeArchived,
      );

  Future<void> _confirmDelete(LocalCatalogRecord record) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف السجل المحلي'),
          content: const Text(
            'سيُحذف السجل من هذا الجهاز فقط. لا يوجد سجل خادمي مرتبط.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      LocalCatalogRecordStore.instance.delete(record.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text('سجلات محلية — ${widget.titleAr}'),
        ),
        body: Column(
          children: [
            Material(
              color: const Color(0xFFFFF7E8),
              child: const ListTile(
                leading: Icon(Icons.phone_android, color: Color(0xFF9A6700)),
                title: Text(
                  'سجلات على الجهاز فقط',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF9A6700),
                  ),
                ),
                subtitle: Text(
                  'لا تُرسل إلى الخادم. لن تظهر لراصدين آخرين أو على أجهزة أخرى.',
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: TextField(
                controller: _query,
                decoration: InputDecoration(
                  labelText: 'بحث محلي',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  suffixIcon: _query.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _query.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.clear),
                        ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            SwitchListTile(
              title: const Text('إظهار المؤرشفة محلياً'),
              value: _includeArchived,
              onChanged: (v) => setState(() => _includeArchived = v),
            ),
            Expanded(
              child: _loading
                  ? MetraAsyncStatePanel.loading(
                      message: 'جاري تحميل السجلات المحلية…',
                    )
                  : rows.isEmpty
                      ? MetraAsyncStatePanel.empty(
                          icon: Icons.folder_off_outlined,
                          title: 'لا توجد سجلات محلية',
                          subtitle:
                              'بعد التحقق المحلي الناجح تُحفظ السجلات على هذا الجهاز فقط.',
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: rows.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final record = rows[index];
                            final date = record.values['observationDate'] ??
                                record.updatedAt.toIso8601String();
                            final archived = record.status ==
                                LocalCatalogRecordStatus.localArchived;
                            return Card(
                              elevation: 0,
                              child: ListTile(
                                title: Text(
                                  archived
                                      ? 'مؤرشف محلياً · $date'
                                      : 'محلي · $date',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  'المعرّف: ${record.id}\n'
                                  'الحقول: ${record.values.length} · '
                                  'حدّث: ${record.updatedAt.toLocal()}',
                                ),
                                isThreeLine: true,
                                trailing: PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'archive') {
                                      LocalCatalogRecordStore.instance
                                          .archive(record.id);
                                    } else if (value == 'delete') {
                                      _confirmDelete(record);
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    if (!archived)
                                      const PopupMenuItem(
                                        value: 'archive',
                                        child: Text('أرشفة محلية'),
                                      ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Text('حذف من الجهاز'),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
