# METRA 2027 — Registration Approval Queue Read Contract

Status: framework-independent read-only application query and unit tests are implemented. The production read store, HTTP endpoint, database adapter and cursor codec are not implemented or enabled.

## Query contract

The approval queue accepts only these filters:

- Optional exact workflow status.
- Optional exact station identifier.
- Page size from 1 through 100 (default 50).
- Optional opaque continuation cursor.

The API trims the station identifier, rejects control characters, rejects undefined status values, and bounds the cursor to 2,048 characters. It does not parse, decode or trust cursor contents.

## Actor and authorization

The actor is resolved through `IRegistrationApprovalActorContextProvider`; no actor ID is accepted from query parameters or request content. The application service rejects missing, inactive, malformed or unprivileged actor contexts before store access.

The store is the security boundary and must enforce the approved queue-read permission and exact visibility scope on every page request. Station-stage approvers must be limited to their authoritative station assignments. System-stage visibility must remain limited to the system-stage queue unless a separately approved policy explicitly grants broader visibility. A caller-supplied station filter narrows the result; it never widens authorization scope. The store must revalidate authorization and scope on each cursor page.

## Projection and pagination

The queue projection includes only request ID, METRA applicant account ID, requested station ID, canonical requested role code, workflow status and UTC submission time. It excludes Auth provider subjects, phone/email, free-text notes and approval decision details.

The store must use keyset pagination ordered by `SubmittedAtUtc DESC, RequestId DESC`. The cursor must be integrity-protected, opaque to the API, actor-bound, filter-bound and expiry-bound. Tampered, expired, cross-actor or cross-filter cursors must be rejected. The store must return no more than the requested page size.

The application service rejects duplicate request IDs, malformed identifiers/codes, undefined statuses, non-UTC timestamps, ascending or nondeterministic ordering, inconsistent `HasMore`/cursor combinations, and oversized/control-character continuation cursors. It returns a read-only snapshot of the result items.

## Explicitly not enabled

No HTTP endpoint is mapped. No production read-store implementation, database query, cursor cryptography, role mapping, station visibility policy, migration, schema change, Supabase project operation or seed data is included. The exact queue-reader permission and any cross-station/system visibility remain product/security approval decisions.
