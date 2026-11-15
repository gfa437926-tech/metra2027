# METRA station read-scope hardening — 2026-11-16

## Change

`MetraStationReadAuthorization` now separates the station-read permission allow-list from the global-read allow-list.

- Station-scoped grants can use only explicit `*.read_station` permissions and must match the requested station UUID.
- Global-read grants can use only explicit `*.read_all` permissions, only for `auditor` or `network_department_head`, and only when both station and organization identifiers are null. Ambiguous mixed-scope grants are rejected.
- Global read never authorizes write permissions.
- The snapshot remains a trusted server-side input. No endpoint or Supabase adapter currently constructs it; no caller-provided role/scope values are trusted.

## Additional tests

Added negative tests for using a global permission under station scope, mixed station/global scope, mixed organization/global scope, and attempting to use a global permission through a station grant. Existing tests cover station A/B isolation, auditor/network-head global reads, missing permission, inactive profile/membership/grant, malformed permission and write denial.

## Not activated

The evaluator is still a pure policy component. It is not wired into endpoints or a database authorization RPC. It must not be used as the sole control while direct database access can bypass it. The new `network_department_head` role and global-read permissions still require schema/catalogue review and a disposable PostgreSQL integration design.

No hosted Supabase schema, grants, RLS, data, secrets or runtime settings were modified. No legacy database was modified.