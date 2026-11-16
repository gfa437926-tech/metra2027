# Flutter Screen Specs

Source branch inspected: `work/flutter-full-interface-completion-2026-11-15`

| Screen ID | Arabic | Status (proven) | Dart path |
|---|---|---|---|
| SCR-HOME | الرئيسية | UI present | features/home/metra_home.dart |
| SCR-STATIONS | دليل المحطات | liveApi partial | features/stations/station_directory_screen.dart |
| SCR-STATION-AUDIT | سجل تدقيق المحطة | liveApi | features/stations/station_audit_log_screen.dart |
| SCR-FORECAST | مراكز التنبؤ | gated/mock | features/forecast_centres/forecast_centre_screen.dart |
| SCR-HOURLY | رصد ساعي | UI + gated submit | features/observations/hourly_observation_entry_screen.dart |
| SCR-DAILY | رصد يومي | UI + gated submit | features/observations/daily_observation_entry_screen.dart |
| SCR-REVIEW | مراجعة الرصدات | UI + gated decision | features/observations/observation_review_screen.dart |
| SCR-AUDIT | التدقيق الإلكتروني | liveApi | features/audit/electronic_audit_screen.dart |
| SCR-REPORTS | مركز التقارير | UI catalogue | features/reports/reports_hub_screen.dart |
| SCR-ARCHIVE | أرشيف الرصدات | 503 fail-closed | features/reports/observation_archive_screen.dart |
| SCR-AI | مختبر AI | UI only / mock | features/ai/ai_workspace_screen.dart |
| SCR-CLIMATOL | CLIMATOL | UI only / mock | features/climatol/climatol_workspace_screen.dart |
| SCR-USERS | المستخدمون | partial | features/admin/user_management_screen.dart |
| SCR-SETTINGS | الإعدادات | present | metra_home settings page |
| SCR-RECORDS | السجلات المصورة | UI only | features/records/records_review_workspace_screen.dart |
| SCR-INSTRUMENTS | الأجهزة | UI sections | features/instruments/instrument_management_screen.dart |

Detailed per-screen files: SCR-*.md in this folder (acceptance checklists; do not treat as complete implementation).
