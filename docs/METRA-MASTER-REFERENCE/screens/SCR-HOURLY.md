# SCR-HOURLY — رصد ساعي / Hourly Observation Entry

| Property | Value |
|---|---|
| Dart path | mobile/metra_mobile/lib/features/observations/hourly_observation_entry_screen.dart |
| Purpose | Enter hourly observation |
| Roles | Observer station-bound |
| API | submitObservation → POST /api/v1/stations/{id}/observations (FeatureGate) |
| Status | UI + gated submit |
| Field parity | Must match fields/hourly-observation-fields.md (36 legacy fields) |

Required states: loading, empty (no station), validation errors, 403, gate closed.
Acceptance: all required legacy fields or explicit waiver; server auth; tests T-OBS-*.
