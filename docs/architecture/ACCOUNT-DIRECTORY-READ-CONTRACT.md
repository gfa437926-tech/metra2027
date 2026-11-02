# METRA account directory read contract

## Purpose and status

This document defines a provider-independent, read-only application boundary for administrative account listings. It is a contract and testable application service only. It does not approve a physical database schema, permission code, role mapping, API route, or production data adapter.

## Query

- Optional account state filter, restricted to defined account-state values.
- Optional station identifier filter. It narrows the actor's already-authorized scope and must never widen it.
- Optional canonical account-ID prefix. The prefix is literal, bounded, and must not be interpreted as SQL wildcard syntax or a query expression.
- Page size is bounded to 1–100.
- Continuation cursor is opaque to the API and bounded in length.

## Projection and privacy

The listing returns only the internal METRA account identifier and account state. It does not return Auth provider subjects, email addresses, phone numbers, profile fields, permission facts, station assignments, free-text notes, or audit before/after values. Separate, independently authorized detail workflows may be specified if required.

## Authorization and store obligations

The actor identifier is resolved from the authenticated server request; it is never accepted from the query. The trusted store must enforce the exact approved account-directory permission and authoritative station scope on every page. No concrete permission code or role is selected by this contract. A station filter only intersects the actor's existing scope.

The store must validate cursor integrity and bind it to actor identity and every normalized filter. Cursor reuse across actors or filters must fail. Use deterministic keyset ordering by AccountId ASC; do not use offset pagination for this contract. The store must apply the literal account-ID prefix safely.

## Response validation

The application service rejects oversized pages, invalid account identifiers or states, duplicate identifiers, non-ascending order, filter leakage, malformed continuation state, and cursors that repeat the incoming cursor. Returned collections are read-only.

## Activation gates

No endpoint mapping, dependency-injection registration, production read-store implementation, schema migration, RLS change, grant, seed data, or database query is introduced by this contract. Activation requires review and approval of the physical schema, exact permission catalogue, station-scope semantics, cursor protection mechanism, store transaction/consistency strategy, and integration tests.

## Tests

The test suite covers actor resolution, malformed actor identity, bounded pagination, undefined state, malformed filters and cursors, page overflow, duplicate/out-of-order records, invalid states, filter leakage, continuation consistency, and immutable response collections.
