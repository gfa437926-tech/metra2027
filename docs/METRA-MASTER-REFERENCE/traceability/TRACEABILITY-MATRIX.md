# مصفوفة التتبع

| FR | Screen | Fields | API | Role |
|---|---|---|---|---|
| FR-OBS-HOURLY | SCR-HOURLY | FLD-HOURLY-* | API-OBS-SUBMIT | ROLE-OBSERVER |
| FR-OBS-DAILY | SCR-DAILY | FLD-DAILY-* | API-OBS-SUBMIT | ROLE-OBSERVER |
| FR-OBS-REVIEW | SCR-REVIEW | — | API-OBS-QUEUE/DECISION | Head/Auditor |
| FR-STATION-DIR | SCR-STATIONS | — | API-STATIONS | auth |
| FR-ARCHIVE | SCR-ARCHIVE | — | API-ARCHIVE | granted |
| FR-FAULT-EQ | SCR-INSTRUMENTS | FLD-FAULT_EQUIPMENT-* | TBD | Workshop |
| FR-FAULT-TEL | — | FLD-FAULT_TELECOM-* | TBD | Telecom |
| FR-CLIMATOL | SCR-CLIMATOL | — | — | ROLE-CLIMATE |
| FR-AI | SCR-AI | — | — | ROLE-AI |

فجوات: agri/rain/soil بلا شاشة في الـ14؛ telecom بلا API؛ CLIMATOL/AI بلا محرك.
