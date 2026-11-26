import 'package:material_ui/material_ui.dart';

import '../../core/catalog_integration/local_catalog_record.dart';
import '../../core/catalog_integration/local_catalog_record_store.dart';
import '../../core/widgets/metra_async_state.dart';
import 'catalog_observation_screen.dart';
import '../../core/catalog/observation_field_catalogs.dart';
import '../../core/catalog_integration/catalog_form_type.dart';
import '../../core/widgets/metra_observation_form.dart';

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
  String? _loadNote;

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
    final report = await LocalCatalogRecordStore.instance.ensureLoaded();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (report.skippedCorrupt > 0) {
        _loadNote =
            'تُجاهل ${report.skippedCorrupt} سجل تالف دون حذف بقية البيانات.';
      }
    });
  }

  List<LocalCatalogRecord> get _rows => LocalCatalogRecordStore.instance.list(
        stationId: widget.stationId,
        formType: widget.formType,
        query: _query.text,
        includeArchived: _includeArchived,
      );

  CatalogFormType? get _formTypeEnum {
    for (final t in CatalogFormType.values) {
      if (t.code == widget.formType) return t;
    }
    return null;
  }

  List<MetraObservationField> _fieldsFor(CatalogFormType type) {
    return switch (type) {
      CatalogFormType.agricultural => ObservationFieldCatalogs.agricultural,
      CatalogFormType.hourlyClimate => ObservationFieldCatalogs.hourlyclimate,
      CatalogFormType.rainfall => ObservationFieldCatalogs.rainfall,
      CatalogFormType.soil => ObservationFieldCatalogs.soil,
      CatalogFormType.faultEquipment => ObservationFieldCatalogs.faultequipment,
      CatalogFormType.faultTelecom => ObservationFieldCatalogs.faulttelecom,
      CatalogFormType.faultIt => ObservationFieldCatalogs.faultit,
    };
  }

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

  void _openDetail(LocalCatalogRecord record) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _LocalCatalogRecordDetailPage(
          recordId: record.id,
          titleAr: widget.titleAr,
          onEdit: () {
            Navigator.of(context).pop();
            _openEdit(record);
          },
        ),
      ),
    );
  }

  void _openEdit(LocalCatalogRecord record) {
    final type = _formTypeEnum;
    if (type == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text('تعديل محلي — ${widget.titleAr}')),
          body: CatalogObservationScreen(
            title: widget.titleAr,
            fields: _fieldsFor(type),
            formCode: type.code,
            stationId: widget.stationId,
            formType: type,
            existingRecordId: record.id,
            initialRecordValues: record.values,
          ),
        ),
      ),
    );
  }

  Future<void> _showExport() async {
    final json = LocalCatalogRecordStore.instance.exportJson(
      stationId: widget.stationId,
      formType: widget.formType,
      includeArchived: _includeArchived,
    );
    await showDialog<void>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تصدير محلي (JSON)'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: SelectableText(
                json,
                style: const TextStyle(fontSize: 12, height: 1.35),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text('سجلات محلية — ${widget.titleAr}'),
          actions: [
            IconButton(
              tooltip: 'تصدير JSON محلي',
              onPressed: rows.isEmpty ? null : _showExport,
              icon: const Icon(Icons.ios_share_outlined),
            ),
          ],
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
            if (_loadNote != null)
              Material(
                color: const Color(0xFFFFF1F0),
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.warning_amber, color: Color(0xFFB42318)),
                  title: Text(_loadNote!, style: const TextStyle(fontSize: 13)),
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
                                onTap: () => _openDetail(record),
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
                                    if (value == 'edit') {
                                      _openEdit(record);
                                    } else if (value == 'archive') {
                                      LocalCatalogRecordStore.instance
                                          .archive(record.id);
                                    } else if (value == 'delete') {
                                      _confirmDelete(record);
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Text('تعديل محلي'),
                                    ),
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

class _LocalCatalogRecordDetailPage extends StatefulWidget {
  const _LocalCatalogRecordDetailPage({
    required this.recordId,
    required this.titleAr,
    required this.onEdit,
  });

  final String recordId;
  final String titleAr;
  final VoidCallback onEdit;

  @override
  State<_LocalCatalogRecordDetailPage> createState() =>
      _LocalCatalogRecordDetailPageState();
}

class _LocalCatalogRecordDetailPageState
    extends State<_LocalCatalogRecordDetailPage> {
  @override
  void initState() {
    super.initState();
    LocalCatalogRecordStore.instance.addListener(_onStore);
  }

  @override
  void dispose() {
    LocalCatalogRecordStore.instance.removeListener(_onStore);
    super.dispose();
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final record = LocalCatalogRecordStore.instance.getById(widget.recordId);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text('تفاصيل محلية — ${widget.titleAr}'),
          actions: [
            if (record != null)
              TextButton(
                onPressed: widget.onEdit,
                child: const Text('تعديل'),
              ),
          ],
        ),
        body: record == null
            ? MetraAsyncStatePanel.empty(
                icon: Icons.search_off,
                title: 'السجل غير موجود',
                subtitle: 'قد يكون حُذف من هذا الجهاز.',
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Card(
                    color: Color(0xFFFFF7E8),
                    child: ListTile(
                      leading: Icon(Icons.phone_android, color: Color(0xFF9A6700)),
                      title: Text('سجل محلي فقط — ليس من الخادم'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    title: const Text('المعرّف'),
                    subtitle: Text(record.id),
                  ),
                  ListTile(
                    title: const Text('المحطة'),
                    subtitle: Text(record.stationId),
                  ),
                  ListTile(
                    title: const Text('نوع النموذج'),
                    subtitle: Text(record.formType),
                  ),
                  ListTile(
                    title: const Text('الحالة'),
                    subtitle: Text(record.status.name),
                  ),
                  ListTile(
                    title: const Text('أُنشئ'),
                    subtitle: Text(record.createdAt.toLocal().toString()),
                  ),
                  ListTile(
                    title: const Text('آخر تحديث'),
                    subtitle: Text(record.updatedAt.toLocal().toString()),
                  ),
                  const Divider(),
                  const Text(
                    'الحقول',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  ...record.values.entries.map(
                    (e) => ListTile(
                      dense: true,
                      title: Text(e.key),
                      subtitle: Text('${e.value ?? '—'}'),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
