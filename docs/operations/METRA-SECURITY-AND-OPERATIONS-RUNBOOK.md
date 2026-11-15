# METRA 2027 — Security and operations runbook baseline

## Environment separation
Maintain isolated development, test, staging and production projects/accounts. Never reuse production secrets in CI or local development. Never point tests at a production or legacy database.

## Secret handling
- Keep Supabase service-role key, database credentials, storage signing keys, scanner credentials and AI-provider keys only in server-side secret management.
- Flutter receives only public client configuration and user access tokens.
- Do not print tokens, upload URLs, object keys or raw scientific payloads in logs.
- Rotate keys after suspected exposure; revoke old keys and verify readiness after rotation.

## Station visibility and authorization

- Ordinary users are scoped to their active, approved station assignment(s); changing a station ID in a request must never expand visibility.
- Only an explicitly active global assignment for `auditor` or `network_department_head`, with the matching `*.read_all` permission, may read across all approved operational stations.
- Global read does not grant create, update, approve, role assignment, membership administration or platform administration.
- The greenfield station directory uses the atomic actor-bound RPC proposal documented in `docs/architecture/METRA-GREENFIELD-STATION-DIRECTORY-DOTNET-READER-2026-11-15.md`. The actor is derived from the validated JWT `sub`; clients never submit an actor UUID.
- Keep `Features:GreenfieldStationDirectoryEnabled` disabled until the reviewed SQL proposals have been approved and applied to a non-production project, the runtime secret and PostgREST ACLs are verified, and cross-station isolation tests pass.
- The associated SQL in `database/proposals/036_*` and `037_*` is proposal-only. CI applies it only to a disposable PostgreSQL fixture. Never run it against hosted Supabase without explicit approval.
- The service-role key is used only by the server for the narrow directory RPC; never put it in Flutter, browser config, mobile bundles, source control, or logs.

## Recorder image pipeline
1. Authorize the capture and station scope.
2. Issue one-time, short-lived upload intent with byte cap and expected SHA-256.
3. Receive bytes into private quarantine; no public ACL.
4. Verify byte count, magic bytes, MIME/extension consistency, digest and decoded image dimensions.
5. Run malware/content inspection. Unknown/timeout means remain quarantined.
6. Append audit evidence and scanner version.
7. Promote the exact verified object only after the acceptance policy passes.
8. Generate previews and OCR/trace derivatives in isolated workers, retaining links to original asset and tool version.
9. Authorize each read independently; never treat an object UUID as a bearer credential.

## Worker isolation
- Run OCR, chart digitization, CLIMATOL and AI jobs in isolated containers/processes.
- Pin immutable container/image digest and configuration for every run.
- Use least-privilege, expiring input/output access; workers must not access unrelated authority data.
- Set CPU, memory, execution-time and output-size limits.
- Persist safe error codes and bounded logs; do not expose raw exception text to clients.
- Retries create distinct attempts. Never reopen a terminal attempt.

## Audit and provenance
Every create, upload, scan decision, preview, extraction, correction, approval, export, model action and climate publication must record actor, authority, station/resource, timestamp, action, reason, source/version and correlation ID. Sensitive reads and denied access should be observable under the approved privacy policy.

## Incident response
- Quarantine affected assets and disable relevant processing feature flags.
- Preserve audit evidence and immutable originals under legal hold if required.
- Revoke compromised credentials and stop worker identities.
- Determine affected stations, authorities, captures, derived values and published products via provenance links.
- Reprocess only from trusted immutable source snapshots.
- Restore from verified backups and document the incident timeline and approvals.

## Deployment gates
No production rollout while critical/high security findings remain open, readiness probes fail, backups are unverified, scanner verdict is indeterminate, schema is unapproved, or release artifacts are unsigned.

### Recorder acceptance invariants
- A scan verdict is accepted only when it is the explicitly defined `Clean` value; unknown enum values and indeterminate results remain quarantined.
- Scanner name and version must both be present, bounded to 100 characters, and free of control characters before an asset can pass the acceptance gate.
- The server-side verified byte length must be positive and no greater than the configured 20 MiB upload limit. A clean scan does not override a failed hash, signature, decoded-dimension, or length check.
- These checks are policy-level safeguards in addition to the upload validator. They do not replace private quarantine storage, authenticated authorization, malware scanning, or immutable audit persistence.
