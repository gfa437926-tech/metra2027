# 10 — API Inventory

| API ID | Method | Route | الحالة |
|---|---|---|---|
| API-OBS-SUBMIT | POST | /api/v1/stations/{stationId}/observations | gate |
| API-OBS-DECISION | POST | .../observations/{id}/decision | gate |
| API-OBS-QUEUE | GET | .../stations/{stationId}/observations | منفّذ |
| API-OBS-VALIDATE-DAILY | POST | /api/v1/observations/daily/validate | منفّذ |
| API-OBS-VALIDATE-HOURLY | POST | /api/v1/observations/hourly/validate | منفّذ |
| API-OBS-VALIDATE-PHENO | POST | /api/v1/observations/phenomena/validate | منفّذ |
| API-STATIONS | GET | /api/v1/stations | منفّذ |
| API-STATIONS-V2 | GET | /api/v2/stations | منفّذ |
| API-STATION-REVIEW | POST | .../stations/{id}/review | منفّذ |
| API-STATION-AUDIT | GET | .../audit-log | منفّذ |
| API-STATION-USERS | GET | .../users | منفّذ |
| API-ARCHIVE | GET | .../observation-archive | **503** |
| API-ARCHIVE-ITEM | GET | .../observation-archive/{id} | **503** |
| API-AUTH-* | POST/GET | authorities/... | منفّذ |
| API-REG-ROLES | GET | /api/v1/registration-roles | منفّذ |
| API-REG-STATUS | GET | /api/v1/account/registration-status | منفّذ |

غير موجود: API-CLIMATOL · API-AI · API-OCR · API-FAULT-CRUD
