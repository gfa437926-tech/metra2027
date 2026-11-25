import 'package:material_ui/material_ui.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/api/metra_api_client.dart';
import '../../core/auth/metra_access_context.dart';
import '../../core/widgets/metra_async_state.dart';
import 'station_directory_query.dart';

/// Station catalogue (map + list). Operational work still requires a selected
/// station and server-side permission checks on every mutation.
class StationDirectoryScreen extends StatefulWidget {
  const StationDirectoryScreen({
    super.key,
    required this.api,
    this.selectedStationId,
    this.onStationSelected,
    this.accessContext,
  });

  final MetraApiClient api;
  final String? selectedStationId;
  final ValueChanged<String>? onStationSelected;

  /// When resolved, stations with operational permissions are badged and can
  /// be filtered via «محطاتي». Directory remains readable for all stations;
  /// mutations stay gated by access-context + server RPCs.
  final MetraAccessContext? accessContext;

  @override
  State<StationDirectoryScreen> createState() => _StationDirectoryScreenState();
}

class _StationDirectoryScreenState extends State<StationDirectoryScreen> {
  String? _type;
  bool _showMap = true;
  bool _mineOnly = false;
  final _query = TextEditingController();
  late Future<List<StationDirectoryItem>> _stations;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _load() {
    _stations = widget.api.getAllStationDirectory(stationType: _type);
  }

  bool _hasOperationalAccess(String stationId) {
    final access = widget.accessContext;
    if (access == null || !access.isResolved) return false;
    return access.canAccessObservationWorkspace(stationId) ||
        access.canAdministerStation(stationId);
  }

  List<StationDirectoryItem> _applyFilters(List<StationDirectoryItem> rows) {
    return filterAndSortStationDirectory(
      rows: rows,
      query: _query.text,
      mineOnly: _mineOnly,
      hasOperationalAccess: _hasOperationalAccess,
    );
  }

  @override
  Widget build(BuildContext context) {
    final access = widget.accessContext;
    final showMineFilter = access != null && access.isResolved;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: Column(
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _chip('الكل', null),
                      _chip('الكلاسيكية', 'classic'),
                      _chip('الآلية', 'automatic'),
                      _chip('السينوبتيكية', 'synoptic'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _query,
                    textDirection: TextDirection.rtl,
                    decoration: InputDecoration(
                      labelText: 'بحث في الدليل المحمّل',
                      hintText: 'الاسم أو الرمز أو معرف المنظمة',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _query.text.trim().isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'مسح البحث',
                              onPressed: () => setState(_query.clear),
                              icon: const Icon(Icons.clear),
                            ),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(
                            value: true,
                            icon: Icon(Icons.map_outlined),
                            label: Text('الخريطة'),
                          ),
                          ButtonSegment(
                            value: false,
                            icon: Icon(Icons.list_alt),
                            label: Text('القائمة'),
                          ),
                        ],
                        selected: {_showMap},
                        onSelectionChanged: (v) =>
                            setState(() => _showMap = v.first),
                      ),
                      if (showMineFilter)
                        FilterChip(
                          label: const Text('محطاتي فقط'),
                          selected: _mineOnly,
                          onSelected: (v) => setState(() => _mineOnly = v),
                          avatar: Icon(
                            _mineOnly
                                ? Icons.verified_user
                                : Icons.verified_user_outlined,
                            size: 18,
                          ),
                        ),
                    ],
                  ),
                  if (showMineFilter && _mineOnly)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          'تُعرض المحطات التي يملك حسابك عليها صلاحيات رصد أو إدارة فقط. '
                          'التفويض النهائي من الخادم.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<StationDirectoryItem>>(
                future: _stations,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return MetraAsyncStatePanel.loading(
                      message: 'جاري تحميل دليل المحطات…',
                    );
                  }
                  if (snapshot.hasError) {
                    return MetraAsyncStatePanel.error(
                      title: 'تعذر تحميل دليل المحطات',
                      subtitle: 'تحقق من تسجيل الدخول والاتصال بالشبكة وواجهة API ثم أعد المحاولة.',
                      onRetry: () => setState(_load),
                    );
                  }
                  final allRows =
                      snapshot.data ?? const <StationDirectoryItem>[];
                  final rows = _applyFilters(allRows);
                  if (rows.isEmpty) {
                    return MetraAsyncStatePanel.empty(
                      icon: Icons.location_off,
                      title: _mineOnly
                          ? 'لا توجد محطات مصرّح بها'
                          : _query.text.trim().isEmpty
                          ? 'لا توجد محطات'
                          : 'لا توجد محطات مطابقة',
                      subtitle: _mineOnly
                          ? 'لا يملك حسابك صلاحيات تشغيلية على أي محطة ضمن الفلتر الحالي.'
                          : _query.text.trim().isEmpty
                          ? 'لا توجد سجلات مطابقة للنوع المحدد.'
                          : 'عبارة البحث لا تطابق اسماً أو رمزاً ضمن المحطات المحمّلة. لم يُستعلم الخادم من جديد.',
                      action: TextButton(
                        onPressed: () => setState(_load),
                        child: const Text('تحديث'),
                      ),
                    );
                  }
                  final located = rows
                      .where((s) => s.hasValidCoordinates)
                      .toList();
                  if (_showMap) return _map(rows, located);
                  return RefreshIndicator(
                    onRefresh: () async => setState(_load),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: rows.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) => _card(rows[i]),
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

  Widget _map(
    List<StationDirectoryItem> rows,
    List<StationDirectoryItem> located,
  ) {
    if (located.isEmpty) {
      return _empty(
        Icons.location_off,
        'لا توجد إحداثيات موثقة',
        'يعرض الدليل ${rows.length} محطة، لكن لا توجد إحداثيات صالحة لرسمها. راجع القائمة للتفاصيل.',
      );
    }
    final center = LatLng(
      located.map((s) => s.latitude!).reduce((a, b) => a + b) / located.length,
      located.map((s) => s.longitude!).reduce((a, b) => a + b) / located.length,
    );
    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: center,
            initialZoom: located.length == 1 ? 6 : 5,
            initialCameraFit: located.length > 1
                ? CameraFit.bounds(
                    bounds: LatLngBounds.fromPoints(
                      located
                          .map((s) => LatLng(s.latitude!, s.longitude!))
                          .toList(),
                    ),
                    padding: const EdgeInsets.all(48),
                  )
                : null,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'org.metra.metra2027',
            ),
            MarkerLayer(
              markers: located
                  .map(
                    (station) => Marker(
                      point: LatLng(station.latitude!, station.longitude!),
                      width: 48,
                      height: 58,
                      alignment: Alignment.topCenter,
                      child: Tooltip(
                        message: '${station.nameArabic} • ${station.localCode}',
                        child: GestureDetector(
                          onTap: widget.onStationSelected == null
                              ? null
                              : () => widget.onStationSelected!(station.id),
                          child: Icon(
                            station.stationType == 'classic'
                                ? Icons.cell_tower
                                : Icons.sensors,
                            size: 38,
                            color: _hasOperationalAccess(station.id)
                                ? const Color(0xFF087CF0)
                                : station.stationType == 'classic'
                                ? const Color(0xFF2463B5)
                                : const Color(0xFF16835D),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
        Positioned(
          right: 12,
          bottom: 12,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FloatingActionButton.small(
                heroTag: 'refresh-station-map',
                onPressed: () => setState(_load),
                child: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _empty(IconData icon, String title, String body, [Widget? action]) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: const Color(0xFF087CF0)),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(height: 1.5, color: Color(0xFF475569)),
            ),
            if (action != null) ...[const SizedBox(height: 16), action],
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, String? value) => ChoiceChip(
    label: Text(label),
    selected: _type == value,
    onSelected: (_) => setState(() {
      _type = value;
      _load();
    }),
  );

  Widget _card(StationDirectoryItem station) {
    final classic = station.stationType == 'classic';
    final type = classic
        ? 'كلاسيكية'
        : station.stationType == 'automatic'
        ? 'آلية'
        : 'سينوبتيكية';
    final approval = station.approvalStatus == 'approved'
        ? 'معتمدة'
        : station.approvalStatus == 'pending'
        ? 'بانتظار الاعتماد'
        : station.approvalStatus;
    final operation = station.operationalStatus == 'unverified'
        ? 'غير متحقق منها'
        : station.operationalStatus;
    final coords = station.hasValidCoordinates
        ? 'إحداثيات صالحة'
        : station.hasCoordinates
        ? 'إحداثيات غير صالحة — لن تظهر على الخريطة'
        : 'لا توجد إحداثيات موثقة';
    final authorized = _hasOperationalAccess(station.id);

    return Card(
      elevation: 0,
      child: ListTile(
        selected: station.id == widget.selectedStationId,
        onTap: widget.onStationSelected == null
            ? null
            : () => widget.onStationSelected!(station.id),
        leading: CircleAvatar(
          backgroundColor: authorized
              ? const Color(0xFFE8F4FF)
              : classic
              ? const Color(0xFFEAF2FF)
              : const Color(0xFFE7F8F2),
          child: Icon(
            classic ? Icons.cell_tower : Icons.sensors,
            color: authorized
                ? const Color(0xFF087CF0)
                : classic
                ? const Color(0xFF2463B5)
                : const Color(0xFF16835D),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                station.nameArabic,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            if (authorized)
              const Padding(
                padding: EdgeInsetsDirectional.only(start: 6),
                child: Tooltip(
                  message: 'لديك صلاحيات تشغيلية على هذه المحطة',
                  child: Icon(
                    Icons.verified_user,
                    size: 18,
                    color: Color(0xFF087CF0),
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text(
          '$type • ${station.localCode}\n$approval • $operation\n$coords'
          '${authorized ? '\nمصرّح لك بالعمل على هذه المحطة' : ''}',
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'تفاصيل المحطة',
              onPressed: () => _showStationDetails(station, authorized),
              icon: const Icon(Icons.info_outline),
            ),
            if (widget.onStationSelected != null)
              Icon(
                station.id == widget.selectedStationId
                    ? Icons.check_circle
                    : Icons.chevron_left,
              ),
          ],
        ),
      ),
    );
  }

  void _showStationDetails(StationDirectoryItem station, bool authorized) {
    final coordinates = station.hasValidCoordinates
        ? '${station.latitude!.toStringAsFixed(5)}, ${station.longitude!.toStringAsFixed(5)}'
        : 'غير متاحة أو غير صالحة';
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  station.nameArabic,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  station.nameEnglish,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (authorized) ...[
                  const SizedBox(height: 8),
                  const Row(
                    children: [
                      Icon(
                        Icons.verified_user,
                        size: 18,
                        color: Color(0xFF087CF0),
                      ),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'حسابك يملك صلاحيات تشغيلية على هذه المحطة (من سياق الخادم).',
                          style: TextStyle(
                            color: Color(0xFF087CF0),
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const Divider(height: 24),
                _detailRow('الرمز المحلي', station.localCode),
                _detailRow('معرّف WMO', station.wmoStationId ?? 'غير متوفر'),
                _detailRow(
                  'نوع المحطة',
                  _stationTypeLabel(station.stationType),
                ),
                _detailRow(
                  'الارتفاع عن سطح البحر',
                  station.elevationM == null
                      ? 'غير متوفر'
                      : '${station.elevationM!.toStringAsFixed(1)} م',
                ),
                _detailRow('الإحداثيات', coordinates),
                _detailRow(
                  'مصدر الإحداثيات',
                  station.coordinateSource ?? 'غير موثق',
                ),
                _detailRow(
                  'دقة الإحداثيات',
                  station.coordinateAccuracyM == null
                      ? 'غير متوفرة'
                      : '${station.coordinateAccuracyM!.toStringAsFixed(1)} م',
                ),
                _detailRow(
                  'حالة الاعتماد',
                  _approvalLabel(station.approvalStatus),
                ),
                _detailRow(
                  'الحالة التشغيلية',
                  _operationLabel(station.operationalStatus),
                ),
                const SizedBox(height: 8),
                const Text(
                  'هذه بيانات دليل المحطات. لا تمثل قياسات جوية لحظية أو حالة اتصال أجهزة الرصد. '
                  'أي عملية رصد أو إدارة تُفرض صلاحياتها من الخادم.',
                  style: TextStyle(color: Color(0xFF64748B), height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );

  String _stationTypeLabel(String type) => switch (type) {
    'classic' => 'كلاسيكية',
    'automatic' => 'آلية',
    'synoptic' => 'سينوبتيكية',
    _ => type,
  };

  String _approvalLabel(String status) => switch (status) {
    'approved' => 'معتمدة',
    'pending' => 'بانتظار الاعتماد',
    _ => status,
  };

  String _operationLabel(String status) => switch (status) {
    'unverified' => 'غير متحقق منها',
    'active' => 'نشطة',
    'inactive' => 'غير نشطة',
    _ => status,
  };
}
