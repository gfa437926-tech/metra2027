import 'dart:math' as math;

import 'package:flutter/material.dart';

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

  double? _haversine(double lat1, double lon1, double lat2, double lon2) {
    const double r = 6371;
    double toRad(double d) => d * math.pi / 180;
    final double dLat = toRad(lat2 - lat1);
    final double dLon = toRad(lon2 - lon1);
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(toRad(lat1)) *
            math.cos(toRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  void _compare(List<StationDirectoryItem> stations) {
    final List<StationDirectoryItem> selected =
        stations.where((StationDirectoryItem s) => _selected.contains(s.id)).toList();
    if (selected.length < 2) {
      setState(() => _error = 'اختر محطتين على الأقل.');
      return;
    }
    final List<_PairResult> pairs = <_PairResult>[];
    for (int i = 0; i < selected.length; i++) {
      for (int j = i + 1; j < selected.length; j++) {
        final StationDirectoryItem a = selected[i];
        final StationDirectoryItem b = selected[j];
        pairs.add(
          _PairResult(
            from: a.nameArabic,
            to: b.nameArabic,
            distanceKm: a.hasValidCoordinates && b.hasValidCoordinates
                ? _haversine(a.latitude!, a.longitude!, b.latitude!, b.longitude!)
                : null,
            elevDiff: a.elevationM != null && b.elevationM != null
                ? b.elevationM! - a.elevationM!
                : null,
          ),
        );
      }
    }
    setState(() {
      _error = null;
      _pairs = pairs;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مركز التنبؤ الجوي'),
        actions: <Widget>[
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
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
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Text('تعذر تحميل دليل المحطات أو لا صلاحية.'),
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
                  title: Text('اطلاع فقط · UTC'),
                  subtitle: Text(
                    'الكتالوج المعتمد فقط. قيم الرصد اللحظية غير متاحة حتى اعتماد عقد اللقطة.',
                  ),
                ),
              ),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Color(0xFF8A1F2D))),
              Row(
                children: <Widget>[
                  FilledButton(
                    onPressed: () => _compare(stations),
                    child: const Text('مقارنة المختارة'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => setState(() {
                      _selected.clear();
                      _pairs = const <_PairResult>[];
                    }),
                    child: const Text('مسح'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final _PairResult p in _pairs)
                ListTile(
                  title: Text('${p.from} → ${p.to}'),
                  subtitle: Text(
                    'المسافة: ${p.distanceKm?.toStringAsFixed(1) ?? 'غير متاح'} كم · '
                    'فرق الارتفاع: ${p.elevDiff?.toStringAsFixed(0) ?? 'غير متاح'} م',
                  ),
                ),
              const Divider(),
              for (final StationDirectoryItem s in stations)
                CheckboxListTile(
                  value: _selected.contains(s.id),
                  onChanged: (bool? value) {
                    setState(() {
                      if (value == true) {
                        _selected.add(s.id);
                      } else {
                        _selected.remove(s.id);
                      }
                    });
                  },
                  title: Text(s.nameArabic),
                  subtitle: Text(
                    'الارتفاع: ${s.elevationM ?? 'غير متاح'} · '
                    'الإحداثيات: ${s.hasValidCoordinates ? '${s.latitude!.toStringAsFixed(3)}, ${s.longitude!.toStringAsFixed(3)}' : 'غير متاح'} · '
                    'الرصد: غير متاح',
                  ),
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
