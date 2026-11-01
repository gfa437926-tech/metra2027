# METRA 2027 — Identity and Account Lifecycle Migration

Status: legacy behavior extracted; replacement contract proposed; implementation intentionally blocked pending identity-provider and data-model approval.

## Scope inspected

Legacy sources inspected:
- `index.html` — sign-in, registration and password-recovery form fields.
- `login.js` — login, registration request, approval checks, password reset and notifications.
- `auth-manager.js` — browser session, role checks, logout and role-based redirects.
- Current backend sources — `Program.cs`, observation authorization policy and API project structure.

This document records observable behavior and security findings. It does not authorize changes to Supabase, identity configuration, user records or production credentials.

## Original user-facing fields and labels to preserve

Registration form:
- `first_name` — الاسم الأول
- `father_name` — اسم الأب
- `last_name` — الكنية
- `station` — المحطة
- `role` — صفة العمل
- `email` — البريد الإلكتروني
- `phone` — رقم الهاتف
- `password` and `confirmPassword` — كلمة المرور وتأكيد كلمة المرور
- `program_password` — كلمة مرور البرنامج (legacy-only; do not carry its shared-secret implementation forward)
- `agreeTerms` — الموافقة على الشروط والأحكام

The registration UI currently exposes these exact role labels:
- راصد جوي
- متنبئ جوي
- رئيس محطة
- مدير مركز
- مدير النظام
- رئيس دائرة الشبكات

The legacy role redirect map also references additional roles, including مبرمج الدعم الفني، رئيس الاتصالات، رئيس الورشات، ومدقق. The role catalogue is therefore inconsistent across screens and must be reconciled against the full original administration workflow before it becomes a canonical permission catalogue.

The legacy station selector is populated from a hard-coded JavaScript list. Treat that list as migration evidence only; station records must come from the approved station catalogue, not a duplicated client-side constant.

## Observed lifecycle

### Sign-in
1. User submits email and password.
2. Legacy code directly queries the `users` table, compares a client-produced hash, and checks account status.
3. Only `active` or `approved` status is accepted.
4. Login count and last-login metadata are updated.
5. A user profile snapshot is written to `localStorage.currentUser`.
6. Navigation is selected using the locally stored role.

Target behavior:
- Delegate credential verification, MFA and recovery to the selected identity provider.
- Resolve the authenticated identity on the server; never trust a browser-supplied user ID, role, station or status.
- Load the approved profile and current assignments from server-controlled records.
- Return a minimal current-user context to Angular and Flutter.
- Update login telemetry server-side without making a successful login depend on a non-critical telemetry write.

### Registration request
1. Collect the profile fields above.
2. Check for an existing email in `users` and `registration_queue`.
3. Legacy code hashes the submitted password in the browser and inserts a `pending` row into `registration_queue`.
4. The described workflow is station-manager approval followed by system-manager approval.
5. A notification attempt is made for the station manager.

Target behavior:
- Create an identity-provider registration/invitation or pending identity according to the approved provider flow.
- Store a registration request with explicit state and immutable audit events.
- Keep requested role and station separate from granted role and active station assignment.
- Require the station-manager decision, then the system-manager decision, with actor, timestamp and decision note.
- Provision active access only after all required approvals.
- Prevent duplicate pending requests using server-side uniqueness and transactional checks.
- Send notifications through a backend notification service; do not treat a client-side console log as delivery.

### Account recovery
Legacy recovery looks up a user using email and phone, generates a temporary password in browser JavaScript, logs that password to the console and displays it on screen, then writes a new password hash directly to the users table.

This flow must not be migrated. Use the identity provider's verified recovery flow with short-lived, single-use recovery tokens. Never generate, log, display or persist a temporary password in application code.

### Session and authorization
Legacy `auth-manager.js` reads `localStorage.currentUser`, considers the session valid for 24 hours, checks role strings in the browser, and allows profile data to be merged back into local storage.

This is presentation state only and cannot provide security. The replacement must:
- Validate tokens/session server-side on protected API requests.
- Enforce permissions in the API for every operation.
- Resolve active station assignments from persisted server-side records.
- Check both permission and resource station scope.
- Support session revocation and account suspension through the identity provider.
- Keep client route guards as navigation UX only.

## Required domain separation

Do not collapse these concepts into one `users.role` or `users.station` field:
- Identity: provider subject / immutable user identifier and verified email.
- Profile: first name, father's name, family name and phone.
- Account state: pending, active, suspended, rejected (final enum to be approved).
- Requested access: station and work role selected in the registration request.
- Granted permissions: server-controlled permission grants.
- Station assignment: station, validity interval, assignment state and authorizing actor.
- Approval history: stage, decision, actor, timestamp and notes.
- Session/security events: sign-in, sign-out, recovery and revocation events.

The current observation authorization policy already expects a server-derived actor context, an active station assignment, a matching station and an explicit permission. Identity integration must provide that context; do not populate it from request JSON or browser storage.

## Security issues confirmed in legacy implementation

- Password verification and hashing are implemented in browser JavaScript.
- A shared program password is hard-coded in `login.js`.
- The client directly reads and writes `users` and `registration_queue`.
- The client stores role, station and account state in local storage and uses them for authorization decisions.
- Recovery reveals a generated temporary password in the browser and console.
- Approval state and login metadata are updated through client-side database calls.
- Station choices are hard-coded and role catalogues differ between registration and redirect code.

These are migration blockers, not behavior to preserve. Preserve the Arabic labels and operational approval intent, not insecure implementation details.

## Decisions required before implementation

1. Select and approve the identity provider and its session/token model.
2. Confirm whether Supabase Auth is the intended identity provider or whether the .NET API will integrate with another OIDC provider.
3. Approve the canonical role catalogue and permission matrix, reconciling the extra legacy roles.
4. Confirm the authoritative station catalogue and station assignment lifecycle.
5. Confirm whether the existing `users` and `registration_queue` data are to be migrated, mapped or retained read-only.
6. Approve the account-state and two-stage approval state machine.
7. Approve notification delivery channel and recovery email configuration.

Until those decisions are approved, do not create or alter Supabase tables, RLS policies, auth settings, user records or production secrets.

## Acceptance tests for the replacement

- Pending, rejected and suspended accounts cannot access protected operations.
- A registration request cannot grant itself a role or station assignment.
- A station manager can approve only requests within their active station scope.
- A system manager can perform only the explicitly granted second-stage approval.
- A user without an active station assignment cannot submit observations.
- A user cannot read, edit, submit or approve observations outside their station scope.
- Client-edited local storage cannot change the authenticated identity or permissions.
- Password recovery never reveals a password to the browser.
- Revoked sessions are rejected by protected API endpoints.
- Angular and Flutter receive the same server-defined current-user and permission contract.
