# METRA 2027 — Current-User Context and Administrative Audit Read Contract

Status: provider- and persistence-independent application contracts. No production data-source adapter, dependency-injection registration, HTTP endpoint or database migration is enabled by this document.

## 1. Current-user context

The authenticated provider identity is resolved only from a cryptographically validated server principal. The exact issuer + subject pair is the lookup key. Email, display name, client storage, route values and request payloads are not identity-link keys.

`ICurrentUserContextDataSource` must return one consistent authoritative snapshot containing:
- canonical METRA account ID and known account lifecycle state;
- the minimum profile fields approved for disclosure;
- station assignments with exact station ID, role code and validity/revocation instants;
- explicit permission grants with validity/revocation instants.

The adapter must reject duplicate issuer+subject links, ambiguous mappings, unlinked subjects and inconsistent records. It must not provision a METRA account from the existence of a valid provider token.

## 2. Application validation and projection

`CurrentUserContextApplicationService` validates the complete snapshot before producing a response:
- account state must be a defined METRA state;
- account, station and role identifiers must be canonical and bounded;
- required profile values must be present and bounded; optional values may be null;
- assignment and permission validity timestamps must use UTC;
- a finite validity end must be strictly later than its start;
- duplicate station + role assignment facts are rejected;
- malformed permission-grant facts are rejected, while well-formed permission codes outside the canonical application catalogue are not exposed.

Only an account whose state is exactly `Active` receives effective assignments or permissions. Start is inclusive; end and revocation are exclusive. Effective permissions are restricted to the canonical permission catalogue, deduplicated and sorted ordinally. Returned assignment and permission collections are read-only projections.

The response is a presentation snapshot, not an authorization token. Every protected operation must independently evaluate current account state, exact permission scope, station assignment and resource ownership on the server. A client-side route guard or cached current-user response never grants access.

## 3. Administrative audit read

`MetraAdministrativeAuditQueryService` obtains the actor ID only from the trusted server-side actor-context provider. The store must enforce the audit-read permission and any approved data/station scope on every request.

The read contract requires:
- bounded page size and canonical filter identifiers/codes;
- UTC and strictly ordered optional time bounds;
- opaque, integrity-protected cursors bound to the actor and normalized filters;
- keyset ordering by `(OccurredAtUtc DESC, EventId DESC)`;
- response validation for event structure, duplicate IDs, deterministic order and continuation semantics;
- read-only behavior; audit history is never modified by a query.

The ordinary list projection intentionally excludes free-text reasons and before/after values. A future event-detail operation requires a separate authorization and disclosure decision; it must not be added by widening the list response.

## 4. Required persistence guarantees

Before enabling an adapter, prove with isolated integration tests that:
- issuer + subject resolves to at most one METRA account;
- account, assignments and grants are read from one consistent snapshot;
- concurrent revocation or station reassignment cannot leave an authorization-sensitive write using stale facts;
- cursor signatures, expiry, actor binding and filter binding are enforced by trusted server-side code;
- audit read permission and approved scope are checked on every page;
- audit writes remain append-only and atomic with the business mutation they describe;
- cancellation propagates and data-source failures fail closed.

No live Supabase project is used for contract integration tests. Do not create tables, alter RLS, change grants or policies, or migrate data until the logical model and physical schema are reviewed and explicitly approved.

## 5. Activation gates

The current-user context and audit query services are application boundaries only. They are not registered as production services and no HTTP routes are mapped. Activation requires an approved identity issuer configuration, a reviewed authoritative persistence adapter, DI registration, endpoint-level authorization, API integration tests, privacy review and operational monitoring.
