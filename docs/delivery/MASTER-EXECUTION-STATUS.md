# METRA 2027 — Master Execution Status

**Timestamp (UTC):** 2026-11-13 ~02:20  
**Local branch:** `work/backend-db-integration-phase`  
**Local HEAD at start of this pass:** `e03da4af14bad1845e248aea43afa90fa0bcef85`

## Sources of truth

| Asset | Location | Notes |
|-------|----------|-------|
| Backend C2–C9 + DB proposals | **Local** this branch | Not fully on remote tip |
| Flutter C7 CI green | Remote `c6d9a9f…` + Actions 43337342656 | 16 tests |
| PR #34 Flutter archive UI | `fix/flutter-client-ci-mainline-2026-11-11` | Draft |
| PR #35 Archive API | `work/backend-api-audit-rebased-2026-11-11` | Draft; **not merge-ready** (station scope gap documented in PR body) |

## Security gates (non-negotiable)

1. **ArchiveRead is per-station only** — R4 proposal + isolated SQL; production RPC must bind `permission_grants.station_id = p_station_id` for `observation.archive.read`.
2. **PR #35 must not merge** until same-authority A/B denial is proven in DB tests and RPC matches R4.
3. **Archive API remains 503** via `UnconfiguredObservationArchiveService`.
4. **No hosted Supabase DDL/RLS/RPC/apply** without explicit owner approval.
5. **No push/merge/deploy** without owner approval.

## Authorization path (current local API)

1. JWT `sub` required.
2. `IStationAuthorizationService.HasStationPermissionAsync` → RPC `metra_user_has_station_permission` (service_role server-side only).
3. Fail-closed on any RPC/config failure.
4. Domain policy double-check for archive.
5. Archive service unconfigured → **503**.

## TOCTOU residual (documented)

Review queue / archive data reads that authorize then SELECT under elevated DB role remain a design risk until atomic DB functions lock rows and re-check grants in one transaction. Proposal track: keep archive closed; for review decisions use station-scoped RPC with row lock (existing decision path direction). Full atomic archive reader is blocked on hosted approval.

## Flutter

- App: `mobile/metra_mobile/` only.
- Forecast coordinate-source test uses `scrollUntilVisible` for lazy ListView (`e03da4a`).
- Mock: AI, Climatol, Forecast live readings, Electronic Audit UI.
- Archive UI present; respects 503.

## Next executable work (when tools/env allow)

1. Re-run `dotnet test` → expect 264.
2. Isolated Path N + archive isolation SQL.
3. Owner-approved non-force Git sync of local Backend to remote.
4. Owner-approved R4 RPC apply + grant uniqueness indexes on isolated then staged hosted.
5. Do not merge PR #35 until A/B same-authority tests green.

## Readiness

**CONDITIONALLY READY** for technical RC review of local Backend + Flutter CI.  
**NOT PRODUCTION READY.**
