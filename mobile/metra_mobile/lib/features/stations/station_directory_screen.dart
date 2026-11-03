import 'package:flutter/material.dart';
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
  late Future<List<StationDirectoryItem>> _stations;
  @override
  void initState() { super.initState(); _load(); }
  void _load() { _stations = widget.api.getStationDirectory(stationType: _type); }
  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(padding: const EdgeInsets.all(12), child: Wrap(spacing: 8, children: [
      _chip('الكل', null), _chip('الكلاسيكية', 'classic'),
      _chip('الآلية', 'automatic'), _chip('السينوبتيكية', 'synoptic'),
    ])),
    Expanded(child: FutureBuilder<List<StationDirectoryItem>>(future: _stations, builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return _empty(Icons.cloud_off, 'تعذر تحميل دليل المحطات',
        'تحقق من تسجيل الدخول والاتصال بواجهة API.',
        TextButton(onPressed: () => setState(_load), child: const Text('إعادة المحاولة')));
      }
      final rows = snapshot.data ?? const <StationDirectoryItem>[];
      if (rows.isEmpty) return _empty(Icons.location_off, 'لا توجد محطات', 'لا توجد سجلات مطابقة.');
      return RefreshIndicator(onRefresh: () async => setState(_load),
        child: ListView.separated(padding: const EdgeInsets.all(12), itemCount: rows.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) => _card(rows[i])));
    })),
  ]);
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
      subtitle: Text('$type • ${station.localCode}\n$approval • $operation\n$coords'),
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
