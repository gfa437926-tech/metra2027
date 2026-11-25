# METRA 2027 — Project Completion Tracker

**Last updated:** 2026-11-25  
**Branch:** `fix/flutter-quality-gates-2026-11-23`  
**HEAD (local):** `50151dd1953a76ce01c1a8bab6d099dfdb27bd25`  
**Scope:** Flutter app `mobile/metra_mobile/` only  
**Constraints:** No DB/SQL/migrations/RLS/RPC/M1–M4 without explicit approval. No invented API endpoints. No force push.

---

## Closure status (contract-scoped)

### Complete within current contracts and fail-closed rules

| Area | State |
|------|--------|
| Auth / login / secure session | Complete |
| Registration request + structured status | Complete |
| Account hub / password rules | Complete |
| Access context fail-closed navigation | Complete |
| Station directory (search, sort, map, mine filter) | Complete |
| Station administration (users, requests, audit, queue) | Complete |
| Hourly / daily / phenomenon cycle (draft → validate → submit → review → decide) | Complete |
| Catalog forms (7): local validation + drafts + honest offline messaging | Complete (no server persist) |
| Observation workspace (tabs, draft markers, overview bar) | Complete |
| Review queue (filter, sort, type grouping, Semantics) | Complete |
| Notifications center (local prefs only) | Complete shell |
| Settings / configuration gate | Complete |
| Forecast centre geographic comparison | Complete (no fake telemetry) |
| CLIMATOL / AI / OCR / Ops / Reports | Honest offline shells with period guards |
| Error presenter / timeouts / idempotency | Complete |
| Unit tests for pure helpers (validation, drafts, review, admin, access, API config) | Expanded (run blocked here) |

### External blockers preventing full production claim

1. **Flutter SDK unavailable in this sandbox** — cannot execute `flutter analyze`, `flutter test`, or `flutter build web` here (tar transport error, ~1.2 GiB RAM).
2. **No GitHub push credentials** — `git push` fails; local commits not on remote; Client CI not triggered from this environment.
3. **M1–M4 not approved** — catalog forms cannot gain server persistence.
4. **No notification service contract** — feed remains empty by design.
5. **No CLIMATOL / AI / OCR / archive / report-export contracts** — actions stay disabled with honest tooltips.
6. **Angular deferred** by mission order.

### Honest ratios

- Flutter surface allowed by contracts: **~95–98%**
- Full METRA 2027 product including DB catalog persist + offline engines + push + CI proof: **not claimable** until blockers above clear

### Next actions outside this agent environment

1. Push `fix/flutter-quality-gates-2026-11-23` with credentials → verify Client CI (analyze + test).
2. On a machine with Flutter stable: `flutter pub get && flutter analyze && flutter test --concurrency=1 && flutter build web --release`.
3. Explicit approval only for M1–M4 if catalog server persistence is required.
4. Contract work for notifications and workspace engines when product prioritizes them.

### Recent commits (continuous line, preserved history)

```
50151dd feat(flutter): local search on station registration and audit admin tabs
35eea55 fix(flutter): complete localization delegates and Material on config screen
03ed439 test(flutter): unresolved access keeps placeholder destinations visible only
60217e7 refactor(flutter): delegate review formatters to pure helpers
1e67ca8 feat(flutter): pure review status and observedAt formatters with tests
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

Shared ancestry includes previously verified CI SHA `d7c7ca5`. Remote push not performed.
