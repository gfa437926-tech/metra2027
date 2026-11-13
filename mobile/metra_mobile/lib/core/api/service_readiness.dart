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
  static const stationAudit = MetraDataSourceMode.liveApi;
  static const observationQueue = MetraDataSourceMode.liveApi;
  /// Hourly/daily forms currently save an in-session draft only; no live write API.\n  static const observationSubmit = MetraDataSourceMode.mock;
  static const observationDecision = MetraDataSourceMode.liveApi;

  /// Archive API remains fail-closed (503) until a real archive service exists.
  static const observationArchive = MetraDataSourceMode.mock;

  static const aiWorkspace = MetraDataSourceMode.mock;
  static const climatol = MetraDataSourceMode.mock;
  static const forecastCentres = MetraDataSourceMode.mock;
  static const electronicAuditUi = MetraDataSourceMode.mock;
}
