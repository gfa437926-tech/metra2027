# METRA 2027 — DevOps / CI-CD Audit

**Audit date:** 2026-11-11 (UTC)  
**Audited base:** `main` at `87f71356083843b2abdef76baf011a82510686be`  
**Working branch:** `assistant-9/devops-ci-hardening`  
**Scope:** GitHub Actions, Angular, ASP.NET Core, Flutter, R/Climatol workflow coordination, Docker/container publishing, runtime configuration, build repeatability, diagnostics and rollback.

## Executive result

The default branch currently contains four workflows. Angular, Flutter and ASP.NET Core have successful historical main-branch CI runs. The latest observed GitHub Pages run failed during runtime-configuration validation after the Angular production build succeeded. A separate R/Climatol workflow is being developed on another assistant's pull request branch; it is not yet part of the audited `main` workflow inventory. No production deployment or container publication was initiated by this audit.

## Workflow inventory on `main`

| Workflow | Responsibility | Triggers | Latest observed main run | Result |
|---|---|---|---|---|
| `backend-ci.yml` | .NET restore/audit, SQL contract checks, API build/tests, Docker build | push/PR path filters, manual | #774, 2026-11-04 | Success |
| `client-ci.yml` | Angular build; Flutter analyze/tests | push/PR path filters, manual | #137, 2026-11-05 | Success |
| `deploy-pages.yml` | Angular Pages build and deployment | main push path filter, manual | #158, 2026-11-05 | Failure in build job |
| `publish-api-container.yml` | Build and push API image to GHCR | main push path filter, manual | #44, 2026-11-04 | Success |

The repository had 3,664 workflow runs in the queried Actions history. The main-branch-filtered history reported 551 runs. These are historical totals, not counts of active workflows.

### Latest run evidence inspected

- Client CI #137: Angular build succeeded; Flutter analyze and tests succeeded.
- Backend build #774: NuGet restore/audit, SQL contract checks, API build, API tests and Docker image build all succeeded.
- Publish API container #44: image publication to GHCR succeeded. This workflow is a release-artifact publisher, not a host deployment. It has `packages: write` permission and must remain clearly separated from test-only CI.
- Deploy Pages #158: Angular production build succeeded; the step **Validate and inject public runtime configuration** failed. The SPA fallback, Pages configuration, artifact upload and deploy jobs were skipped. The workflow job summary proves the failing step, but this audit did not retrieve the step log or inspect repository secret values; the precise missing/invalid input is therefore not asserted.
- A recent Client CI run on assistant 3's PR #21 also passed both Angular and Flutter jobs.
- The R/Climatol workflow is visible on assistant 4's PR #23 branch. Run #18 succeeded; run #19 was in progress at the time of inspection. It is not present in the `main` workflow directory, so it is tracked as parallel work rather than duplicated here.

## Safe changes in this PR

### Client CI repeatability

The Angular job previously used `npm install` and cached against `package.json` even though a committed lockfile exists. It now uses `npm ci` and caches against `package-lock.json`, so CI installs the dependency graph recorded in the lockfile. The workflow also uses the same major versions of checkout/setup-node actions as the backend workflow.

The Flutter job now uses `flutter pub get --enforce-lockfile` so CI cannot silently rewrite the committed dependency lock. It continues to run static analysis and the test suite.

The workflow remains limited to client paths and has no deploy or publish step.

## Build and infrastructure assessment

### Angular

- Node.js major is explicitly set to 22.
- `package-lock.json` is committed and is now authoritative for CI installs.
- The production Pages build uses a separate workflow; its configuration gate is currently failing on the latest observed main run.
- Follow-up: pin the Node 22 patch/runtime through a repository toolchain policy if exact local/CI parity is required.

### ASP.NET Core

- Target framework is `net10.0`; backend CI installs .NET `10.0.x`.
- CI runs NuGet vulnerability audit with high/critical warnings treated as errors, SQL contract scripts, Release build, tests and Docker build.
- Dockerfile uses .NET 10 SDK/runtime stages and runs as the non-root application user.
- Follow-up: introduce a reviewed `global.json` SDK policy and test it against the hosting/build images before enforcing an exact SDK feature band.

### Flutter

- The app commits `pubspec.lock`; CI now enforces it.
- CI performs `flutter analyze` and `flutter test`.
- The action currently follows the moving `stable` channel. Exact Flutter SDK reproducibility is not guaranteed until the team agrees and records a specific Flutter version (for example in a checked-in version file and the workflow).

### R / Climatol

- No R workflow exists on audited `main`.
- The separate R workflow is in active development on PR #23. Its latest observed check was still running, with a preceding run successful.
- Do not add a competing R workflow here. Once PR #23 is reviewed and merged, update this inventory with its package/toolchain versions, Climatol execution contract, fixture provenance, artifact retention and scientific approval gates.
- CI must not run operational homogenization or overwrite authoritative station series. Use versioned test fixtures and retain diagnostics as build artifacts.

### Docker and hosting

- `backend/Metra.Api/Dockerfile` builds from repository root; `.dockerignore` excludes Git metadata, client build directories, dependency caches and build output.
- `render.yaml` describes a Render Blueprint and auto-deploys on commits to its configured branch after the Blueprint is created. It does not prove that a Render service exists or is deployed.
- `publish-api-container.yml` pushes commit-tagged and `latest` images to GHCR on main. This audit did not run it and did not deploy any image.
- There is no root Docker Compose file in the inspected root listing. Do not invent a local multi-service runtime contract until required services and dependencies are specified.

## Runtime configuration and secret handling

- Pages workflow expects `METRA_API_BASE_URL` and `METRA_SUPABASE_ANON_KEY`; `METRA_SUPABASE_URL` has a documented public project URL fallback.
- The Supabase anon/publishable key and API base URL are client-visible configuration, not server credentials. Their values must not be confused with a service-role key.
- The backend deployment guide identifies `Supabase__ServiceRoleKey` as server-only. It must be held in the hosting provider's secret manager and never supplied to Angular, Flutter, Pages artifacts, Docker build arguments, or committed files.
- This audit did not read or print secret values. Repository secrets are not inspected through the available public repository/file reads.
- The Pages runtime-config step intentionally validates HTTPS, the `/api/v1` suffix, and a clean Supabase origin. Restore the deployment only after the required values are configured and the workflow is deliberately run by an authorized maintainer.

## Workflow overlap and trigger risks

1. `client-ci.yml` and `deploy-pages.yml` both react to Angular changes on main. This is intentional separation of verification and deployment, but creates two independent runs; CI success does not gate Pages deployment.
2. `backend-ci.yml` builds the Docker image for validation; `publish-api-container.yml` separately builds and pushes the image. The duplicate build is deliberate for trust separation, but increases runtime/cost. Consider reusable workflows only after preserving the difference in permissions and push behavior.
3. Client CI currently includes changes to `deploy-pages.yml` in its path filters; this means deployment workflow edits also run client tests, which is safe but broader than necessary.
4. Backend CI and container publication are independent on main. Publishing is not gated by a required backend-CI workflow dependency. Add a branch protection / required-check policy or reusable workflow gate before treating GHCR publication as an approved release.
5. The R workflow on PR #23 is not yet part of main. Avoid duplicate definitions and reconcile its final trigger/path filters with the main CI inventory after that PR is reviewed.
6. Multiple quick commits have caused cancelled superseded Client CI runs in the historical Actions list. Client concurrency already cancels superseded runs; cancelled runs should not be counted as failures.

## Deployment and rollback strategy (proposal; not executed)

### Release promotion

1. Require successful backend, client and relevant data-science checks on the exact commit SHA.
2. Build once and publish an immutable container tag using the full commit SHA; retain SBOM and provenance metadata.
3. Promote the same immutable image digest between development, staging and production. Do not rebuild separately for each environment.
4. Keep environment configuration outside the image and use separate host secret stores and least-privilege credentials.
5. Require an explicit human approval at the production environment boundary. The current GHCR publishing workflow is not itself a production deployment approval gate.
6. Apply database migrations only through a separately reviewed and backed-up process; never couple an unreviewed migration to an application rollback.

### Rollback

- **API container:** redeploy the last known-good immutable SHA/digest in the hosting provider's deployment history. Do not roll back to mutable `latest`.
- **Angular Pages:** revert the faulty commit through a reviewed PR or redeploy the last known-good Pages artifact/commit. Confirm runtime configuration separately; reverting frontend code does not repair missing secrets.
- **Flutter:** distribute the last approved signed release through the relevant store/channel; retain release artifacts and signing-key custody outside the repository.
- **Database:** use a separately rehearsed restore/forward-fix plan. Application rollback does not reverse schema/data changes. No database operation is part of this PR.

## Known repository documentation mismatch

The requested files `واجهات/مهما.md`, `واجهات/تغيير.md` and `واجهات/README.md` were not present in the root listing of the audited `main` branch. The existing documentation locations are under `docs/`. This PR therefore adds this audit under `docs/deployment/` and does not create a parallel `واجهات/` directory or claim to update files that are absent. The project owner should provide/restore the intended interface handoff directory or confirm the canonical replacement path.

## Validation status for this PR

- GitHub Actions PR run #725 completed successfully on 2026-11-10: Angular `npm ci` and production build passed; Flutter locked dependency resolution, `flutter analyze`, and `flutter test` passed. Evidence: https://github.com/gfa437926-tech/metra2027/actions/runs/42922825265
- Assistant-specific progress and append-only change log were added at `docs/progress/assistant-09.md` and `docs/progress/assistant-09-changelog.md`.
- Existing historical main checks were inspected as listed above; they are not substituted for fresh PR checks.
- No production deployment, Pages deployment, GHCR publication, database change, secret mutation or merge to `main` was performed.
- PR #27 remains open as Draft pending review and the follow-up items in the assistant progress report.

## Assistant 09 reporting protocol — 2026-11-10T23:29:00Z

- Task ID: `DEVOPS-09-001`; status: in progress.
- Progress: 67% (8/12 explicitly tracked work items; 4 remaining).
- Branch: `assistant-9/devops-ci-hardening`.
- PR: https://github.com/gfa437926-tech/metra2027/pull/27 (open, Draft, not merged).
- Progress report: https://github.com/gfa437926-tech/metra2027/blob/assistant-9/devops-ci-hardening/docs/progress/assistant-09.md
- Append-only change log: https://github.com/gfa437926-tech/metra2027/blob/assistant-9/devops-ci-hardening/docs/progress/assistant-09-changelog.md
- PR validation: Client CI #725 passed Angular and Flutter jobs; https://github.com/gfa437926-tech/metra2027/actions/runs/42922825265
- Follow-up: investigate Pages runtime configuration validation; confirm canonical `واجهات/` handoff files; reconcile R/Climatol after PR #23; pin Flutter SDK.


## Follow-up diagnostic addendum — 2026-11-10T23:31:43Z

- Pages main run #158: https://github.com/gfa437926-tech/metra2027/actions/runs/41951012675
- The Angular production build passed; `Validate and inject public runtime configuration` failed. Artifact upload and deploy were skipped.
- The checked-in workflow requires `METRA_API_BASE_URL` and `METRA_SUPABASE_ANON_KEY`; `METRA_SUPABASE_URL` has a public project URL fallback. The API URL must be HTTPS and end in `/api/v1`; the Supabase URL must be a clean HTTPS origin.
- The job-level evidence confirms the failed step but does not establish which setting was missing or malformed. Secret values were not accessed. Exact cause remains unverified; repository maintainers must check secret/environment availability and formatting without disclosing values.
- R package check #19 on the separate climate branch succeeded: https://github.com/gfa437926-tech/metra2027/actions/runs/42922431783. PR #23 remains Draft/open/unmerged: https://github.com/gfa437926-tech/metra2027/pull/23. Passing package check is not equivalent to operational Climatol validation or PR approval.
- No Pages deployment/re-run, secret/environment change, Climatol production run, database operation, or merge was performed.
- Assistant 09 progress remains 67% (8/12); four work items remain open. See https://github.com/gfa437926-tech/metra2027/blob/assistant-9/devops-ci-hardening/docs/progress/assistant-09.md and the append-only log at https://github.com/gfa437926-tech/metra2027/blob/assistant-9/devops-ci-hardening/docs/progress/assistant-09-changelog.md.


## Flutter SDK pin and R workflow review — 2026-11-10T23:34:30Z

### Flutter

The successful Client CI #725 job log records the resolved SDK path as `flutter/stable-3.47.9-x64`. Assistant 09 used this observed, passing toolchain version to pin `flutter-version: '3.47.9'` in `.github/workflows/client-ci.yml`. This avoids an unreviewed SDK version choice and converts the previous moving `stable` target into a reproducible explicit version.

- Change commit: https://github.com/gfa437926-tech/metra2027/commit/feacff5ac43479baba8141a4a2b9e27cd50c9ac7
- Post-pin CI: https://github.com/gfa437926-tech/metra2027/actions/runs/42924440412 (pending at time of this note; success is not yet claimed).

### R / Climatol branch review

- R package check #19 passed: https://github.com/gfa437926-tech/metra2027/actions/runs/42922431783.
- PR #23 remains Draft/open/unmerged: https://github.com/gfa437926-tech/metra2027/pull/23.
- The workflow `.github/workflows/climate-analytics-r.yml` on `work/climate-analytics-r-hardening` limits its push trigger to `work/climate-analytics-r-bootstrap`. After merge to `main`, direct pushes to `main` will not trigger this workflow. The PR trigger can validate PR changes, but the post-merge push coverage should be corrected by the owning assistant before integration.
- R is configured as `4.5` (minor line) and Climatol as `4.5-0` in the R CI dependency setup; this does not pin an exact R patch release.
- Assistant 09 did not modify PR #23 or the R workflow owned by Assistant 04.

No production deployment, secret/environment change, database operation, Climatol production processing, or merge was performed.
