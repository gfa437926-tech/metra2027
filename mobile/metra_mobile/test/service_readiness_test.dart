import 'package:flutter_test/flutter_test.dart';
import 'package:metra_mobile/core/api/service_readiness.dart';

void main() {
  test('non-production observation workflows are not classified as live API', () {
    expect(MetraServiceReadiness.observationSubmit, MetraDataSourceMode.mock);
    expect(MetraServiceReadiness.observationArchive, MetraDataSourceMode.mock);
  });

  test('implemented station and review reads retain live API classification', () {
    expect(MetraServiceReadiness.stationDirectory, MetraDataSourceMode.liveApi);
    expect(MetraServiceReadiness.stationAudit, MetraDataSourceMode.liveApi);
    expect(MetraServiceReadiness.observationQueue, MetraDataSourceMode.liveApi);
  });
}
