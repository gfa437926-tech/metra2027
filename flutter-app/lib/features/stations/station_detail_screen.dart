import 'package:flutter/material.dart';

import '../../core/api/metra_api_client.dart';

class StationDetailScreen extends StatelessWidget {
  const StationDetailScreen({super.key, required this.station});

  final StationDirectoryItem station;

  String _stationType(String value) => switch (value) {
        'classic' => 'كلاسيكية',
        'automatic' => 'آلية',
        'synoptic' => 'سينوبتيكية',
        _ => 'غير محدد',
      };

  String _status(String value) => switch (value.toLowerCase()) {
        'active' => 'فعالة',
        'inactive' => 'غير فعالة',
        'unverified' => 'غير متحقق منها',
        'approved' => 'معتمدة',
        'pending' => 'بانتظار الاعتماد',
        'rejected' => 'مرفوضة',
        _ => value.isEmpty ? 'غير محدد' : value,
      };

  @override
  Widget build(BuildContext context) {
    final coordinates = station.hasValidCoordinates
        ? '${station.latitude!.toStringAsFixed(5)}, ${station.longitude!.toStringAsFixed(5)}'
        : 'لا توجد إحداثيات صالحة موثقة';
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('تفاصيل المحطة')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.sensors, size: 34),
                    const SizedBox(height: 12),
                    Text(station.nameArabic,
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 4),
                    Text(station.nameEnglish),
                    const SizedBox(height: 12),
                    SelectableText('رمز المحطة: ${station.localCode}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            _section('التصنيف والحالة', [
              _detail('نوع المحطة', _stationType(station.stationType)),
              _detail('الحالة التشغيلية', _status(station.operationalStatus)),
              _detail('حالة الاعتماد', _status(station.approvalStatus)),
              _detail('سجل تجريبي', station.isDemo ? 'نعم' : 'لا'),
            ]),
            const SizedBox(height: 10),
            _section('الموقع الجغرافي', [
              _detail('الإحداثيات', coordinates),
              _detail('الارتفاع', station.elevationM == null
                  ? 'غير متوفر'
                  : '${station.elevationM!.toStringAsFixed(1)} متر'),
              _detail('مصدر الإحداثيات',
                  station.coordinateSource ?? 'غير موثق'),
              _detail('دقة الإحداثيات', station.coordinateAccuracyM == null
                  ? 'غير متوفرة'
                  : '${station.coordinateAccuracyM!.toStringAsFixed(1)} متر'),
              _detail('معرّف WMO', station.wmoStationId ?? 'غير متوفر'),
            ]),
            const SizedBox(height: 12),
            const Card(
              child: ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('مصدر التفاصيل'),
                subtitle: Text(
                  'هذه البيانات مأخوذة من سجل دليل المحطات. '
                  'لا تمثل قياسات جوية لحظية ولا تمنح صلاحية تعديل المحطة.',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Divider(),
              ...children,
            ],
          ),
        ),
      );

  Widget _detail(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: Text(label)),
            const SizedBox(width: 12),
            Expanded(flex: 3,
                child: SelectableText(value,
                    style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
      );
}
