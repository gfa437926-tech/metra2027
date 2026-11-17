import 'package:material_ui/material_ui.dart';

import '../../core/api/metra_api_client.dart';
import '../../core/catalog/observation_field_catalogs.dart';
import '../../core/catalog_integration/catalog_form_type.dart';
import 'catalog_observation_screen.dart';
import 'daily_observation_screen.dart';
import 'hourly_observation_screen.dart';
import 'observation_review_screen.dart';
import 'phenomenon_observation_screen.dart';

const _navy = Color(0xFF061B4A);
const _blue = Color(0xFF087CF0);

/// Observation workspace: approved server-backed forms + local-only catalogues.
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
    return DefaultTabController(
      length: 11,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            const Material(
              color: Colors.white,
              child: TabBar(
                isScrollable: true,
                labelColor: _navy,
                indicatorColor: _blue,
                tabs: [
                  Tab(text: 'ساعي · متصل'),
                  Tab(text: 'يومي · متصل'),
                  Tab(text: 'ظاهرة · متصل'),
                  Tab(text: 'زراعي'),
                  Tab(text: 'مناخي ساعي'),
                  Tab(text: 'أمطار'),
                  Tab(text: 'تربة'),
                  Tab(text: 'أعطال أجهزة'),
                  Tab(text: 'اتصالات'),
                  Tab(text: 'تقنية المعلومات'),
                  Tab(text: 'مراجعة · متصل'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  HourlyObservationScreen(api: api, stationId: stationId),
                  DailyObservationScreen(api: api, stationId: stationId),
                  PhenomenonObservationScreen(api: api, stationId: stationId),
                  CatalogObservationScreen(
                    title: 'الرصد الزراعي',
                    fields: ObservationFieldCatalogs.agricultural,
                    formCode: 'agricultural',
                    stationId: stationId,
                    formType: CatalogFormType.agricultural,
                  ),
                  CatalogObservationScreen(
                    title: 'الرصد المناخي الساعي',
                    fields: ObservationFieldCatalogs.hourlyclimate,
                    formCode: 'hourlyclimate',
                    stationId: stationId,
                    formType: CatalogFormType.hourlyClimate,
                  ),
                  CatalogObservationScreen(
                    title: 'رصد الأمطار',
                    fields: ObservationFieldCatalogs.rainfall,
                    formCode: 'rainfall',
                    stationId: stationId,
                    formType: CatalogFormType.rainfall,
                  ),
                  CatalogObservationScreen(
                    title: 'رصد التربة',
                    fields: ObservationFieldCatalogs.soil,
                    formCode: 'soil',
                    stationId: stationId,
                    formType: CatalogFormType.soil,
                  ),
                  CatalogObservationScreen(
                    title: 'أعطال الأجهزة',
                    fields: ObservationFieldCatalogs.faultequipment,
                    formCode: 'faultequipment',
                    stationId: stationId,
                    formType: CatalogFormType.faultEquipment,
                  ),
                  CatalogObservationScreen(
                    title: 'أعطال الاتصالات',
                    fields: ObservationFieldCatalogs.faulttelecom,
                    formCode: 'faulttelecom',
                    stationId: stationId,
                    formType: CatalogFormType.faultTelecom,
                  ),
                  CatalogObservationScreen(
                    title: 'بلاغات تقنية المعلومات',
                    fields: ObservationFieldCatalogs.faultit,
                    formCode: 'faultit',
                    stationId: stationId,
                    formType: CatalogFormType.faultIt,
                  ),
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
