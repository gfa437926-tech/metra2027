# METRA 2027 — Project Completion Tracker

**Last updated:** 2026-11-25  
**Branch:** `fix/flutter-quality-gates-2026-11-23`  
**HEAD (local):** `e2f6a208dcaf9c7edf83d0c41d7e40bd4a74cbc5`  
**Scope:** Flutter app `mobile/metra_mobile/` only  
**Constraints:** No DB/SQL/migrations/RLS/RPC/M1–M4 without explicit approval. No invented API endpoints.

---

## 1. Unit inventory (Flutter)

### Core
| Module | Status | Notes |
|--------|--------|-------|
| API client (`metra_api_client`) | Connected | Timeouts, access-context, stations, review, validate/submit observation, registration, station admin lists |
| Access context | Fail-closed | Destination visibility + station permission codes |
| Auth / secure session | Connected | Supabase + FlutterSecureStorage |
| Registration field rules | Local complete | UUID, phone, name, email optional, password, confirm |
| Observation draft store | Local complete | ChangeNotifier, station-scoped, secret filter, draftsForStation |
| Observation submit flow | Connected | Shared validate+submit for hourly/daily/phenomenon |
| Rainfall/soil local rules | Local complete | Negative rain, calendar date, future date reject |
| Notification preferences | Local session | ChangeNotifier; no push service |
| Error presenter | Complete | Queue/load/auth mapping |
| Theme / adaptive nav / async panel / permission denied | Complete | RTL-ready |

### Features / screens
| Screen | Status | Server contract |
|--------|--------|-----------------|
| Home / navigation | Complete | Access-context gated |
| Login / auth shell | Complete | Supabase |
| Account hub | Complete | Password change, registration status link |
| Registration request | Complete | Local validators + submit API |
| Station directory | Complete | Search (name/code/WMO/id/type), map, mine filter |
| Station administration | Complete | Users, registration requests decide, audit, queue |
| Observation workspace | Complete | Live draft tab markers + station draft overview bar |
| Hourly / Daily / Phenomenon | Connected | Draft + submit flow |
| Catalog forms (7 types) | Local-only | Validation + draft; no server persist (honest message) |
| Observation review | Connected | Filter, sort by observedAt, station mismatch guard, decide |
| Notifications center | Local shell | Prefs only; empty feed (no synthetic rows) |
| System settings | Complete | Account link, offline notices |
| Forecast centre | Honest offline | No measurement contract — no fake values |
| CLIMATOL / AI / OCR / Archive / Comparison / Operations / Reports | Honest offline | Period validation + day count; actions disabled with tooltips |

---

## 2. Server-connected vs local-only

**Connected (real API methods used):**
- Access context
- Station directory (paged + all)
- Observation validate + submit (hourly / daily / phenomenon)
- Review queue + decide (approve / return)
- Registration roles, my status, submit request
- Station users, registration requests + decide, audit log

**Local-only (by design until contracts / M1–M4):**
- Rainfall, soil, agricultural, hourly climate, fault equipment/telecom/IT forms
- Notification delivery
- CLIMATOL, AI, OCR, archive file storage, comparison metrics, production reports export
- Draft persistence across app restarts (session memory only; no shared_preferences dep)

---

## 3. Waiting on external approval

| Item | Blocked action |
|------|----------------|
| M1 | DB CHECK/RPC expansion for catalog observation types |
| M2 | event_type / audit structure |
| M3 | .NET guards/validators expansion |
| M4 | Server persistence for catalog forms |
| Notification service contract | Real push/feed |
| CLIMATOL / AI / OCR / archive / report export contracts | Execution paths |

---

## 4. Recent local commits (this line of work)

```
e2f6a20 fix(flutter): shared observationDate calendar and future guards for catalogs
3c8f38a test(flutter): cover agricultural/fault catalog validation and account states
c3efa22 fix(flutter): reject whitespace-only login passwords client-side
22c2d62 docs: add PROJECT_COMPLETION_TRACKER for continuous completion resume
2860289 refactor(flutter): centralize account password rules via RegistrationFieldRules
3ea3ce7 feat(flutter): match station directory query on id and type fields
fcd7e52 fix(flutter): reject future observation dates on rainfall/soil local forms
eb48374 fix(flutter): sort review queue by observedAt descending locally
d4816ad feat(flutter): station draft overview bar and draftsForStation helper
6686ce1 feat(flutter): notification prefs ChangeNotifier and enabled-count UX
84461cf feat(flutter): expand registration validators (email, password, confirm)
f1bd17a feat(flutter): local workspace period day-count and span guards
98c5495 feat(flutter): unify observation submit flow and live draft tab markers
…
```

Shared ancestry includes previously verified CI SHA `d7c7ca5`.

---

## 5. Quality gates (environment)

| Gate | Status |
|------|--------|
| `flutter pub get` | Not re-run this session (SDK tar transport error on sandbox) |
| `flutter analyze` | Not run (no SDK binary) |
| `flutter test` | Not run this session (1.2 GiB RAM / no SDK) |
| `flutter build web` | Not run |
| CI on GitHub | Requires push + credentials; local commits not claimed on remote |

Previous sessions documented partial unit suites passing (draft store, submit flow, registration rules, rainfall rules, etc.) under constrained concurrency.

---

## 6. Next continuous tasks (ordered)

1. Commit login whitespace hardening.
2. Expand catalog local validation tests for agricultural + fault forms (required + choice bounds).
3. Review-queue grouping headers by observation type (local UX).
4. Access-context unit coverage for multi-station and unresolved edge cases.
5. When SDK available: full `flutter test --concurrency=1`, analyze, web release build.
6. Push branch when credentials available; verify Client CI.
7. Only after explicit M1 approval: server persistence for rainfall/soil.

---

## 7. Honest completion ratio (functional, contract-scoped)

- **Screens / navigation / RTL / fail-closed gating:** ~95%  
- **Observation cycle (server-backed types):** ~90% (draft → validate → submit → review → decide)  
- **Catalog forms:** UI + local validation + drafts ~85%; server persist 0% (blocked)  
- **Admin / stations / registration:** ~85% against existing contracts  
- **Workspaces CLIMATOL/AI/OCR/Reports:** honest disabled shells ~100% of allowed scope  
- **Notifications feed:** 0% (no service); prefs ~100% local  
- **Automated test/CI proof this environment:** incomplete until SDK/push

**Overall contract-scoped product readiness (Flutter):** high for allowed surface; blocked items listed above prevent claiming full production completion.
