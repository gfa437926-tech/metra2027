import 'package:material_ui/material_ui.dart';

import '../../core/api/metra_api_client.dart';
import '../../core/auth/metra_access_context.dart';
import '../../core/catalog/observation_field_catalogs.dart';
import '../../core/catalog_integration/catalog_form_type.dart';
import '../../core/drafts/observation_draft_store.dart';
import '../../core/widgets/metra_observation_form.dart';
import '../../core/widgets/metra_permission_denied_page.dart';
import 'catalog_observation_screen.dart';
import 'daily_observation_screen.dart';
import 'hourly_observation_screen.dart';
import 'observation_review_screen.dart';
import 'phenomenon_observation_screen.dart';

const _navy = Color(0xFF061B4A);
const _blue = Color(0xFF087CF0);

/// Observation workspace: server-backed forms and explicitly local catalogues.
///
/// Fails closed when the server access context is absent or unresolved.
/// Tab labels show a local-draft marker when a session draft exists for the
/// active station (does not claim server persistence).
class ObservationWorkspaceScreen extends StatefulWidget {
  const ObservationWorkspaceScreen({
    super.key,
    required this.api,
    required this.stationId,
    this.accessContext,
  });

  final MetraApiClient api;
  final String stationId;
  final MetraAccessContext? accessContext;

  @override
  State<ObservationWorkspaceScreen> createState() =>
      _ObservationWorkspaceScreenState();
}

class _ObservationWorkspaceScreenState
    extends State<ObservationWorkspaceScreen> {
  @override
  void initState() {
    super.initState();
    ObservationDraftStore.instance.addListener(_onDraftsChanged);
  }

  @override
  void dispose() {
    ObservationDraftStore.instance.removeListener(_onDraftsChanged);
    super.dispose();
  }

  void _onDraftsChanged() {
    if (mounted) setState(() {});
  }

  bool get _canEnter =>
      widget.accessContext?.isResolved == true &&
      widget.accessContext!.canEnterObservations(widget.stationId);

  bool get _canReview =>
      widget.accessContext?.isResolved == true &&
      widget.accessContext!.canReviewObservations(widget.stationId);

  String _tabLabel(String base, String formType) {
    final has = ObservationDraftStore.instance.hasDraft(
      widget.stationId,
      formType,
    );
    return has ? '$base · مسودة' : base;
  }

  @override
  Widget build(BuildContext context) {
    final tabs = <Tab>[];
    final views = <Widget>[];
    final stationId = widget.stationId;
    final api = widget.api;
    final accessContext = widget.accessContext;

    if (_canEnter) {
      tabs.addAll([
        Tab(text: _tabLabel('ساعي · متصل', 'hourly')),
        Tab(text: _tabLabel('يومي · متصل', 'daily')),
        Tab(text: _tabLabel('ظاهرة · متصل', 'phenomenon')),
      ]);
      views.addAll([
        HourlyObservationScreen(
          key: ValueKey('hourly-$stationId'),
          api: api,
          stationId: stationId,
        ),
        DailyObservationScreen(
          key: ValueKey('daily-$stationId'),
          api: api,
          stationId: stationId,
        ),
        PhenomenonObservationScreen(
          key: ValueKey('phenomenon-$stationId'),
          api: api,
          stationId: stationId,
        ),
      ]);

      void addCatalog({
        required String tabLabel,
        required String title,
        required List<MetraObservationField> fields,
        required String formCode,
        required CatalogFormType formType,
      }) {
        tabs.add(Tab(text: _tabLabel(tabLabel, formType.code)));
        views.add(
          CatalogObservationScreen(
            key: ValueKey('catalog-${formType.code}-$stationId'),
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
    }

    if (_canReview) {
      tabs.add(const Tab(text: 'مراجعة · متصل'));
      views.add(
        ObservationReviewScreen(
          key: ValueKey('review-$stationId'),
          api: api,
          stationId: stationId,
        ),
      );
    }

    if (tabs.isEmpty) {
      final message = accessContext?.isResolved == true
          ? MetraPermissionDeniedMessages.observations
          : MetraPermissionDeniedMessages.contextUnavailable;
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 40, color: _navy),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _navy, height: 1.5),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final draftTypes = ObservationDraftStore.instance.formTypesWithDrafts(
      stationId,
    );
    final hasDrafts = draftTypes.isNotEmpty;

    // Key resets controller when station or permitted tab set changes so length
    // never mismatches an old TabController (fail-safe across station switch).
    return DefaultTabController(
      key: ValueKey<String>(
        'obs-ws-$stationId-${tabs.length}-$_canEnter-$_canReview',
      ),
      length: tabs.length,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            if (hasDrafts)
              Material(
                color: const Color(0xFFFFF7E8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.edit_note, color: Color(0xFF9A6700)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'مسودات محلية لهذه المحطة: ${draftTypes.length} '
                          '(${draftTypes.take(4).join('، ')}'
                          '${draftTypes.length > 4 ? '…' : ''})',
                          style: const TextStyle(
                            color: Color(0xFF7C5E10),
                            height: 1.35,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          ObservationDraftStore.instance.clearStation(
                            stationId,
                          );
                        },
                        child: const Text('مسح الكل'),
                      ),
                    ],
                  ),
                ),
              ),
            Material(
              color: Colors.white,
              child: TabBar(
                isScrollable: true,
                labelColor: _navy,
                indicatorColor: _blue,
                tabs: tabs,
              ),
            ),
            Expanded(child: TabBarView(children: views)),
          ],
        ),
      ),
    );
  }
}
