# Logical Data Model (spec only — NOT applied)

Referenced names from project: station_catalogue, permission_grants, station_audit_log, metra_observations, station_assignments, metra_user_profiles; RPCs metra_submit_observation, metra_decide_observation, metra_user_has_station_permission.

```mermaid
erDiagram
  USER_PROFILE ||--o{ STATION_ASSIGNMENT : has
  STATION ||--o{ STATION_ASSIGNMENT : hosts
  STATION ||--o{ OBSERVATION : records
  OBSERVATION ||--o| OBSERVATION_DECISION : decided
  STATION ||--o{ STATION_AUDIT_LOG : audited
  AUTHORITY ||--o{ PERMISSION_GRANT : grants
  RECORD_IMAGE ||--o{ OCR_EXTRACTION : yields
```

No DDL executed in this task.
