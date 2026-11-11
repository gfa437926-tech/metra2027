import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/api/metra_api_client.dart';

/// Catalogue-based geographic comparison for forecast-centre staff.
/// Live telemetry is intentionally not synthesized here: it needs a separate,
/// approved observation-feed contract with timestamp and quality provenance.
class ForecastCentreScreen extends StatefulWidget {
  const ForecastCentreScreen({super.key, required this.api});

  final MetraApiClient api;

  @override
  State<ForecastCentreScreen> createState() => _ForecastCentreScreenState();
}

class _ForecastCentreScreenState extends State<ForecastCentreScreen> {
  late Future<List<StationDirectoryItem>> _stationsFuture;
  final Set<String> _selectedIds = <String>{};
  String? _referenceId;

  @override
  void initState() {
    super.initState();
    _stationsFuture = widget.api.getAllStationDirectory();
  }

  void _reload() {
    setState(() {
      _stationsFuture = widget.api.getAllStationDirectory();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<StationDirectoryItem>>(
      future: _stationsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _state(
            icon: Icons.cloud_off_outlined,
            title: 'تعذر تحميل دليل المحطات',
            message: 'تحقق من الاتصال وصلاحية الوصول، ثم أعد المحاولة.',
            action: FilledButton.tonalIcon(
              onPressed: _reload,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          );
        }
        final stations = snapshot.data ?? const <StationDirectoryItem>[];
        if (stations.isEmpty) {
          return _state(
            icon: Icons.location_searching,
            title: 'لا توجد محطات متاحة للمقارنة',
            message: 'لم يُرجع دليل المحطات أي سجلات ضمن نطاق صلاحيات الحساب.',
            action: TextButton(onPressed: _reload, child: const Text('تحديث')),
          );
        }
        final selected = stations.where((s) => _selectedIds.contains(s.id)).toList();
        StationDirectoryItem? reference;
        for (final station in stations) {
          if (station.id == _referenceId) { reference = station; break; }
        }
        return Directionality(
          textDirection: TextDirection.rtl,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _intro(),
              const SizedBox(height: 12),
              _liveUnavailable(),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text('اختيار المحطات للمقارنة',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            )),
                  ),
                  TextButton.icon(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh),
                    label: const Text('تحديث الدليل'),
                  ),
                ],
              ),
              Text(
                'يمكن اختيار محطتين إلى أربع محطات. هذه المقارنة جغرافية وتعتمد على بيانات الدليل فقط.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              ...stations.map((station) => _stationChoice(station)),
              const SizedBox(height: 16),
              if (selected.length >= 2) ...[
                Text('المقارنة الجغرافية',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        )),
                const SizedBox(height: 8),
                _referencePicker(selected),
                const SizedBox(height: 8),
                ...selected.map((station) => _comparisonCard(
                      station,
                      reference != null && reference.id != station.id
                          ? _distanceKm(reference, station)
                          : null,
                    )),
              ] else
                _state(
                  icon: Icons.compare_arrows,
                  title: 'اختر محطتين على الأقل',
                  message: 'ستظهر مقارنة الارتفاع والإحداثيات والمسافة عند تحديد محطتين.',
                ),
              const SizedBox(height: 20),
              const Text(
                'تنبيه علمي: اختلاف الارتفاع والموقع عاملان مهمان عند تفسير الفروق الجوية، لكنهما لا يكفيان وحدهما لاستنتاج حالة الطقس أو إجراء تصحيح للقياسات.',
                style: TextStyle(color: Color(0xFF64748B), height: 1.5),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _intro() => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              const Icon(Icons.query_stats, size: 30, color: Color(0xFF087CF0)),
              const SizedBox(height: 10),
              const Text('مراكز التنبؤ الجوي',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              SizedBox(height: 6),
              Text(
                'مساحة مقارنة المحطات والمناطق حسب الموقع والارتفاع، تمهيداً لعرض الرصدات الفعلية والنشرات بعد اعتماد مصدرها.',
                style: TextStyle(height: 1.5),
              ),
            ],
          ),
        ),
      );

  Widget _liveUnavailable() => Card(
        color: const Color(0xFFFFF7E8),
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              const Icon(Icons.sensors_off, color: Color(0xFF9A5B00)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('الرصدات اللحظية والنشرات غير متصلة',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 5),
                    Text(
                      'لا يوجد في عقد API الذي تمت مراجعته مصدر معتمد لقياسات الحرارة والضغط والرطوبة والأمطار والرياح أو تفاصيل النشرات. لن نعرض قيماً افتراضية على أنها رصد فعلي.',
                      style: TextStyle(height: 1.45),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Widget _stationChoice(StationDirectoryItem station) {
    final selected = _selectedIds.contains(station.id);
    final canAdd = selected || _selectedIds.length < 4;
    return Card(
      elevation: 0,
      child: CheckboxListTile(
        value: selected,
        onChanged: !canAdd && !selected
            ? null
            : (checked) {
                setState(() {
                  if (checked == true) {
                    _selectedIds.add(station.id);
                    _referenceId ??= station.id;
                  } else {
                    _selectedIds.remove(station.id);
                    if (_referenceId == station.id) {
                      _referenceId = _selectedIds.isEmpty ? null : _selectedIds.first;
                    }
                  }
                });
              },
        title: Text(station.nameArabic,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${station.localCode} • ${_typeLabel(station.stationType)} • الارتفاع: ${_elevation(station)}',
        ),
        secondary: const Icon(Icons.location_on_outlined),
        controlAffinity: ListTileControlAffinity.leading,
      ),
    );
  }

  Widget _referencePicker(List<StationDirectoryItem> selected) => DropdownButtonFormField<String>(
        initialValue: selected.any((s) => s.id == _referenceId)
            ? _referenceId
            : selected.first.id,
        decoration: const InputDecoration(
          labelText: 'المحطة المرجعية لحساب المسافات',
          border: OutlineInputBorder(),
        ),
        items: selected
            .map((s) => DropdownMenuItem(value: s.id, child: Text(s.nameArabic)))
            .toList(),
        onChanged: (value) => setState(() => _referenceId = value),
      );

  Widget _comparisonCard(StationDirectoryItem station, double? distanceKm) {
    final isReference = station.id == _referenceId;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(station.nameArabic,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                if (isReference)
                  const Chip(label: Text('مرجع المقارنة')),
              ],
            ),
            const Divider(),
            _metric('الرمز', station.localCode),
            _metric('النوع', _typeLabel(station.stationType)),
            _metric('الارتفاع', _elevation(station)),
            _metric('خط العرض', _coordinate(station.latitude)),
            _metric('خط الطول', _coordinate(station.longitude)),
            _metric('مصدر الإحداثيات', station.coordinateSource ?? 'غير موثق'),
            _metric('دقة الإحداثيات', station.coordinateAccuracyM == null
                ? 'غير متوفرة'
                : '${station.coordinateAccuracyM!.toStringAsFixed(1)} م'),
            if (isReference)
              _metric('المسافة من المرجع', '0 كم')
            else
              _metric('المسافة من المرجع', distanceKm == null
                  ? 'غير قابلة للحساب — الإحداثيات غير صالحة'
                  : '${distanceKm.toStringAsFixed(1)} كم'),
          ],
        ),
      ),
    );
  }

  Widget _metric(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 128,
              child: Text(label,
                  style: const TextStyle(color: Color(0xFF64748B))),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );

  Widget _state({
    required IconData icon,
    required String title,
    required String message,
    Widget? action,
  }) =>
      Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 40, color: const Color(0xFF64748B)),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(message, textAlign: TextAlign.center),
              if (action != null) ...[const SizedBox(height: 12), action],
            ],
          ),
        ),
      );

  String _typeLabel(String type) => switch (type) {
        'classic' => 'كلاسيكية',
        'automatic' => 'آلية',
        'synoptic' => 'سينوبتيكية',
        _ => type,
      };

  String _elevation(StationDirectoryItem station) => station.elevationM == null
      ? 'غير متوفر'
      : '${station.elevationM!.toStringAsFixed(1)} م';

  String _coordinate(double? value) =>
      value == null ? 'غير متوفر' : value.toStringAsFixed(5);

  double? _distanceKm(StationDirectoryItem a, StationDirectoryItem b) {
    if (!a.hasValidCoordinates || !b.hasValidCoordinates) return null;
    const earthRadiusKm = 6371.0088;
    final lat1 = _radians(a.latitude!);
    final lat2 = _radians(b.latitude!);
    final deltaLat = _radians(b.latitude! - a.latitude!);
    final deltaLon = _radians(b.longitude! - a.longitude!);
    final haversine = math.pow(math.sin(deltaLat / 2), 2) +
        math.cos(lat1) * math.cos(lat2) *
            math.pow(math.sin(deltaLon / 2), 2);
    final bounded = haversine.clamp(0.0, 1.0);
    return 2 * earthRadiusKm *
        math.asin(math.sqrt(bounded.toDouble()));
  }

  double _radians(double degrees) => degrees * math.pi / 180;
}
