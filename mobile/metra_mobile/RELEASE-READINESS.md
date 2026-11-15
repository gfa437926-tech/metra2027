# METRA 2027 Flutter — Release Readiness

## Current deliverable

This branch contains the native Flutter source for the METRA 2027 mobile client and the expanded scientific workspaces:

- Operations: station directory, hourly and daily observation entry, observation review, station/electronic audit, reports and user administration.
- Records: paper and mechanical archive, image review/digitization workflow, Thermograph, Hygrograph, Barograph and Pluviograph, three-source comparison, quality review and approval.
- Climate: CLIMATOL job preparation, time-series exploration, breakpoint candidates, reference-station review, homogenized-series versioning and monthly/seasonal/annual climate-report surfaces.
- AI: dataset inventory, annotation workflow, station/time leakage-aware split policy, experiment preparation, evaluation metrics, model registry, approval and monitoring surfaces.
- Shared: Arabic RTL, shared design system, adaptive mobile/tablet navigation.

## Important production boundary

This is a **Flutter UI release candidate**, not a production-connected meteorological system yet. The following server-side capabilities are not implemented or deployed end-to-end and therefore remain visibly unavailable in the app:

1. Secure upload/storage and retention of source record images.
2. OCR inference and mechanical-chart curve digitization.
3. CLIMATOL runtime, job queue, execution contract and immutable corrected-series output.
4. AI dataset ingestion, training orchestration, inference gateway, model registry persistence and deployment.
5. Persistent image annotations, human approvals and three-source comparison API.
6. Production archive RPC/service and fully wired report/export pipelines.
7. Real staging/production identity-provider end-to-end verification.

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
