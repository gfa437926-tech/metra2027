/// Classification of Flutter ↔ backend readiness for METRA mobile.
/// Live binding is allowed only when API contract + backend + tests exist.
/// Mock must never be presented as production data in UI labels.
enum MetraDataSourceMode { mock, gated, liveApi }

class MetraServiceReadiness {
  const MetraServiceReadiness._();

  /// Supabase Auth is used for session tokens; API calls use Bearer to .NET.
  static const authentication = MetraDataSourceMode.liveApi;

  /// The HTTP endpoints exist, but the current adapters still target absent
  /// legacy public tables/RPCs. Keep these workflows gated until greenfield
  /// persistence contracts and least-privilege integration tests are deployed.
  static const stationDirectory = MetraDataSourceMode.gated;
  static const stationAudit = MetraDataSourceMode.gated;
  static const observationQueue = MetraDataSourceMode.gated;
  static const stationUsers = MetraDataSourceMode.gated;
  static const registrationRead = MetraDataSourceMode.gated;
  static const authorityAccessRead = MetraDataSourceMode.gated;

  /// The .NET submission endpoint exists, but the scientific-contract feature gate
  /// is not approved and the required atomic RPC may not be deployed hosted.
  static const observationSubmit = MetraDataSourceMode.gated;

  /// The decision endpoint exists; atomic authorization RPC may not be hosted yet.
  static const observationDecision = MetraDataSourceMode.gated;

  /// Archive API remains fail-closed (503) until a real archive service exists.
  static const observationArchive = MetraDataSourceMode.mock;

  static const aiWorkspace = MetraDataSourceMode.mock;
  static const climatol = MetraDataSourceMode.mock;
  static const forecastCentres = MetraDataSourceMode.mock;

  /// Station operational audit endpoint is not yet mapped to the greenfield audit schema.
  static const electronicAuditUi = MetraDataSourceMode.gated;
}
