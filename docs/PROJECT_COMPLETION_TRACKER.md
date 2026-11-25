# METRA 2027 — Project Completion Tracker

**Last updated:** 2026-11-25  
**Branch:** `fix/flutter-quality-gates-2026-11-23`  
**HEAD (local):** `60217e7ff5ddd3333309644f362f4aa0f561563d`  
**Scope:** Flutter app `mobile/metra_mobile/` only  
**Constraints:** No DB/SQL/migrations/RLS/RPC/M1–M4 without explicit approval. No invented API endpoints.

---

## 1. Unit inventory (Flutter)

### Core
| Module | Status | Notes |
|--------|--------|-------|
| API client | Connected | Timeouts, access-context, stations, review, validate/submit, registration, admin lists |
| Access context | Fail-closed | Destination + station permission codes |
| Auth / secure session | Connected | Supabase + FlutterSecureStorage |
| Registration field rules | Local complete | UUID, phone, name, email, password, confirm |
| Observation draft store | Local complete | ChangeNotifier, station-scoped, secret filter, draftsForStation |
| Observation submit flow | Connected | Validate+submit + idempotency key reuse |
| Rainfall/soil local rules | Local complete | Negative rain, calendar + future date |
| Notification preferences | Local session | ChangeNotifier; no push service |
| Error presenter | Complete | Queue/submit/review/registration mapping |
| Theme / nav / async / permission denied | Complete | RTL-ready |

### Features / screens
| Screen | Status | Server contract |
|--------|--------|-----------------|
| Home | Complete | Access gated + live draft summary for active station |
| Login / auth | Complete | Supabase; whitespace-only password rejected |
| Account hub | Complete | Password rules centralized |
| Registration request + status | Complete | Structured status (no raw dump); pure status labels |
| Station directory | Complete | Query id/type + local sort by Arabic name |
| Station administration | Complete | Users/requests/audit/queue; pure search helpers |
| Observation workspace | Complete | Draft tab markers + station draft overview bar |
| Hourly / Daily / Phenomenon | Connected | Shared submit flow + generation/station guards |
| Catalog forms (7) | Local-only | Validation + drafts; honest pending-contract messaging |
| Observation review | Connected | Type filter, newest sort, type grouping headers, Semantics |
| Notifications center | Local shell | Prefs only |
| Settings | Complete | Account, sign-out confirm, config flags |
| Forecast centre | Honest offline | Station distance comparison only |
| CLIMATOL / AI / OCR / Ops / Reports | Honest offline | Period day-count + disabled actions |

---

## 2. Server-connected vs local-only

**Connected:** access context, station directory, observation validate/submit (hourly/daily/phenomenon), review queue + decide, registration roles/status/submit, station users/requests/decide, audit log.

**Local-only until contracts/M1–M4:** rainfall, soil, agricultural, hourly climate, fault forms; notification delivery; CLIMATOL/AI/OCR/archive/report export; cross-restart draft persistence (session memory only).

---

## 3. External blockers

| Item | Blocked |
|------|---------|
| M1–M4 | DB/RPC/.NET expansion for catalog persistence |
| Notification service | Real feed/push |
| CLIMATOL / AI / OCR / archive / report APIs | Execution paths |
| Flutter SDK in this sandbox | analyze / test / web / CI proof |

---

## 4. Recent commits (this continuous line)

```
4dcaa02 chore(flutter): declare flutter_localizations for MaterialApp delegates
fde9087 feat(flutter): admin audit search helper and Semantics on registration decisions
28ed537 test(flutter): draft store notifies listeners; refresh completion tracker
f0202dc feat(flutter): Semantics labels on review approve and return actions
934c8fd feat(flutter): pure registrationStatusLabel for operator-facing status codes
b5ac0fe test(flutter): cover observation submit idempotency key reuse on retry
e43ab46 feat(flutter): local station directory sort and pure filter helper
3fa2ea6 fix(flutter): define home station draft summary widget class
090f932 feat(flutter): live station draft summary on home overview
d9301c9 fix(flutter): structured registration status without raw response dump
9f1bee8 feat(flutter): group review queue by observation type with pure list builder
…
```

---

## 5. Quality gates

| Gate | Status |
|------|--------|
| flutter analyze / test / web | Not runnable (no SDK binary; ~1.2 GiB RAM; tar transport error) |
| CI on GitHub | Requires push credentials |

---

## 6. Next continuous tasks

1. Expand Semantics on admin decision and primary nav destinations.
2. Additional pure helpers for audit-log local search when useful.
3. When SDK available: `flutter test --concurrency=1`, analyze, web release.
4. Push branch; verify Client CI.
5. After explicit M1: catalog server persistence only.

---

## 7. Honest completion ratio (contract-scoped)

- Screens / RTL / fail-closed: ~96%
- Observation cycle (server-backed): ~92%
- Catalog forms: UI+local validation ~90%; server persist 0%
- Admin / stations / registration: ~90%
- Workspaces offline honesty: ~100% of allowed scope
- Notifications feed: 0% (blocked); prefs complete
- Automated test/CI proof this environment: incomplete

**Overall Flutter readiness within contracts:** high. Production “complete” claim remains blocked by M1–M4, notification service, and offline workspace engines.
