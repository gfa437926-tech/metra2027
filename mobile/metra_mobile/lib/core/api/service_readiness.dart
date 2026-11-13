/// Classification of Flutter ↔ backend readiness for METRA mobile.
/// Live binding is allowed only when API contract + backend + tests exist.
/// Mock must never be presented as production data in UI labels.
enum MetraDataSourceMode { mock, gated, liveApi }

class MetraServiceReadiness {
  const MetraServiceReadiness._();

  /// Supabase Auth is used for session tokens; API calls use Bearer to .NET.
  static const authentication = MetraDataSourceMode.liveApi;

  /// Station directory and audit require configured METRA_API_BASE_URL.
  static const stationDirectory = MetraDataSourceMode.liveApi;
  /// Atomic actor-bound read RPCs are not deployed to hosted Supabase yet.
  static const stationAudit = MetraDataSourceMode.mock;
  static const observationQueue = MetraDataSourceMode.mock;

  /// The .NET submission endpoint exists, but the scientific-contract feature gate
  /// is not approved and the required atomic RPC is not deployed to the hosted DB.
  /// Keep the client explicitly gated until both deployment prerequisites are verified.
  static const observationSubmit = MetraDataSourceMode.gated;

  /// The decision endpoint exists, but its atomic authorization RPC is not deployed.
  static const observationDecision = MetraDataSourceMode.gated;

  /// Archive API remains fail-closed (503) until a real archive service exists.
  static const observationArchive = MetraDataSourceMode.mock;

  static const aiWorkspace = MetraDataSourceMode.mock;
  static const climatol = MetraDataSourceMode.mock;
  static const forecastCentres = MetraDataSourceMode.mock;
  static const electronicAuditUi = MetraDataSourceMode.mock;
}
