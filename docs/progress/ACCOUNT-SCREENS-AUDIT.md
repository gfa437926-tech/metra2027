# METRA 2027 — Flutter account and identity screens audit

- **UTC:** 2026-11-11T16:27:46.380Z
- **Task:** ACC-AUDIT-01
- **Repository:** `gfa437926-tech/metra2027`
- **Branch:** `work/flutter-canonical-consolidation`
- **Canonical Flutter:** `flutter-app/`
- **Reference source:** `mobile/metra_mobile/` on `main`
- **Status:** Source audit complete; account-state display enhancement committed; access-context and role administration remain blocked by missing API contract.
- **Scope:** Master specification IDs ID-01 through ID-06 and administration IDs AD-01 through AD-04.

## 1. Current screen inventory

| Requirement | Canonical implementation | Audit result |
|---|---|---|
| ID-01 Sign in | `core/auth/metra_auth.dart` | Partial. Supabase email/password, secure session storage, validation, busy/error states, recovery and registration links exist. The auth gate currently checks only whether a Supabase session exists; it does not resolve the METRA account state or effective access context before opening the home shell. |
| ID-02 Registration request | `features/auth/registration_screen.dart` | Implemented baseline. Identity creation is separate from the METRA request; stations are filtered to approved/active/non-demo; roles come from the requestable-roles API; terms and an idempotency key are sent; client does not grant permissions. Email-confirmation path requires the user to sign in again before submitting the METRA request. |
| ID-03 Registration review | `features/admin/registration_review_screen.dart` | Partial. Station and system-stage queues and decision calls exist; rejection reason and stage switching are tested. Needs broader authorization, stale/concurrent decision, empty/error and audit-history coverage. |
| ID-04 Password recovery | `features/auth/password_recovery_screen.dart` | Partial. Reset-email request and privacy-safe response exist with tests. Password-reset deep-link completion / new-password confirmation route and release redirect configuration are not evidenced in this Flutter client. |
| ID-05 Account/profile | `features/account/account_profile_screen.dart` | Improved in this task. Displays identity provider, account state, registration request state, review note and UTC submission time using `GET /api/v1/account/registration-status`. It still cannot show assigned stations or effective roles/permissions. |
| ID-06 Access denied/session expired | No dedicated global screen or auth-state route | Missing. Individual screens map some 401/403 errors, but there is no consistent app-level denied/pending/disabled/revoked-session state and protected-view clearing policy. |
| AD-01 User directory | `features/admin/station_assignment_screen.dart` uses station users | Partial and station-scoped only. No global user directory/search or full account detail. |
| AD-02 User details | Profile shows email and registration state | Partial. No verified personal metadata, station assignment history or effective permission detail API. |
| AD-03 Role/permission administration | No canonical permission-administration screen | Missing. Static `role_workspace_catalog.dart` is a navigation description, not an account's actual roles and never an authorization source. |
| AD-04 Station assignment | `features/admin/station_assignment_screen.dart` | Partial. Server-provided assignable roles, request/decision/revoke actions and reason capture exist. Requires lifecycle/expiry/revocation, cross-station and broader role tests. |

## 2. Verified backend contract boundaries

- `GET /api/v1/account/registration-status` derives the subject from the verified JWT and returns the registration-status projection: `account_state`, `state_reason`, latest `request_id`, `request_status`, `submitted_at`, and `review_note`.
- That endpoint does **not** return authority memberships, station assignments, effective permission grants, or a complete current-user access context.
- Station user listing is exposed as `GET /api/v1/stations/{stationId}/users` and requires `users.station.view`.
- Station assignment operations are station-scoped and require `users.station.manage`; the client obtains assignable roles from the server rather than inventing them.
- Registration review uses server-side station/authority authorization. Client navigation must not be treated as permission.
- Authority membership and permission-grant lifecycle database functions exist in migration history, but a complete corresponding account-administration API/UI workflow is not established in the reviewed route inventory.

## 3. Security findings

1. **Session is not equivalent to an active METRA account.** `MetraAuthGate` currently routes any signed-in Supabase session to `MetraHome`. This is a client UX gap; protected operations must continue to rely on server-side account-state, role, assignment and permission checks.
2. **Navigation is not role-aware.** The home “More” menu and static role-workspace catalogue expose navigation labels without a current-user permission projection. This is not authorization, but it can confuse users and is not accepted as a completed role experience.
3. **No effective-access projection.** The profile cannot truthfully display a user's current stations, authority memberships or permission grants with the existing registration-status endpoint.
4. **No global access-state experience.** Pending, suspended, disabled, revoked and expired states are not consistently handled at the app shell.
5. **Password recovery completion is incomplete.** The current screen requests an email; deep-link handling and setting a new password must be checked before release.

## 4. Changes made in this round

- Added an optional server-status loader to `MetraAccountProfileScreen`.
- Bound it to `MetraApiClient.getMyRegistrationStatus` from the canonical home shell.
- Added explicit labels for account state and registration stage, review note, and UTC request timestamp.
- Added loading, unavailable and retry states; provider exception text is not rendered.
- Added widget tests for authoritative status display and safe failure handling.
- No account role, station assignment or permission is inferred from a registration status response.

## 5. Required next implementation gates

| Task | Required work | Gate |
|---|---|---|
| ACC-02 | Design and approve `GET /api/v1/account/access-context` backed by a server-derived JWT subject. It must expose only the caller's account state, current authority memberships, station assignments, effective permissions and validity windows. | Backend/API and data-contract review; no DB change until owner approval. |
| ACC-03 | Build a real “الأدوار والصلاحيات” screen from the access-context response, including source, scope, validity and revoked/expired state. | Must not use static role labels as grants. |
| ACC-04 | Add app-level pending/suspended/disabled/access-denied/session-expired states; clear protected content after revoked/expired access and handle 401/403 consistently. | Requires the access-context contract and auth lifecycle tests. |
| ACC-05 | Verify Supabase recovery redirect/deep-link behavior and add the new-password completion screen/test. | Requires approved redirect URI and runtime verification. |
| ACC-06 | Add authorized user directory and account details; keep station-scoped users distinct from authority-wide users. | Requires explicit API routes and permission grants. |
| ACC-07 | Extend registration-review and assignment tests for forbidden actor, wrong station, expired/revoked assignment, duplicate/concurrent decision, empty/error states and audit trail. | API/backend integration evidence. |

## 6. Acceptance tests still required

- Anonymous, pending, active, suspended and disabled account states.
- Expired/revoked JWT and refresh failure; protected content is cleared.
- User A cannot read or mutate User B's profile or assignment.
- A station manager cannot review or list users for another station.
- Revoked/expired assignment immediately stops enabling the corresponding action.
- A role label without an effective permission grant never enables an action.
- Registration request cannot self-approve or self-grant a role.
- Recovery email response does not disclose whether an account exists; reset deep link can set a new password safely.
- Sign-out removes the local secure session and returns to sign-in.

## 7. Explicit non-changes

- No Supabase migration, RLS, policy, grant, seed or schema modification.
- No write to the new or legacy database.
- No service-role key in Flutter.
- No global role or station scope inferred from a display label.
- No merge to `main`, production deployment or deletion of `mobile/metra_mobile/`.
- Flutter analyzer, widget tests, Android/iOS builds and visual checks have **not** been executed in this environment; source tests are committed but not reported as passing.
