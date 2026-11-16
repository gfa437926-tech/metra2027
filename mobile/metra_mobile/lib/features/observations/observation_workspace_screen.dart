import 'package:material_ui/material_ui.dart';
import '../../core/api/metra_api_client.dart';
import 'daily_observation_screen.dart';
import 'hourly_observation_screen.dart';
import 'observation_review_screen.dart';
import 'catalog_observation_screen.dart';
import '../../core/catalog/observation_field_catalogs.dart';

const _navy = Color(0xFF061B4A);
const _blue = Color(0xFF087CF0);

/// Single observation destination: entry forms + review without nested sidebars.
class ObservationWorkspaceScreen extends StatelessWidget {
  const ObservationWorkspaceScreen({
    super.key,
    required this.api,
    required this.stationId,
  });

  final MetraApiClient api;
  final String stationId;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: DefaultTabController(
        length: 10,
        child: Column(
          children: [
            const Material(
              color: Colors.white,
              child: TabBar(
                isScrollable: true,
                labelColor: _navy,
                indicatorColor: _blue,
                tabs: [
                  Tab(text: 'رصد ساعي'),
                  Tab(text: 'رصد يومي'),
                  Tab(text: 'زراعي'),
                  Tab(text: 'مناخي ساعي'),
                  Tab(text: 'أمطار'),
                  Tab(text: 'تربة'),
                  Tab(text: 'أعطال أجهزة'),
                  Tab(text: 'اتصالات'),
                  Tab(text: 'تقنية المعلومات'),
                  Tab(text: 'مراجعة'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  HourlyObservationScreen(api: api, stationId: stationId),
                  DailyObservationScreen(api: api, stationId: stationId),
                  const CatalogObservationScreen(title: 'الرصد الزراعي', fields: ObservationFieldCatalogs.agricultural),
                  const CatalogObservationScreen(title: 'الرصد المناخي الساعي', fields: ObservationFieldCatalogs.hourlyclimate),
                  const CatalogObservationScreen(title: 'رصد الأمطار', fields: ObservationFieldCatalogs.rainfall),
                  const CatalogObservationScreen(title: 'رصد التربة', fields: ObservationFieldCatalogs.soil),
                  const CatalogObservationScreen(title: 'أعطال الأجهزة', fields: ObservationFieldCatalogs.faultequipment),
                  const CatalogObservationScreen(title: 'أعطال الاتصالات', fields: ObservationFieldCatalogs.faulttelecom),
                  const CatalogObservationScreen(title: 'بلاغات تقنية المعلومات', fields: ObservationFieldCatalogs.faultit),
                  ObservationReviewScreen(api: api, stationId: stationId),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
