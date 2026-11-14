# METRA 2027 — Flutter UI Requirements Traceability (UI phase)

| Requirement area | Flutter location | Status |
|------------------|------------------|--------|
| Login / recovery | core/auth/metra_auth.dart | Existing (partial) |
| Registration / approval UI | features/admin/user_management_screen.dart | Scaffold present |
| Home / KPIs / shortcuts | features/home/metra_home.dart | Expanded |
| Station catalogue / map | features/stations/station_directory_screen.dart | Existing |
| Station audit | features/stations/station_audit_log_screen.dart | Existing |
| Hourly entry form | features/observations/hourly_observation_entry_screen.dart | Scaffold + field groups |
| Daily entry form | features/observations/daily_observation_entry_screen.dart | Scaffold + field groups |
| Observation review | features/observations/observation_review_screen.dart | Existing |
| Reports hub + archive | features/reports/* | Existing + preserved |
| Electronic audit | features/audit/electronic_audit_screen.dart | New read-only |
| Forecast centres | features/forecast_centres/forecast_centre_screen.dart | Existing |
| AI workspace | features/ai/ai_workspace_screen.dart | New |
| Climatol | features/climatol/climatol_workspace_screen.dart | New |
| Settings | features/home/metra_home.dart (_SettingsPage) | Expanded |
| Design system | core/widgets/metra_ui.dart | New |

Scientific acceptance remains gated by source contracts; UI completeness does not equal scientific completeness.
