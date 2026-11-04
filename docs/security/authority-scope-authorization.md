# Authority access lifecycle

## Implementation status

Database migrations 020–022 implement authority-scoped memberships, individual permission grants, protected review queues, revocation, and append-only access auditing. ASP.NET Core exposes authenticated routes for membership and permission-grant requests, decisions, revocations, queues, and audit reads.

## Enforcement

- Permission grants now include an authority identifier. Station and authority permission predicates require the grant to belong to the exact authority being checked.
- Membership and grant approvals require an active reviewer with the authority-level review permission, an active role mapping, and an individual grant in the same authority.
- Requesters cannot approve their own requests. State-changing operations lock the target and reviewer authorization rows.
- Revoking a membership also revokes that user's active grants in the same authority.
- Access events are written to an RLS-protected audit table. A database trigger rejects update, delete, and truncate operations.
- Direct service-role writes to membership and grant tables are revoked; the API uses narrow database RPCs.

## Verification and release gates

- Supabase security advisor reported zero security lints after migrations 020–022.
- Negative SQL checks passed for inactive requesters, unknown IDs, unauthorized queue/audit reads, and attempted audit mutation.
- The new project currently contains no Auth users, account states, authority memberships, permission grants, or access-audit events. Real-user, cross-authority, self-approval, and concurrency tests therefore remain outstanding.
- Initial administrator onboarding requires a verified identity and owner-controlled approval path. No default administrator or synthetic account is created.
- Production API hosting and secret configuration still need to be supplied and verified.

**Release status: not production-ready** until real identity tests, administrator onboarding, and live API deployment/readiness checks are complete. The legacy database remains untouched.
