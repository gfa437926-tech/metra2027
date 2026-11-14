import 'package:flutter_test/flutter_test.dart';
import 'package:metra_mobile/core/api/service_readiness.dart';

void main() {
  test('observation writes remain gated until scientific approval and atomic RPC deployment', () {
    expect(MetraServiceReadiness.observationSubmit, MetraDataSourceMode.gated);
    expect(MetraServiceReadiness.observationDecision, MetraDataSourceMode.gated);
    expect(MetraServiceReadiness.observationArchive, MetraDataSourceMode.mock);
  });

  test('non-scientific reads use live API contracts while unavailable services fail closed', () {
    expect(MetraServiceReadiness.stationDirectory, MetraDataSourceMode.liveApi);
    expect(MetraServiceReadiness.stationAudit, MetraDataSourceMode.liveApi);
    expect(MetraServiceReadiness.observationQueue, MetraDataSourceMode.liveApi);
    expect(MetraServiceReadiness.stationUsers, MetraDataSourceMode.liveApi);
    expect(MetraServiceReadiness.registrationRead, MetraDataSourceMode.liveApi);
    expect(MetraServiceReadiness.authorityAccessRead, MetraDataSourceMode.liveApi);
  });
}
