import 'package:flutter/material.dart';
import '../../core/api/metra_api_client.dart';
import 'daily_observation_screen.dart';
import 'hourly_observation_screen.dart';
import 'observation_review_screen.dart';

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
        length: 3,
        child: Column(
          children: [
            Material(
              color: Colors.white,
              child: TabBar(
                labelColor: _navy,
                indicatorColor: _blue,
                tabs: const [
                  Tab(text: 'رصد ساعي'),
                  Tab(text: 'رصد يومي'),
                  Tab(text: 'مراجعة'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  HourlyObservationScreen(api: api, stationId: stationId),
                  DailyObservationScreen(api: api, stationId: stationId),
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
