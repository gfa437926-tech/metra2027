# Support and maintenance authorization matrix

Status: proposed server-side contract; not yet wired to routes or persistence.

## Principal identity
- Resolve the actor from the validated JWT subject. Never accept actor ID, station scope, role, or permissions from the request body as authoritative.
- Resolve active account, station memberships, and permissions on the server for each operation. Reject disabled, unapproved, or stale principals.
- Keep service-role credentials server-side. Do not expose them in Angular, Flutter, logs, exceptions, or API responses.

## Station boundary
- A station observer may create and read records only for stations explicitly assigned to that actor.
- A station manager may review records only for their authorized station scope.
- Workshop/support staff may be assigned only when their active support membership permits the target station and incident category.
- Central support roles may access multiple stations only through explicit permission scope; do not infer global access from a role label alone.
- Every list, detail, update, attachment, export, and aggregate query must apply the same station boundary. A UUID supplied by a client is not proof of access.

## Suggested permissions
| Action | Permission |
|---|---|
| Submit equipment fault | `equipment_fault.create` |
| Read station fault queue/details | `equipment_fault.read` |
| Review / reject equipment fault | `equipment_fault.review` |
| Assign or reassign workshop technician | `equipment_fault.assign` |
| Start or update maintenance work (`InProgress`) | `equipment_fault.update` |
| Resolve or close maintenance | `equipment_fault.resolve` |
| Submit IT/telecom incident | `support_incident.create` |
| Read support incident | `support_incident.read` |
| Review / reject support incident | `support_incident.review` |
| Assign support incident | `support_incident.assign` |
| Start work or wait for information (`InProgress`, `WaitingForInformation`) | `support_incident.update` |
| Resolve or close support incident | `support_incident.resolve` |
| View station-scoped analytics | `operations.analytics.read` |

### Transition → permission mapping (API contract)
| Domain | Target status | Required permission |
|---|---|---|
| Equipment | UnderReview, Rejected | `equipment_fault.review` |
| Equipment | Assigned | `equipment_fault.assign` |
| Equipment | InProgress | `equipment_fault.update` |
| Equipment | Resolved, Closed | `equipment_fault.resolve` |
| Support | UnderReview, Rejected | `support_incident.review` |
| Support | Assigned | `support_incident.assign` |
| Support | InProgress, WaitingForInformation | `support_incident.update` |
| Support | Resolved, Closed | `support_incident.resolve` |


## Mutation requirements
1. Validate request shape and domain policy.
2. Authenticate actor and resolve current authorization scope.
3. Verify target record belongs to an allowed station and current lifecycle state permits the action.
4. Validate assignee is active and authorized for that station/category.
5. Apply mutation atomically with concurrency protection.
6. Write audit event containing actor, station, record, action, timestamp, and safe before/after metadata.
7. Return a stable response; do not expose internal exception or credential details.

## Audit and privacy
- Record denied cross-station access attempts without copying sensitive payloads into logs.
- Sanitize free-text and attachment names. Store attachments privately; issue short-lived, authorized download URLs only after record-level access checks.
- Restrict exports by permission and station scope, paginate, and audit export generation.
- Use UTC timestamps and explicit lifecycle transitions. Do not let clients directly set resolved/closed state or audit fields.

## Readiness gates
Before adding these routes to readiness checks, implement and test authorization, station isolation, audit persistence, error mapping, and dependency health. Until then, these are design requirements, not implemented controls.
