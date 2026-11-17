import 'package:material_ui/material_ui.dart';

import '../../core/api/metra_api_client.dart';
import '../../core/auth/metra_access_context.dart';
import '../../core/catalog/observation_field_catalogs.dart';
import '../../core/catalog_integration/catalog_form_type.dart';
import '../../core/widgets/metra_observation_form.dart';
import 'catalog_observation_screen.dart';
import 'daily_observation_screen.dart';
import 'hourly_observation_screen.dart';
import 'observation_review_screen.dart';
import 'phenomenon_observation_screen.dart';

const _navy = Color(0xFF061B4A);
const _blue = Color(0xFF087CF0);

/// Observation workspace: approved server-backed forms + local-only catalogues.
///
/// Review tab is shown only when [accessContext] grants review permissions on
/// [stationId]. Server still enforces every mutation.
class ObservationWorkspaceScreen extends StatelessWidget {
  const ObservationWorkspaceScreen({
    super.key,
    required this.api,
    required this.stationId,
    this.accessContext,
  });

  final MetraApiClient api;
  final String stationId;
  final MetraAccessContext? accessContext;

  /// When context is absent (tests / legacy callers), keep connected entry tabs.
  bool get _canEnter {
    final access = accessContext;
    if (access == null || !access.isResolved) return true;
    return access.canEnterObservations(stationId);
  }

  /// Review tab only when server context grants review codes on this station.
  /// Absent context keeps the tab (server still enforces).
  bool get _canReview {
    final access = accessContext;
    if (access == null || !access.isResolved) return true;
    return access.canReviewObservations(stationId);
  }

  @override
  Widget build(BuildContext context) {
    final tabs = <Tab>[];
    final views = <Widget>[];

    if (_canEnter) {
      tabs.addAll(const [
        Tab(text: 'ساعي · متصل'),
        Tab(text: 'يومي · متصل'),
        Tab(text: 'ظاهرة · متصل'),
      ]);
      views.addAll([
        HourlyObservationScreen(api: api, stationId: stationId),
        DailyObservationScreen(api: api, stationId: stationId),
        PhenomenonObservationScreen(api: api, stationId: stationId),
      ]);
    }

    // Local-only catalogue forms (no server persistence contract yet).
    void addCatalog({
      required String tabLabel,
      required String title,
      required List<MetraObservationField> fields,
      required String formCode,
      required CatalogFormType formType,
    }) {
      tabs.add(Tab(text: tabLabel));
      views.add(
        CatalogObservationScreen(
          title: title,
          fields: fields,
          formCode: formCode,
          stationId: stationId,
          formType: formType,
        ),
      );
    }

    addCatalog(
      tabLabel: 'زراعي',
      title: 'الرصد الزراعي',
      fields: ObservationFieldCatalogs.agricultural,
      formCode: 'agricultural',
      formType: CatalogFormType.agricultural,
    );
    addCatalog(
      tabLabel: 'مناخي ساعي',
      title: 'الرصد المناخي الساعي',
      fields: ObservationFieldCatalogs.hourlyclimate,
      formCode: 'hourlyclimate',
      formType: CatalogFormType.hourlyClimate,
    );
    addCatalog(
      tabLabel: 'أمطار',
      title: 'رصد الأمطار',
      fields: ObservationFieldCatalogs.rainfall,
      formCode: 'rainfall',
      formType: CatalogFormType.rainfall,
    );
    addCatalog(
      tabLabel: 'تربة',
      title: 'رصد التربة',
      fields: ObservationFieldCatalogs.soil,
      formCode: 'soil',
      formType: CatalogFormType.soil,
    );
    addCatalog(
      tabLabel: 'أعطال أجهزة',
      title: 'أعطال الأجهزة',
      fields: ObservationFieldCatalogs.faultequipment,
      formCode: 'faultequipment',
      formType: CatalogFormType.faultEquipment,
    );
    addCatalog(
      tabLabel: 'اتصالات',
      title: 'أعطال الاتصالات',
      fields: ObservationFieldCatalogs.faulttelecom,
      formCode: 'faulttelecom',
      formType: CatalogFormType.faultTelecom,
    );
    addCatalog(
      tabLabel: 'تقنية المعلومات',
      title: 'بلاغات تقنية المعلومات',
      fields: ObservationFieldCatalogs.faultit,
      formCode: 'faultit',
      formType: CatalogFormType.faultIt,
    );

    if (_canReview) {
      tabs.add(const Tab(text: 'مراجعة · متصل'));
      views.add(ObservationReviewScreen(api: api, stationId: stationId));
    }

    return DefaultTabController(
      length: tabs.length,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            Material(
              color: Colors.white,
              child: TabBar(
                isScrollable: true,
                labelColor: _navy,
                indicatorColor: _blue,
                tabs: tabs,
              ),
            ),
            Expanded(
              child: TabBarView(children: views),
            ),
          ],
        ),
      ),
    );
  }
}
