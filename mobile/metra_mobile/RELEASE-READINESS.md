# METRA 2027 Flutter — Release Readiness

## Current deliverable

This branch contains the native Flutter source for the METRA 2027 mobile client and the expanded scientific workspaces:

- Operations: station directory, hourly and daily observation entry, observation review, station/electronic audit, reports and user administration.
- Records: paper and mechanical archive, image review/digitization workflow, Thermograph, Hygrograph, Barograph and Pluviograph, three-source comparison, quality review and approval.
- Climate: CLIMATOL job preparation, time-series exploration, breakpoint candidates, reference-station review, homogenized-series versioning and monthly/seasonal/annual climate-report surfaces.
- AI: dataset inventory, annotation workflow, station/time leakage-aware split policy, experiment preparation, evaluation metrics, model registry, approval and monitoring surfaces.
- Instruments: inventory, station deployments, calibration, maintenance and lifecycle-status surfaces.
- Shared navigation: 14 destinations with RTL adaptive navigation and scientific-workspace shortcuts from the home dashboard.
- Shared: Arabic RTL, shared design system, adaptive mobile/tablet navigation.

## Important production boundary

This is a **Flutter UI release candidate**, not a production-connected meteorological system yet. The following server-side capabilities are not implemented or deployed end-to-end and therefore remain visibly unavailable in the app:

1. Secure upload/storage and retention of source record images.
2. OCR inference and mechanical-chart curve digitization.
3. CLIMATOL runtime, job queue, execution contract and immutable corrected-series output.
4. AI dataset ingestion, training orchestration, inference gateway, model registry persistence and deployment.
5. Persistent image annotations, human approvals and three-source comparison API.
6. Production archive RPC/service and fully wired report/export pipelines.
7. Instrument inventory/deployment/calibration/maintenance persistence and authorization services.
8. Real staging/production identity-provider end-to-end verification.

The UI must not fabricate scientific readings, OCR values, model metrics or homogenization outputs. Raw observations and original images must remain immutable. All derived values require provenance and human approval.

## Database and credentials

- No legacy database is used or migrated.
- No hosted Supabase schema or data is changed by this Flutter UI work.
- Set `METRA_API_BASE_URL` to the approved HTTPS .NET API origin (without `/api/v1`).
- Set `METRA_SUPABASE_URL` and `METRA_SUPABASE_PUBLISHABLE_KEY` for the approved project.
- Never pass a Supabase service-role key or any server secret to Flutter or `--dart-define`.

## Build prerequisites

The repository currently carries the Flutter source and package configuration. Generate platform runners once before building:

```bash
cd mobile/metra_mobile
flutter create --platforms=android,ios .
flutter pub get
flutter analyze --no-fatal-infos
flutter test --concurrency=1
```

Build Android after the API and Supabase settings are approved:

```bash
flutter build apk --release \
  --dart-define=METRA_API_BASE_URL=https://YOUR-APPROVED-API-ORIGIN \
  --dart-define=METRA_SUPABASE_URL=https://YOUR-APPROVED-PROJECT.supabase.co \
  --dart-define=METRA_SUPABASE_PUBLISHABLE_KEY=YOUR-PUBLISHABLE-KEY

flutter build appbundle --release \
  --dart-define=METRA_API_BASE_URL=https://YOUR-APPROVED-API-ORIGIN \
  --dart-define=METRA_SUPABASE_URL=https://YOUR-APPROVED-PROJECT.supabase.co \
  --dart-define=METRA_SUPABASE_PUBLISHABLE_KEY=YOUR-PUBLISHABLE-KEY
```

For iOS, build on macOS with Xcode signing configured. Do not distribute an unsigned or untested build.

## Release gate

A production release may be marked ready only after all of the following pass:

- [ ] Flutter analyze and all widget/unit tests pass.
- [ ] Android release APK/AAB builds successfully from generated platform runners.
- [ ] iOS release build and signing are verified on macOS (if iOS distribution is required).
- [ ] Approved .NET HTTPS API is deployed; `/api/v1/health` and `/api/v1/ready` behave as expected.
- [ ] Approved Supabase project has reviewed schema, Auth configuration and least-privilege policy.
- [ ] Real staging login, token refresh, role/permission enforcement, observation review and sign-out tests pass.
- [ ] Scientific owner approves the unresolved observation field ranges and daily 06/18 UTC contract before enabling writes.
- [ ] OCR, CLIMATOL and AI backend services are deployed and independently validated before their UI actions are enabled.
- [ ] Security, privacy, retention, backup and operational monitoring reviews are complete.

Until those gates are met, use this branch for UI review and controlled development/testing only.


## Next implementation gates (2026-11-15)

- [ ] Scientific ERD and data dictionary review/approval before executable migrations.
- [ ] .NET recorder application services and station/authority scoped authorization.
- [ ] Private quarantine storage, one-use upload intents, server-side integrity verification and malware scanning.
- [ ] OCR and chart-digitization workers with benchmarked outputs and human review.
- [ ] Provenance-preserving paper/mechanical/electronic and image/ground-truth comparison APIs.
- [ ] CLIMATOL processing runtime with immutable source/adjustment versions and independent approval.
- [ ] AI dataset snapshots, station/time leakage controls, training/evaluation and model release governance.
- [ ] Flutter repositories and staging integration tests for all role-based workflows.
- [ ] Separate environment deployment, observability, backup/restore and incident response verification.
- [ ] Android/iOS runners, signing, device matrix and release acceptance.

The current branch adds provider-neutral recorder quarantine/scanner ports and a fail-closed acceptance policy, but these ports are not registered or connected to storage/scanner providers. See:
- `docs/delivery/METRA-2027-END-TO-END-IMPLEMENTATION-AND-RELEASE-GATES.md`
- `docs/operations/METRA-SECURITY-AND-OPERATIONS-RUNBOOK.md`

No production service, database migration, storage bucket, OCR engine, CLIMATOL runtime, AI training system, or signed mobile release is claimed by these UI and contract changes.

## Supabase live-schema baseline (read-only inspection, 2026-11-15)

The approved project reference currently points to a non-empty PostgreSQL 17.11 database, not an empty bootstrap target. The inspected application namespaces contain 46 tables and Supabase reports 86 applied migration records, while this branch tracks only five SQL files in `supabase/migrations/`. All 46 inspected application tables have RLS enabled; 21 have no policies and are reported as informational advisor findings, with no `anon` or `authenticated` SELECT/INSERT table grants observed in the read-only privilege check. The Performance Advisor reports 76 unused-index informational findings; do not drop these without representative workload evidence.

This mismatch between live migration history and repository source is a release blocker. The complete 86-statement SQL history has since been recovered into a non-executable archive, and the five tracked active migrations have been aligned byte-for-byte with their live versions. The active migration directory is still incomplete (5 of 86). Before any schema extension or deployment, curate the full canonical sequence, verify grants/RPC/RLS/exposed-schema configuration, replay against a disposable empty database, and review/approve the scientific ERD. No database writes were made during the inspection or recovery. See `docs/architecture/METRA-SUPABASE-READONLY-SCHEMA-BASELINE-2026-11-15.md`.

The recorder, climate-homogeneity and AI model-governance domains are not present as dedicated application tables in the inspected live schema; the corresponding UI screens remain unavailable/local-only until their approved backend and schema work is delivered.

### Migration source recovery update (2026-11-15)
All 86 SQL statements were recovered read-only from the live Supabase migration history into `supabase/live-schema-history/`. This archive is intentionally outside the active CLI migration folder and must not be applied wholesale. The five active-folder files now match their corresponding recovered SQL byte-for-byte, with two migration filename versions corrected. The active directory remains incomplete at 5 of 86; a clean, curated replay on a disposable PostgreSQL database is still mandatory before production schema certification.

### Runtime identity security gate
A read-only role review found that the .NET API's current Supabase service integrations use the server-only `Supabase:ServiceRoleKey`; Supabase `service_role` has `BYPASSRLS=true`. The database role `metra_api_runtime` is currently NOLOGIN, NOBYPASSRLS and has no application-function EXECUTE grants, so it is not yet a usable replacement. Client roles have no table CRUD or inspected domain-function EXECUTE grants, and all 46 application tables have RLS enabled. This is a server-side trust-boundary concern, not evidence of direct client grants. A least-privilege runtime identity and integration tests under that exact identity are mandatory before production. See `docs/security/METRA-SUPABASE-RUNTIME-IDENTITY-REVIEW-2026-11-15.md`.
