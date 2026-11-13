import 'package:flutter_test/flutter_test.dart';
import 'package:metra_mobile/core/api/service_readiness.dart';

void main() {
  test('observation submission is wired to the API while archive remains gated', () {
    expect(MetraServiceReadiness.observationSubmit, MetraDataSourceMode.liveApi);
    expect(MetraServiceReadiness.observationArchive, MetraDataSourceMode.mock);
  });

  test('station catalogue remains live while gated atomic reads stay non-live until deployed', () {
    expect(MetraServiceReadiness.stationDirectory, MetraDataSourceMode.liveApi);
    expect(MetraServiceReadiness.stationAudit, MetraDataSourceMode.mock);
    expect(MetraServiceReadiness.observationQueue, MetraDataSourceMode.mock);
  });
}
