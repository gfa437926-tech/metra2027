/// Classification of Flutter ↔ backend readiness for METRA mobile.
/// Live binding is allowed only when API contract + backend + tests exist.
/// Mock must never be presented as production data in UI labels.
enum MetraDataSourceMode { mock, liveApi }

class MetraServiceReadiness {
  const MetraServiceReadiness._();

  /// Supabase Auth is used for session tokens; API calls use Bearer to .NET.
  static const authentication = MetraDataSourceMode.liveApi;

  /// Station directory and audit require configured METRA_API_BASE_URL.
  static const stationDirectory = MetraDataSourceMode.liveApi;
  /// Atomic actor-bound read RPCs are not deployed to hosted Supabase yet.
  static const stationAudit = MetraDataSourceMode.mock;
  static const observationQueue = MetraDataSourceMode.mock;

  /// Hourly/daily forms currently save an in-session draft only; no live write API.
  static const observationSubmit = MetraDataSourceMode.mock;
  static const observationDecision = MetraDataSourceMode.liveApi;

  /// Archive API remains fail-closed (503) until a real archive service exists.
  static const observationArchive = MetraDataSourceMode.mock;

  static const aiWorkspace = MetraDataSourceMode.mock;
  static const climatol = MetraDataSourceMode.mock;
  static const forecastCentres = MetraDataSourceMode.mock;
  static const electronicAuditUi = MetraDataSourceMode.mock;
}
