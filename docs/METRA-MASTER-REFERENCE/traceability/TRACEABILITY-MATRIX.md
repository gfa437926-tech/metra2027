# مصفوفة التتبع المركزية

**التحقق الآلي:** `ok=true` · issues=0 (الروابط المعرفة)

| FR | SCR | #Fields | API | Status |
|---|---|---|---|---|
| FR-HOME | SCR-HOME | 0 | — | UI present |
| FR-STATION-DIR | SCR-STATIONS | 0 | API-STATIONS | liveApi partial |
| FR-STATION-AUDIT | SCR-STATION-AUDIT / SCR-AUDIT | 0 | API-STATION-AUDIT | liveApi |
| FR-FORECAST | SCR-FORECAST | 0 | — | gated/mock |
| FR-OBS-HOURLY | SCR-HOURLY | 36 | API-OBS-SUBMIT, VALIDATE-HOURLY | UI + gated |
| FR-OBS-DAILY | SCR-DAILY | 32 | API-OBS-SUBMIT, VALIDATE-DAILY | UI + gated |
| FR-OBS-REVIEW / QUEUE | SCR-REVIEW | 0 | API-OBS-QUEUE, DECISION | UI + gated |
| FR-REPORTS | SCR-REPORTS | 0 | — | UI catalogue |
| FR-ARCHIVE | SCR-ARCHIVE | 0 | API-ARCHIVE | 503 fail-closed |
| FR-AI | SCR-AI | 0 | — | UI only |
| FR-CLIMATOL | SCR-CLIMATOL | 0 | — | UI only |
| FR-USERS-REG / AUTH-GRANT | SCR-USERS | 0 | API-REG/AUTH | partial |
| FR-SETTINGS | SCR-SETTINGS | 0 | auth | present |
| FR-RECORDS | SCR-RECORDS | 0 | — | UI only |
| FR-FAULT-EQ / INSTRUMENTS | SCR-INSTRUMENTS | 15 | — | UI sections |
| FR-OBS-AGRI | — | 31 | — | legacy only U-03 |
| FR-OBS-RAIN | — | 7 | — | legacy only U-03 |
| FR-OBS-SOIL | — | 7 | — | legacy only U-03 |
| FR-OBS-HCLIMATE | — | 15 | — | legacy only U-03 |
| FR-FAULT-TEL | — | 21 | API-FAULT-* مقترح | U-04 |
| FR-FAULT-IT | — | 10 | API-FAULT-* مقترح | U-04 |

انظر `AUTO-VERIFY-RESULT.json` و `traceability-matrix.json`.
