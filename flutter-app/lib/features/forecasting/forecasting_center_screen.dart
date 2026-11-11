import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/api/metra_api_client.dart';

/// Read-only forecasting centre using the approved station catalogue only.
class ForecastingCenterScreen extends StatefulWidget {
  const ForecastingCenterScreen({super.key, required this.api});

  final MetraApiClient api;

  @override
  State<ForecastingCenterScreen> createState() => _ForecastingCenterScreenState();
}

class _ForecastingCenterScreenState extends State<ForecastingCenterScreen> {
  late Future<List<StationDirectoryItem>> _stations;
  final Set<String> _selected = <String>{};
  String? _error;
  List<_PairResult> _pairs = const <_PairResult>[];

  @override
  void initState() {
    super.initState();
    _stations = widget.api.getAllStationDirectory();
  }

  void _reload() {
    setState(() {
      _error = null;
      _pairs = const <_PairResult>[];
      _stations = widget.api.getAllStationDirectory();
    });
  }

  void _toggleStation(StationDirectoryItem station, bool selected) {
    setState(() {
      if (selected) {
        _selected.add(station.id);
      } else {
        _selected.remove(station.id);
      }
      _pairs = const <_PairResult>[];
    });
  }

  bool _comparing = false;

  Future<void> _compare(List<StationDirectoryItem> stations) async {
    final selected = stations
        .where((StationDirectoryItem s) => _selected.contains(s.id))
        .toList(growable: false);
    if (selected.length < 2) {
      setState(() => _error = 'اختر محطتين على الأقل.');
      return;
    }
    setState(() {
      _comparing = true;
      _error = null;
      _pairs = const <_PairResult>[];
    });
    try {
      final response = await widget.api.compareForecastingStations(
        selected.map((s) => s.id).toList(growable: false),
      );
      final names = <String, String>{for (final s in selected) s.id: s.nameArabic};
      final rawPairs = response['pairs'] as List<dynamic>;
      final parsed = rawPairs.map((raw) {
        final pair = Map<String, dynamic>.from(raw as Map);
        final fromId = pair['fromStationId'] as String?;
        final toId = pair['toStationId'] as String?;
        return _PairResult(
          from: names[fromId] ?? fromId ?? 'محطة غير معروفة',
          to: names[toId] ?? toId ?? 'محطة غير معروفة',
          distanceKm: (pair['distanceKm'] as num?)?.toDouble(),
          elevDiff: (pair['elevationDifferenceM'] as num?)?.toDouble(),
        );
      }).toList(growable: false);
      if (!mounted) return;
      setState(() {
        _pairs = parsed;
        _comparing = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _comparing = false;
        _error = error.toString();
      });
    }
  }

  Widget _stationMap(List<StationDirectoryItem> stations) {
    final located = stations.where((s) => s.hasValidCoordinates).toList();
    if (located.isEmpty) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.location_off_outlined),
          title: Text('لا توجد إحداثيات صالحة'),
          subtitle: Text('تعرض المقارنة بيانات الكتالوج المتاحة دون إنشاء مواقع افتراضية.'),
        ),
      );
    }
    final center = LatLng(
      located.map((s) => s.latitude!).reduce((a, b) => a + b) / located.length,
      located.map((s) => s.longitude!).reduce((a, b) => a + b) / located.length,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('التوزع الجغرافي للمحطات',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            Text('${located.length} / ${stations.length}',
                style: const TextStyle(color: Color(0xFF64748B))),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            height: 300,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: center,
                initialZoom: located.length == 1 ? 6 : 5,
                initialCameraFit: located.length > 1
                    ? CameraFit.bounds(
                        bounds: LatLngBounds.fromPoints(located
                            .map((s) => LatLng(s.latitude!, s.longitude!))
                            .toList()),
                        padding: const EdgeInsets.all(42),
                      )
                    : null,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'org.metra.metra2027',
                ),
                MarkerLayer(
                  markers: located.map((station) {
                    final isSelected = _selected.contains(station.id);
                    return Marker(
                      point: LatLng(station.latitude!, station.longitude!),
                      width: 54,
                      height: 58,
                      child: Tooltip(
                        message: '${station.nameArabic} • ${station.localCode}',
                        child: GestureDetector(
                          onTap: () => _toggleStation(station, !isSelected),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 38,
                                color: isSelected
                                    ? const Color(0xFFDC4B42)
                                    : const Color(0xFF1769AA),
                              ),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFFDC4B42)
                                      : const Color(0xFF1769AA),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const RichAttributionWidget(
                  attributions: [TextSourceAttribution('OpenStreetMap contributors')],
                ),
              ],
            ),
          ),
        ),
        if (located.length != stations.length)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '${stations.length - located.length} محطة بلا إحداثيات صالحة؛ تظهر في القائمة فقط.',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مركز التنبؤ الجوي'),
        actions: <Widget>[
          IconButton(onPressed: _reload, tooltip: 'تحديث الدليل',
              icon: const Icon(Icons.refresh)),
        ],
      ),
      body: FutureBuilder<List<StationDirectoryItem>>(
        future: _stations,
        builder: (
          BuildContext context,
          AsyncSnapshot<List<StationDirectoryItem>> snapshot,
        ) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_outlined, size: 40),
                    const SizedBox(height: 10),
                    const Text('تعذر تحميل دليل المحطات أو لا توجد صلاحية.'),
                    TextButton(onPressed: _reload, child: const Text('إعادة المحاولة')),
                  ],
                ),
              ),
            );
          }
          final List<StationDirectoryItem> stations =
              snapshot.data ?? const <StationDirectoryItem>[];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              const Card(
                color: Color(0xFFEEF6FA),
                child: ListTile(
                  leading: Icon(Icons.visibility_outlined),
                  title: Text('اطلاع فقط · جميع الأوقات UTC'),
                  subtitle: Text(
                    'المعروض حالياً بيانات دليل المحطات والموقع والارتفاع فقط. '
                    'قيم الرصد اللحظية وتفاصيل النشرات لا تُعرض قبل اعتماد واجهة اللقطة الحية.',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _stationMap(stations),
              const Text('اختر المحطات للمقارنة',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text('${_selected.length} محطة محددة',
                  style: const TextStyle(color: Color(0xFF64748B))),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: _comparing ? null : () => _compare(stations),
                    child: Text(_comparing ? 'جارٍ المقارنة...' : 'مقارنة المختارة'),
                  ),
                  OutlinedButton(
                    onPressed: _selected.isEmpty
                        ? null
                        : () => setState(() {
                              _selected.clear();
                              _pairs = const <_PairResult>[];
                              _error = null;
                            }),
                    child: const Text('مسح التحديد'),
                  ),
                ],
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_error!,
                      style: const TextStyle(color: Color(0xFF8A1F2D))),
                ),
              if (_pairs.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('نتائج المقارنة الجغرافية',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                for (final _PairResult p in _pairs)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.compare_arrows),
                      title: Text('${p.from} ↔ ${p.to}'),
                      subtitle: Text(
                        'المسافة: ${p.distanceKm?.toStringAsFixed(1) ?? 'غير متاح'} كم · '
                        'فرق الارتفاع: ${p.elevDiff?.toStringAsFixed(0) ?? 'غير متاح'} م',
                      ),
                    ),
                  ),
              ],
              const Divider(height: 24),
              for (final StationDirectoryItem s in stations)
                CheckboxListTile(
                  value: _selected.contains(s.id),
                  onChanged: (bool? value) =>
                      _toggleStation(s, value == true),
                  title: Text(s.nameArabic),
                  subtitle: Text(
                    'الارتفاع: ${s.elevationM?.toStringAsFixed(1) ?? 'غير متاح'} م · '
                    'الإحداثيات: ${s.hasValidCoordinates ? '${s.latitude!.toStringAsFixed(3)}, ${s.longitude!.toStringAsFixed(3)}' : 'غير متاح'} · '
                    'الرصد اللحظي: غير متاح',
                  ),
                ),
              if (stations.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('لا توجد محطات في الدليل الحالي.',
                      textAlign: TextAlign.center),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _PairResult {
  const _PairResult({
    required this.from,
    required this.to,
    required this.distanceKm,
    required this.elevDiff,
  });

  final String from;
  final String to;
  final double? distanceKm;
  final double? elevDiff;
}
