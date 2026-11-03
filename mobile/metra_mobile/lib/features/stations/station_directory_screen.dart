import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/api/metra_api_client.dart';

class StationDirectoryScreen extends StatefulWidget {
  const StationDirectoryScreen({super.key, required this.api, this.selectedStationId, this.onStationSelected});
  final MetraApiClient api;
  final String? selectedStationId;
  final ValueChanged<String>? onStationSelected;
  @override
  State<StationDirectoryScreen> createState() => _StationDirectoryScreenState();
}
class _StationDirectoryScreenState extends State<StationDirectoryScreen> {
  String? _type;
  bool _showMap = true;
  late Future<List<StationDirectoryItem>> _stations;
  @override
  void initState() { super.initState(); _load(); }
  void _load() { _stations = widget.api.getAllStationDirectory(stationType: _type); }
  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(padding: const EdgeInsets.fromLTRB(12, 12, 12, 4), child: Column(children: [
      Wrap(spacing: 8, children: [
        _chip('الكل', null), _chip('الكلاسيكية', 'classic'),
        _chip('الآلية', 'automatic'), _chip('السينوبتيكية', 'synoptic'),
      ]),
      const SizedBox(height: 8),
      SegmentedButton<bool>(segments: const [
        ButtonSegment(value: true, icon: Icon(Icons.map_outlined), label: Text('الخريطة')),
        ButtonSegment(value: false, icon: Icon(Icons.list_alt), label: Text('القائمة')),
      ], selected: {_showMap}, onSelectionChanged: (v) => setState(() => _showMap = v.first)),
    ])),
    Expanded(child: FutureBuilder<List<StationDirectoryItem>>(future: _stations, builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
      if (snapshot.hasError) {
        return _empty(Icons.cloud_off, 'تعذر تحميل دليل المحطات',
          'تحقق من تسجيل الدخول والاتصال بواجهة API.',
          TextButton(onPressed: () => setState(_load), child: const Text('إعادة المحاولة')));
      }
      final rows = snapshot.data ?? const <StationDirectoryItem>[];
      if (rows.isEmpty) return _empty(Icons.location_off, 'لا توجد محطات', 'لا توجد سجلات مطابقة.');
      final located = rows.where((s) => s.hasCoordinates &&
        s.latitude! >= -90 && s.latitude! <= 90 &&
        s.longitude! >= -180 && s.longitude! <= 180).toList();
      if (_showMap) return _map(rows, located);
      return RefreshIndicator(onRefresh: () async => setState(_load),
        child: ListView.separated(padding: const EdgeInsets.all(12), itemCount: rows.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) => _card(rows[i])));
    })),
  ]);
  Widget _map(List<StationDirectoryItem> rows, List<StationDirectoryItem> located) {
    if (located.isEmpty) {
      return _empty(Icons.location_off, 'لا توجد إحداثيات موثقة',
        'يعرض الدليل ${rows.length} محطة، لكن لا توجد إحداثيات صالحة لرسمها. راجع القائمة للتفاصيل.');
    }
    final center = LatLng(
      located.map((s) => s.latitude!).reduce((a,b) => a+b) / located.length,
      located.map((s) => s.longitude!).reduce((a,b) => a+b) / located.length);
    return Stack(children: [
      FlutterMap(options: MapOptions(
        initialCenter: center,
        initialZoom: located.length == 1 ? 6 : 5,
        initialCameraFit: located.length > 1
          ? CameraFit.bounds(
              bounds: LatLngBounds.fromPoints(located
                .map((s) => LatLng(s.latitude!, s.longitude!)).toList()),
              padding: const EdgeInsets.all(48),
            )
          : null,
      ), children: [
        TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'org.metra.metra2027'),
        MarkerLayer(markers: located.map((station) => Marker(
          point: LatLng(station.latitude!, station.longitude!), width: 48, height: 58,
          alignment: Alignment.topCenter,
          child: Tooltip(message: '${station.nameArabic} • ${station.localCode}',
            child: GestureDetector(
              onTap: widget.onStationSelected == null ? null : () => widget.onStationSelected!(station.id),
              child: Icon(station.stationType == 'classic' ? Icons.cell_tower : Icons.sensors,
                size: 38, color: station.stationType == 'classic'
                  ? const Color(0xFF2463B5) : const Color(0xFF16835D)),
            )),
        )).toList()),
        const RichAttributionWidget(attributions: [TextSourceAttribution('OpenStreetMap contributors')]),
      ]),
      PositionedDirectional(start: 12, top: 12, child: Card(child: Padding(
        padding: const EdgeInsets.all(10), child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _legend(Icons.cell_tower, const Color(0xFF2463B5), 'كلاسيكية'),
            _legend(Icons.sensors, const Color(0xFF16835D), 'آلية / أخرى'),
            const SizedBox(height: 4),
            Text('المعروضة: ${located.length} من ${rows.length}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            if (located.length != rows.length)
              Text('بلا إحداثيات: ${rows.length-located.length}', style: const TextStyle(fontSize: 11)),
          ],
        ),
      ))),
      PositionedDirectional(end: 12, bottom: 12, child: FloatingActionButton.small(
        heroTag: 'refresh-station-map', onPressed: () => setState(_load), child: const Icon(Icons.refresh))),
    ]);
  }
  Widget _legend(IconData icon, Color color, String label) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2), child: Row(mainAxisSize: MainAxisSize.min,
      children: [Icon(icon, color: color, size: 19), const SizedBox(width: 6), Text(label)]));
  Widget _chip(String label, String? value) => ChoiceChip(label: Text(label),
    selected: _type == value, onSelected: (_) => setState(() { _type = value; _load(); }));
  Widget _card(StationDirectoryItem station) {
    final classic = station.stationType == 'classic';
    final type = classic ? 'كلاسيكية' : station.stationType == 'automatic' ? 'آلية' : 'سينوبتيكية';
    final approval = station.approvalStatus == 'approved' ? 'معتمدة' :
      station.approvalStatus == 'pending' ? 'بانتظار الاعتماد' : station.approvalStatus;
    final operation = station.operationalStatus == 'unverified' ? 'غير متحقق منها' : station.operationalStatus;
    final coords = station.hasCoordinates ? 'الإحداثيات متوفرة' : 'لا توجد إحداثيات موثقة';
    return Card(elevation: 0, child: ListTile(
      selected: station.id == widget.selectedStationId,
      onTap: widget.onStationSelected == null ? null : () => widget.onStationSelected!(station.id),
      leading: CircleAvatar(backgroundColor: classic ? const Color(0xFFEAF2FF) : const Color(0xFFE7F8F2),
        child: Icon(classic ? Icons.cell_tower : Icons.sensors,
          color: classic ? const Color(0xFF2463B5) : const Color(0xFF16835D))),
      title: Text(station.nameArabic, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text('$type • ${station.localCode}\\n$approval • $operation\\n$coords'),
      isThreeLine: true,
      trailing: widget.onStationSelected == null ? null : Icon(station.id == widget.selectedStationId ? Icons.check_circle : Icons.chevron_left)));
  }
  Widget _empty(IconData icon, String title, String detail, [Widget? action]) =>
    Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 42), const SizedBox(height: 12),
      Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 6), Text(detail, textAlign: TextAlign.center),
      if (action != null) action,
    ])));
}
