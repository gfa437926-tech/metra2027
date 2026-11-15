// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/api/metra_api_client.dart';
import '../../core/api/service_readiness.dart';
import 'greenfield_station_directory_item.dart';

class StationDirectoryScreen extends StatefulWidget {
  const StationDirectoryScreen({
    super.key,
    required this.api,
    this.selectedStationId,
    this.onStationSelected,
  });

  final MetraApiClient api;
  final String? selectedStationId;
  final ValueChanged<String>? onStationSelected;

  @override
  State<StationDirectoryScreen> createState() => _StationDirectoryScreenState();
}

class _StationDirectoryScreenState extends State<StationDirectoryScreen> {
  bool _showMap = true;
  bool _directoryNotReady = false;
  late Future<List<GreenfieldStationDirectoryItem>> _stations;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _directoryNotReady =
        MetraServiceReadiness.stationDirectory != MetraDataSourceMode.liveApi;
    if (_directoryNotReady) {
      // Keep the readiness gate as explicit UI state. A pre-failed Future can
      // emit an unhandled asynchronous error before FutureBuilder subscribes,
      // especially when the user taps Retry while the feature remains gated.
      _stations = Future.value(const <GreenfieldStationDirectoryItem>[]);
      return;
    }
    _stations = widget.api.getGreenfieldStationDirectory();
  }

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: SegmentedButton<bool>(
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
                onSelectionChanged: (value) =>
                    setState(() => _showMap = value.first),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<GreenfieldStationDirectoryItem>>(
              future: _stations,
              builder: (context, snapshot) {
                if (_directoryNotReady) {
                  return _empty(
                    Icons.cloud_off,
                    'تعذر تحميل دليل المحطات',
                    'دليل المحطات متوقف مؤقتاً حتى اكتمال ربط قاعدة البيانات الجديدة واختبارات الصلاحيات.',
                    TextButton(
                      onPressed: () => setState(_load),
                      child: const Text('إعادة المحاولة'),
                    ),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  final error = snapshot.error;
                  return _empty(
                    Icons.cloud_off,
                    'تعذر تحميل دليل المحطات',
                    'تحقق من تسجيل الدخول والاتصال بواجهة API.',
                    TextButton(
                      onPressed: () => setState(_load),
                      child: const Text('إعادة المحاولة'),
                    ),
                  );
                }
                final rows =
                    snapshot.data ?? const <GreenfieldStationDirectoryItem>[];
                if (rows.isEmpty) {
                  return _empty(
                    Icons.location_off,
                    'لا توجد محطات',
                    'لا توجد سجلات مطابقة في دليل المحطات الجديد.',
                  );
                }
                final located = rows.where((station) => station.hasCoordinates).toList();
                if (_showMap) return _map(rows, located);
                return RefreshIndicator(
                  onRefresh: () async => setState(_load),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) => _card(rows[index]),
                  ),
                );
              },
            ),
          ),
        ],
      );

  Widget _map(
    List<GreenfieldStationDirectoryItem> rows,
    List<GreenfieldStationDirectoryItem> located,
  ) {
    if (located.isEmpty) {
      return _empty(
        Icons.location_off,
        'لا توجد إحداثيات موثقة',
        'يعرض الدليل ${rows.length} محطة، لكن لا توجد إحداثيات صالحة لرسمها. راجع القائمة للتفاصيل.',
      );
    }
    final center = LatLng(
      located.map((station) => station.latitude!).reduce((a, b) => a + b) /
          located.length,
      located.map((station) => station.longitude!).reduce((a, b) => a + b) /
          located.length,
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
                          .map((station) => LatLng(
                                station.latitude!,
                                station.longitude!,
                              ))
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
                        message: '${station.nameArabic} • ${station.stationCode}',
                        child: GestureDetector(
                          onTap: widget.onStationSelected == null
                              ? null
                              : () => widget.onStationSelected!(station.id),
                          child: const Icon(
                            Icons.sensors,
                            size: 38,
                            color: Color(0xFF16835D),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const RichAttributionWidget(
              attributions: [
                TextSourceAttribution('OpenStreetMap contributors'),
              ],
            ),
          ],
        ),
        PositionedDirectional(
          start: 12,
          top: 12,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sensors, color: Color(0xFF16835D), size: 19),
                      SizedBox(width: 6),
                      Text('مواقع المحطات'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'المعروضة: ${located.length} من ${rows.length}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  if (located.length != rows.length)
                    Text(
                      'بلا إحداثيات: ${rows.length - located.length}',
                      style: const TextStyle(fontSize: 11),
                    ),
                ],
              ),
            ),
          ),
        ),
        PositionedDirectional(
          end: 12,
          bottom: 12,
          child: FloatingActionButton.small(
            heroTag: 'refresh-station-map',
            onPressed: () => setState(_load),
            child: const Icon(Icons.refresh),
          ),
        ),
      ],
    );
  }

  Widget _card(GreenfieldStationDirectoryItem station) {
    final coordinates = station.hasCoordinates
        ? 'إحداثيات موثقة'
        : 'لا توجد إحداثيات موثقة';
    return Card(
      elevation: 0,
      child: ListTile(
        selected: station.id == widget.selectedStationId,
        onTap: widget.onStationSelected == null
            ? null
            : () => widget.onStationSelected!(station.id),
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFE7F8F2),
          child: Icon(Icons.sensors, color: Color(0xFF16835D)),
        ),
        title: Text(
          station.nameArabic,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${station.stationTypeNameArabic} • ${station.stationCode}\n'
          '${_approvalLabel(station.approvalStatus)} • '
          '${_operationLabel(station.operationalStatus)}\n$coordinates',
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'تفاصيل المحطة',
              onPressed: () => _showStationDetails(station),
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

  void _showStationDetails(GreenfieldStationDirectoryItem station) {
    final coordinates = station.hasCoordinates
        ? '${station.latitude!.toStringAsFixed(5)}, '
            '${station.longitude!.toStringAsFixed(5)}'
        : 'غير متاحة';
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
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  station.nameEnglish,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const Divider(height: 24),
                _detailRow('رمز المحطة', station.stationCode),
                _detailRow('معرّف WMO', station.wmoIdentifier ?? 'غير متوفر'),
                _detailRow('نوع المحطة', station.stationTypeNameArabic),
                _detailRow(
                  'الارتفاع عن سطح البحر',
                  station.elevationM == null
                      ? 'غير متوفر'
                      : '${station.elevationM!.toStringAsFixed(1)} م',
                ),
                _detailRow('الإحداثيات', coordinates),
                _detailRow('المنطقة الزمنية', station.timezoneName ?? 'غير متوفرة'),
                _detailRow('مصدر الإحداثيات', station.locationSource ?? 'غير موثق'),
                _detailRow(
                  'دقة الإحداثيات',
                  station.horizontalAccuracyM == null
                      ? 'غير متوفرة'
                      : '${station.horizontalAccuracyM!.toStringAsFixed(1)} م',
                ),
                _detailRow('حالة الاعتماد', _approvalLabel(station.approvalStatus)),
                _detailRow('الحالة التشغيلية', _operationLabel(station.operationalStatus)),
                const SizedBox(height: 8),
                const Text(
                  'هذه بيانات دليل المحطات. لا تمثل قياسات جوية لحظية أو حالة اتصال أجهزة الرصد.',
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
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 132,
              child: Text(
                label,
                style: const TextStyle(color: Color(0xFF64748B)),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );

  String _approvalLabel(String status) => switch (status) {
        'approved' => 'معتمدة',
        _ => status,
      };

  String _operationLabel(String status) => switch (status) {
        'active' => 'فعالة',
        'temporarily_closed' => 'متوقفة مؤقتاً',
        _ => status,
      };

  Widget _empty(IconData icon, String title, String detail, [Widget? action]) =>
      Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 42),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(detail, textAlign: TextAlign.center),
              if (action != null) action,
            ],
          ),
        ),
      );
}
