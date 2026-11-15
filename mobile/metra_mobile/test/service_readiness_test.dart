import 'package:flutter_test/flutter_test.dart';
import 'package:metra_mobile/core/api/service_readiness.dart';

void main() {
  test('observation writes remain gated until scientific approval and atomic RPC deployment', () {
    expect(MetraServiceReadiness.observationSubmit, MetraDataSourceMode.gated);
    expect(MetraServiceReadiness.observationDecision, MetraDataSourceMode.gated);
    expect(MetraServiceReadiness.observationArchive, MetraDataSourceMode.mock);
  });

  test('schema-incompatible API workflows remain gated despite existing HTTP endpoints', () {
    expect(MetraServiceReadiness.stationDirectory, MetraDataSourceMode.gated);
    expect(MetraServiceReadiness.stationAudit, MetraDataSourceMode.gated);
    expect(MetraServiceReadiness.observationQueue, MetraDataSourceMode.gated);
    expect(MetraServiceReadiness.stationUsers, MetraDataSourceMode.gated);
    expect(MetraServiceReadiness.registrationRead, MetraDataSourceMode.gated);
    expect(MetraServiceReadiness.authorityAccessRead, MetraDataSourceMode.gated);
    expect(MetraServiceReadiness.electronicAuditUi, MetraDataSourceMode.gated);
    expect(MetraServiceReadiness.authentication, MetraDataSourceMode.liveApi);
  });
}
