# METRA 2027 — Project Completion Tracker

**Last updated:** 2026-11-25  
**Branch:** `fix/flutter-quality-gates-2026-11-23`  
**HEAD (local):** `d73190d661455ebf3cd5130a5b62fa9210dc00ca`  
**Origin (fetched):** `600076f79d3c4256267af2539a83a8bfdab13605` — local **ahead by 63 commits**, not pushed  
**Constraints:** No DB/SQL/migrations/RLS/RPC/M1–M4 execution without explicit approval. No invented endpoints. No force push. Angular deferred.

---

## Phase status

| Phase | Status |
|-------|--------|
| 1 Source integrity | Local history intact; origin lag documented |
| 2 Flutter within contracts | ~98% of allowed surface |
| 3 Observation cycle (server-backed types) | Complete client-side against existing contracts |
| 4 Backend API mapping | Coverage matrix written; assignment routes wired |
| 5 M1–M4 | **Decision packages ready — awaiting owner approval** (not executed) |
| 6 Specialized services | Honest offline / no contract |
| 7 Analyze/test/build | **Blocked:** no Flutter/dotnet SDK in sandbox |
| 8 GitHub push / CI | **Blocked:** no push credentials |
| 9 Production closure | **Partial closure only** |

---

## Completed this session (from 1c67654)

- Station assignment client: `getStationAssignableRoles`, `requestStationAssignment`, `decideStationAssignment`
- Admin users tab: assignment request form (roles load + submit)
- `docs/delivery/API-CLIENT-COVERAGE-MATRIX.md`
- `docs/delivery/M1-M4-DECISION-PACKAGES.md`

---

## User approvals required (blocking full product)

1. **M1** — DB observation_type allow-list for rainfall/soil  
2. **M2** — audit event taxonomy (recommended: defer)  
3. **M3** — .NET validators for expanded types  
4. **M4** — Flutter server persist for approved catalog types  
5. Push credentials or local push of `fix/flutter-quality-gates-2026-11-23`  
6. Optional: contracts for notifications feed, CLIMATOL, AI, OCR, report export, archive store  

---

## Quality gates (this environment)

| Gate | Result |
|------|--------|
| `git fetch origin` | Succeeded; origin at 600076f |
| `git push` | Fails: no username device |
| `flutter analyze/test/web` | Not run — `flutter.tar.xz` transport error |
| `dotnet test` | No `dotnet` binary |

---

## Next session start

1. Read this tracker + `git rev-parse HEAD`  
2. If credentials available: push branch, watch Client CI  
3. If M1–M4 approved: implement **only** approved package  
4. Else: wire remaining existing contracts (assignment decide UI queue, revoke) without DB  
5. Never claim production-complete while phases 7–8 blocked  

---

## Recent commits

```
d73190d feat(flutter): station assignment API client (roles, request, decide)
1c67654 docs: tracker HEAD 50151dd after admin local search
50151dd feat(flutter): local search on station registration and audit admin tabs
…
```
