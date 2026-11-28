# METRA 2027 — API client coverage matrix (Flutter ↔ Backend)

**Date:** 2026-11-25  
**Branch:** `fix/flutter-quality-gates-2026-11-23`  
**Rule:** No invented endpoints. Gaps are explicit.

## Connected in Flutter client (`metra_api_client.dart`)

| Backend route | Flutter method | UI surface |
|---|---|---|
| `GET /api/v1/me/access-context` | `getAccessContext` | Home / navigation gating |
| `GET /api/v1/stations` | `getStationDirectory` / `getAllStationDirectory` | Station directory, forecast |
| `GET /api/v1/stations/{id}/observations` | `getReviewQueue` | Review + admin observations tab |
| `POST /api/v1/stations/{id}/observations` | `submitObservation` | Hourly/daily/phenomenon submit |
| `POST /api/v1/stations/{id}/observations/{obs}/decision` | `decideObservation` | Review decisions |
| `POST /api/v1/observations/hourly\|daily/validate` | `validateObservation` | Submit flow |
| `POST /api/v1/observations/phenomena/validate` | `validateObservation` | Phenomenon submit |
| `GET /api/v1/registration-roles` | `getRegistrationRoles` | Registration request |
| `GET /api/v1/account/registration-status` | `getMyRegistrationStatus` | Registration status |
| `POST /api/v1/registration-requests` | `submitRegistrationRequest` | Registration request |
| `GET /api/v1/stations/{id}/users` | `getStationUsers` | Admin users |
| `GET /api/v1/stations/{id}/registration-requests` | `getStationRegistrationRequests` | Admin registration queue |
| `POST .../registration-requests/{id}/decision` | `decideStationRegistrationRequest` | Admin approve/reject |
| `GET /api/v1/stations/{id}/audit-log` | `getStationAuditLog` | Admin audit |
| `GET /api/v1/stations/{id}/assignable-roles` | `getStationAssignableRoles` | Admin assignment form |
| `POST /api/v1/stations/{id}/assignments` | `requestStationAssignment` | Admin assignment form |
| `POST .../assignments/{id}/decision` | `decideStationAssignment` | Client ready; dedicated queue UI partial |

## Backend routes not wired in Flutter (existing contracts)

| Route group | Reason / next step |
|---|---|
| Station assignment **revoke** | `revokeStationAssignment` wired |
| System registration requests/audit | Chief-auditor flows; needs product UX scope |
| Authority memberships / permission-grants / access-queue | Authority-admin product surface; not station operator app |
| `POST /api/v1/stations/{id}/review` (catalogue review) | Station catalogue workflow; separate from observation review |

## Explicitly local-only (no approved persistence contract)

Rainfall, soil, agricultural, hourly climate, fault equipment/telecom/IT forms — validation + drafts only until M1–M4 approval.

## Explicitly offline shells (no service contract)

Notifications feed, CLIMATOL engine, AI, OCR, archive file store, production report export.
