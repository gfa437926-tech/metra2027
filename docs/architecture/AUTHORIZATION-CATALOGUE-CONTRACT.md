# METRA 2027 — Authorization Catalogue Validation Contract

Status: implemented as a provider-independent structural validator. No production role names, permission names, or role-to-permission mappings are approved by this contract.

## Purpose

The catalogue is the controlled vocabulary used by administration and authorization workflows. It is not itself an authorization grant. A role assignment must not directly authorize an API operation: the server resolves approved role mappings into explicit, scoped, time-bounded permission grants, and the effective-permission evaluator remains the runtime enforcement point.

## Catalogue elements

- Role definition: canonical code, display name, and whether the role may be assigned to accounts.
- Permission definition: canonical code, display name, and whether the permission is enabled for new assignment/use.
- Role-permission mapping: a reference from one known role code to one known permission code.

Display names are presentation data and may be localized. Codes are stable machine identifiers and are compared ordinally. The validator accepts only lowercase ASCII alphanumeric segments separated by a single dot, underscore, or hyphen; codes are limited to 128 characters.

## Validation guarantees

The pure validator rejects:

- missing catalogue or missing collections;
- null, malformed, blank-label, or duplicate role/permission definitions;
- noncanonical mapping codes;
- mappings to unknown roles or permissions;
- duplicate role-permission pairs.

It does not normalize codes, infer mappings, decide whether a role should exist, or assign permissions. A disabled permission and a non-assignable role may remain in the catalogue as historical/configuration data; enforcement of those flags belongs to the administrative command and grant-creation policies.

## Security and lifecycle boundaries

- A catalogue mapping is not a user grant.
- A role assignment is not a substitute for a permission grant.
- Station scope is not encoded by this catalogue mapping; effective station authorization still requires an exact station-scoped grant and a current station assignment.
- Changes to catalogue definitions or mappings require privileged server-side administration, validation, audit history, and concurrency control.
- Existing grants must not silently gain new permissions merely because a role mapping changes. Any grant reconciliation is a separate reviewed operation with explicit audit events.
- The runtime authorization layer must fail closed when a requested permission is unknown, disabled, or absent from the effective grants.

## Deliberately undecided

This contract does not select METRA role codes, permission codes, Arabic labels, role hierarchy, default mappings, account-to-role cardinality, or permission inheritance. Those are product and governance decisions requiring explicit approval. No database schema, migration, seed data, Supabase configuration, or live project access is authorized by this work.
