/// Classification of Flutter ↔ backend readiness for METRA mobile.
/// Live binding is allowed only when API contract + backend + tests exist.
/// Mock must never be presented as production data in UI labels.
enum MetraDataSourceMode { mock, gated, liveApi }

class MetraServiceReadiness {
  const MetraServiceReadiness._();

  /// Supabase Auth is used for session tokens; API calls use Bearer to .NET.
  static const authentication = MetraDataSourceMode.liveApi;

  /// Station directory requires configured METRA_API_BASE_URL.
  static const stationDirectory = MetraDataSourceMode.liveApi;

  /// Client calls live .NET endpoints; unavailable backends surface 401/403/503.
  static const stationAudit = MetraDataSourceMode.liveApi;
  static const observationQueue = MetraDataSourceMode.liveApi;
  static const stationUsers = MetraDataSourceMode.liveApi;
  static const registrationRead = MetraDataSourceMode.liveApi;
  static const authorityAccessRead = MetraDataSourceMode.liveApi;

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

  /// Station operational audit via .NET audit-log (not observation provenance).
  static const electronicAuditUi = MetraDataSourceMode.liveApi;
}
