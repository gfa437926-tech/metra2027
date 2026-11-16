# METRA transfer — restore acceptance checklist

**Status:** pre-restore governance checklist; not an authorization to connect to, export from, or modify any hosted database.

## Non-negotiable safety boundary

- [ ] The only permitted experimental source is project ref `tbdnklyxjvbrilvnwgmq`.
- [ ] The owner has identified the new target project ref in writing. A target must never equal the source or any legacy project.
- [ ] No legacy METRA database is queried, exported, modified, or used as a fallback.
- [ ] No hosted operation begins until the owner approves the exact source, exact target, scope, window, operators, and evidence-retention location.
- [ ] No credentials, database URLs, passphrases, JWTs, API keys, or user data are committed to Git or pasted into chat.
- [ ] The transfer is limited to the approved `public` and `private` application schemas. Supabase-managed schemas, Auth users/sessions, Storage objects, provider settings, secrets, and JWT signing material are excluded.
- [ ] All rows from `public.metra_observation_records` are excluded, including demo and non-demo history. The target acceptance query must return exactly zero.
- [ ] Do not infer station approval or invent station coordinates. The station catalogue and coordinate provenance require explicit owner review.

## Gate 0 — repository and CI evidence

- [ ] Record the exact branch, commit SHA, PR number, and workflow run IDs.
- [ ] Verify CI against the exact proposed commit, not merely its parent.
- [ ] Require successful Backend build, Flutter Client CI, Flutter C7 CI, and transfer safety workflow where applicable.
- [ ] Inspect job steps and logs for the transfer workflow; a workflow name or green badge alone is insufficient.
- [ ] Confirm ShellCheck, Python unit tests, shell guards, disposable PostgreSQL fixtures, extension checks, ACL checks, Auth-FK checks, and importer tests completed successfully.
- [ ] Record any skipped, cancelled, or unavailable check as an unresolved gate; do not silently treat it as passing.

**Exit evidence:** commit SHA, workflow/run IDs, job conclusions, and retained test logs.

## Gate 1 — source inventory and provenance review

- [ ] Verify the source project identity from a trusted connection endpoint without exposing its URL in evidence.
- [ ] Review the exported table/function inventory and schema scope.
- [ ] Verify `auth.users` is empty and the manifest states `auth_users_exported=false` and `auth_user_count=0`.
- [ ] Review the Auth foreign-key inventory separately; compare row/null/distinct cardinalities without requiring source UUID values to match regenerated target IDs.
- [ ] Verify the observation provenance report is present and that no observation-history payload is included.
- [ ] Review station catalogue provenance, approval state, coordinate coverage, orphan coordinates, and duplicate links. Unapproved or unresolved station records remain unresolved; do not promote them automatically.
- [ ] Review extension name, version, and schema inventory.
- [ ] Review source object grants and default ACL inventory; do not copy broad source defaults into the target.

**Exit evidence:** signed source inventory review, Auth-FK report, observation-exclusion report, station provenance review, and extension/ACL inventories.

## Gate 2 — artifact integrity and target readiness

- [ ] Confirm the encrypted schema and data artifacts exist and the manifest covers the exact expected artifact set.
- [ ] Verify SHA-256 checksums and reject missing, duplicate, unexpected, or path-traversal entries.
- [ ] Verify GPG integrity without recording or disclosing the passphrase.
- [ ] Verify the target project identity independently and confirm it is the explicitly approved new project.
- [ ] Confirm the target application schemas are empty. Run the empty-target guard only against an explicitly approved disposable or target environment.
- [ ] Confirm required extensions are available at the recorded versions/schemas before any import decision.
- [ ] Confirm restrictive target default ACLs and runtime role design have been reviewed.
- [ ] Confirm the target has a recoverable backup/snapshot plan and a documented stop/rollback owner.

**Exit evidence:** checksum verification output, target identity confirmation, empty-target evidence, extension readiness, ACL review, and recovery plan.

## Gate 3 — isolated restore rehearsal

- [ ] Perform the first restore rehearsal only in disposable PostgreSQL, never in a hosted legacy database.
- [ ] Apply schema and data using the reviewed transfer scripts and the exact verified artifact manifest.
- [ ] Verify the import rejects a non-empty target and rejects any dump containing excluded observation-history rows.
- [ ] Verify Auth users remain absent and Auth-FK cardinalities are preserved under the approved remapping policy.
- [ ] Verify object inventory, row counts, data fingerprints, sequence state, ACL acceptance, extension inventory, and station provenance.
- [ ] Verify target-only default ACL and function search-path assertions.
- [ ] Preserve logs and checksums without including secrets or raw observation history.

**Exit evidence:** isolated restore log, comparison outputs, target-only security assertions, and a list of all deviations.

## Gate 4 — application acceptance

- [ ] Run backend and Flutter integration/smoke tests against the isolated restored target.
- [ ] Verify least-privilege access for every runtime role and confirm default-deny behavior for unsupported roles.
- [ ] Verify RLS and API exposure boundaries for every exposed application table.
- [ ] Verify audit immutability and function search-path protections.
- [ ] Verify station catalogue behavior without approving pending stations or manufacturing missing coordinates.
- [ ] Obtain application owner and security reviewer sign-off.

**Exit evidence:** test report, role/access matrix, RLS review, audit checks, and signed owner acceptance.

## Gate 5 — live operation authorization (currently blocked)

This gate is intentionally not satisfied by repository commits or disposable CI.

- [ ] Owner explicitly authorizes the exact live source and target refs, scope, operator, time window, and retention policy.
- [ ] Security reviewer approves the credential-handling and recovery plan.
- [ ] Data owner explicitly approves exclusions and any station catalogue decisions.
- [ ] A tested recovery/rollback plan and post-restore verification window are approved.
- [ ] The owner gives a separate explicit go-ahead for each hosted export/import/cutover action.

Until every item is approved, do not connect to hosted Supabase, export data, apply migrations, import data, change grants, or cut over an application.

## Gate 6 — post-operation reconciliation (only after Gate 5 approval)

- [ ] Verify the target project identity again before each operation.
- [ ] Verify the excluded observation table contains zero rows.
- [ ] Verify Auth-user count remains zero and Auth-FK cardinalities match the approved report.
- [ ] Re-run row-count, data-hash, sequence, object, ACL, extension, and station-provenance comparisons.
- [ ] Re-run security and application smoke tests.
- [ ] Record deviations, incidents, operator, timestamps, and evidence references.
- [ ] Obtain final owner sign-off before any production routing change.

## Current disposition

**NO-GO for hosted restore or cutover.** Repository tests and disposable PostgreSQL checks are validation evidence only. They do not constitute a live restore, application acceptance, owner approval, or production readiness decision.
