# Authority access API contract

All routes require an authenticated METRA access token. The API derives the actor from the validated JWT sub claim; callers cannot choose the reviewer identity.

## Catalogue and request options

- GET /api/v1/authorities — active authority catalogue.
- GET /api/v1/authorities/{authorityId}/membership-roles — active roles and whether each role is requestable.
- GET /api/v1/authorities/{authorityId}/permission-options — permissions mapped to the caller's current approved role in this authority. Requires an active account and current approved membership.

## Membership lifecycle

- POST /api/v1/authorities/{authorityId}/memberships
  - Body: roleCode, reason, optional userId, validFrom, validTo.
  - Without userId, the caller requests their own membership. Supplying another userId is a sponsored request and requires authority.access.review. Self-service is limited to roles marked requestable.
- POST /api/v1/authorities/{authorityId}/memberships/{membershipId}/decision
  - Body: decision (approve or reject), reason.
- POST /api/v1/authorities/{authorityId}/memberships/{membershipId}/revocation
  - Body: reason.
  - Revocation also revokes that subject's active permission grants in the same authority.

## Individual permission grants

- POST /api/v1/authorities/{authorityId}/permission-grants
  - Body: permissionCode, reason, optional validFrom, validTo.
  - The caller must have a current approved membership whose role maps the requested permission.
- POST /api/v1/authorities/{authorityId}/permission-grants/{grantId}/decision
  - Body: decision (approve or reject), reason.
- POST /api/v1/authorities/{authorityId}/permission-grants/{grantId}/revocation
  - Body: reason.

## Queues and audit

- GET /api/v1/authorities/{authorityId}/access-queue?kind=membership|permission_grant|membership_active|permission_grant_active&limit=50
  - Pending queues require authority.access.review.
  - Active membership/grant directories require authority.access.revoke.
- GET /api/v1/authorities/{authorityId}/access-audit?limit=100
  - Requires authority.access.review.

## Enforcement

The authority ID in the route is checked again by the database decision/revocation RPCs against the target record. Membership and grant transitions use row locks and append-only audit events. Requesters and subjects cannot approve their own requests. The service-role key is held only by the ASP.NET server and is never returned to clients.

Typical responses are 200 for successful transitions/reads, 400 for invalid input, 401 for missing identity, 403 for insufficient scope, 404 for unknown records, 409 for state conflicts, and 503 when the database service is unavailable. The database remains the final authority for every decision.
