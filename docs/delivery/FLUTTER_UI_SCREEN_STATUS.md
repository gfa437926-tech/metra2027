# Flutter UI screen status (source audit)

Branch work as of local HEAD after UI closure batch. Server contracts unchanged.

| Screen | Entry | Status | Notes |
|--------|-------|--------|-------|
| MetraConfigurationScreen | main when env missing | Complete | Honest missing config |
| MetraLoginScreen | AuthGate signed out | Complete | Sign-in, reset password |
| MetraHome / Overview | Nav home | Complete | Station label, access, drafts |
| StationDirectoryScreen | Nav stations | Complete | Select, map, details |
| ForecastCentreScreen | Nav forecast | Complete (API directory) | No live telemetry claim |
| ObservationWorkspaceScreen | Nav observations | Complete gated | Station banner, tabs |
| Hourly/Daily/Phenomenon | Workspace tabs | Complete | Server validate+submit |
| CatalogObservationScreen | Workspace tabs | Local-only complete | 7 form types |
| LocalCatalogRecordsScreen | Catalog button | Local-only complete | CRUD/export |
| ObservationReviewScreen | Workspace tab | Complete gated | Queue, decide, optimistic hide |
| StationAdministrationScreen | Nav admin | Complete gated | Users, reg, queue, audit |
| Climatol/RecordsAi/Ops/Reports | Nav | UI-only offline | Disabled + contract notice |
| SystemSettingsScreen | Nav settings | Complete | Account, notif, recovery, logout |
| AccountHubScreen | Settings/Account | Complete | Password, reg, recovery |
| RegistrationRequest/Status | Account | Complete | API-backed |
| NotificationsCenterScreen | Settings | Local-only | No server feed |
| LegacyDataRecoveryScreen | Settings/Account | Complete | Explicit claim |

No DB/schema/API inventions in this phase.
