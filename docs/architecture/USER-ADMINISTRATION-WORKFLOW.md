# METRA 2027 — User Administration and Station Assignment Workflow

Status: implementation-ready workflow proposal; business authorization and persistence mapping remain pending.

This document turns the observed legacy registration and approval behavior into a reviewable workflow. It does not select an identity provider, grant permissions to roles, define SQL, or authorize changes to Supabase.

## 1. Non-negotiable boundaries

- ASP.NET Core is the application authority for account state, profile, approvals, role grants, station assignments and authorization.
- The identity provider alone handles credentials, MFA, verified identity and credential recovery.
- Angular and Flutter use the same versioned API contracts.
- A requested role or station is never an effective grant.
- Role names and client route visibility are not permissions.
- Every protected action is re-authorized by the API using current server-side facts.
- No browser storage value can establish the actor, account state, role, station or permission.
- Existing Supabase tables, rows, Auth settings and RLS remain unchanged until a separately approved migration plan exists.

## 2. User registration and approval lifecycle

### Proposed states

| State | Meaning | Effective access |
|---|---|---|
| PendingStationApproval | Request submitted; station decision is outstanding | None |
| PendingSystemApproval | Station decision accepted; system decision is outstanding | None |
| Active | All required approvals completed and account provisioned | Only explicit, current grants |
| Rejected | Request rejected at an approval stage | None |
| Suspended | Previously active account access suspended | None |

These names align with the current application-service enum but remain subject to business approval. Unknown states must fail closed.

### Transition rules

1. **Submit request** — validate the profile, requested station, requested role, terms acceptance, verified identity workflow and duplicate-request rules. Create the request and audit event atomically. The requested role and station remain requests only.
2. **Station decision** — only an actor with the explicit station-approval permission and an active assignment covering the requested station may approve or reject. Record actor, stage, decision, timestamp and note.
3. **System decision** — only an actor with the explicit system-approval permission may approve or reject a request already accepted at the station stage. The API must reject skipped or out-of-order stages.
4. **Provisioning** — after all required approvals, provision the METRA account and separately create the approved role grant and station assignment. Do not infer either from the registration payload.
5. **Suspension** — suspend access through a separately authorized administrative action. Revoke or invalidate active grants/assignments according to the approved policy, and ensure existing sessions cannot continue to authorize protected operations.
6. **Reactivation** — require an explicit, audited administrative decision. Re-check the identity link, current assignments and grants; never reactivate by changing a client-side flag.
7. **Resubmission** — rejected-request resubmission behavior is not yet approved. Do not silently reopen or overwrite the historical request.

### Required invariants

- A user cannot approve their own request.
- One stage cannot substitute for another.
- A station manager cannot decide requests outside their active station scope.
- System approval is not implied by station approval.
- Duplicate pending requests for the same identity are prevented by an authoritative transactional rule.
- Repeated decisions are idempotent or return a stable conflict; they never create duplicate assignments.
- A failed notification does not roll back a valid approval; notification delivery is retried and tracked separately.
- Every state transition has an immutable audit event.

## 3. Station assignment lifecycle

A station assignment is a separately governed relationship, not a profile string.

Each effective assignment must carry at least these conceptual facts:

- METRA account identifier;
- authoritative station identifier;
- granted role code or assignment category;
- validity start and exclusive validity end;
- active/revoked state;
- authorizing actor and approval reference;
- audit timestamps and reason.

Rules:

- A requested station is not an assignment.
- An assignment is effective only when the account is Active, the assignment is active, its start time is inclusive, its end time is exclusive, and it has not been revoked.
- Station changes require a new authorized assignment decision and audit event; do not overwrite history.
- Multiple simultaneous assignments are allowed only if the business owner confirms that use case and scope semantics.
- Organizational units such as الإدارة العامة must not be treated as meteorological stations until their classification is confirmed.
- Station codes, coordinates, hierarchy and active status must come from the authoritative station master, not from hard-coded UI lists or inferred values.

## 4. Role and permission governance

The legacy evidence contains these distinct labels:

| Exact Arabic label | Evidence location | Canonical status |
|---|---|---|
| راصد جوي | Registration and redirect | Unapproved |
| متنبئ جوي | Registration | Unapproved |
| متنبئ في محطات الرصد | Redirect | Unapproved; do not merge with متنبئ جوي without confirmation |
| رئيس محطة | Registration and redirect | Unapproved |
| مدير مركز | Registration and redirect | Unapproved |
| مدير النظام | Registration and redirect | Unapproved |
| رئيس دائرة الشبكات | Registration and redirect | Unapproved |
| مبرمج الدعم الفني | Redirect only | Unapproved; operational status to confirm |
| رئيس الاتصالات | Redirect only | Unapproved; operational status to confirm |
| رئيس الورشات | Redirect only | Unapproved; operational status to confirm |
| مدقق | Redirect only | Unapproved; operational status to confirm |

No role-to-permission assignments are made here. The permission matrix must be approved capability by capability, rather than inferred from redirect destinations.

### Permission matrix template

| Capability | راصد جوي | متنبئ جوي / متنبئ في محطات الرصد | رئيس محطة | مدير مركز | مدير النظام | الشبكات | الدعم الفني | الاتصالات | الورشات | مدقق |
|---|---|---|---|---|---|---|---|---|---|---|
| Read station observations | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD |
| Create daily observations | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD |
| Edit own draft observations | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD |
| Review/approve observations | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD |
| Review station registrations | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD |
| Complete system approval | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD |
| Manage station assignments | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD |
| Manage role grants | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD |
| View audit history | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD | TBD |

The table is deliberately unresolved. The business owner must confirm the four redirect-only roles, the two forecaster labels, and the meaning of الإدارة العامة before the catalogue is finalized. A role may map to several explicit permissions, and the same permission may be granted to different roles with different station scopes.

## 5. Administration API behavior

The provider-neutral contract currently proposes:

- GET /api/v1/identity/me
- POST /api/v1/registration-requests
- GET /api/v1/registration-requests/{requestId}
- POST /api/v1/registration-requests/{requestId}/station-decision
- POST /api/v1/registration-requests/{requestId}/system-decision
- provider-managed recovery endpoints under /api/v1/identity/recovery

These are proposed routes, not claims that the endpoints are implemented. Each endpoint must validate the authenticated provider subject, resolve the METRA account from authoritative storage, enforce current account state and permission, and record state-changing actions transactionally.

The API must not accept caller-supplied actor IDs, effective role grants, account states, permission arrays or trusted station assignments. Registration accepts only requested access.

## 6. Audit events

At minimum, record these event categories:

- registration request submitted;
- station approval or rejection;
- system approval or rejection;
- account activated, suspended or reactivated;
- role grant created, changed, expired or revoked;
- station assignment created, changed, expired or revoked;
- identity linked or unlinked (only after a separately approved secure flow);
- authentication, sign-out, recovery and session-revocation security events.

Each event should identify the actor from the validated server context, target account/request, event type, UTC timestamp, outcome, correlation ID and a minimal decision note. Never write passwords, tokens, MFA secrets or recovery codes to audit logs.

## 7. UI requirements for Angular and Flutter

Both clients must present the same server-defined states and Arabic labels. The UI may hide unavailable actions for usability, but this is not authorization. On every decision action, the API re-checks permission, station scope and current workflow state.

The administration UI should distinguish:
- registration requests awaiting station review;
- requests awaiting system review;
- active and suspended accounts;
- effective role grants;
- current and historical station assignments;
- audit history.

Do not show a requested role/station as granted before provisioning completes. Do not fabricate demo users or static permission lists to make an unfinished integration appear operational.

## 8. Approval checklist before implementation

- [ ] Approve the identity provider and ASP.NET Core token/session validation model.
- [ ] Approve open registration versus invitation/verified-email enrollment.
- [ ] Approve the exact role catalogue and resolve both forecaster labels.
- [ ] Confirm whether the four redirect-only roles remain operational.
- [ ] Approve the role-to-permission matrix and station-scope rules.
- [ ] Approve whether multiple active station assignments are permitted.
- [ ] Confirm the authoritative station master and classify الإدارة العامة.
- [ ] Approve rejection, resubmission, suspension and reactivation behavior.
- [ ] Approve notification channels and operational retry/monitoring.
- [ ] Approve the legacy user/request data migration or read-only retention plan.
- [ ] Approve a separate database/RLS migration plan before any persistence change.

Until these decisions are recorded, continue with provider-neutral application contracts and tests only. Do not configure an identity provider, enable a permissive authentication handler, map production identity endpoints, or change Supabase.
