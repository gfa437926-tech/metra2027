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
| ID-01 Sign in | `core/auth/metra_auth.dart` + `features/account/account_state_gate.dart` | Improved. Supabase session is followed by `GET /api/v1/account/registration-status`; only `account_state=active` opens the operational shell. Pending/null routes to registration/status; suspended/disabled/rejected/unknown and status-service errors fail closed. Effective permissions are still not projected to the shell. |
| ID-02 Registration request | `features/auth/registration_screen.dart` | Implemented baseline. Identity creation is separate from the METRA request; stations are filtered to approved/active/non-demo; roles come from the requestable-roles API; terms and an idempotency key are sent; client does not grant permissions. Email-confirmation path requires the user to sign in again before submitting the METRA request. |
| ID-03 Registration review | `features/admin/registration_review_screen.dart` | Partial. Station and system-stage queues and decision calls exist; rejection reason and stage switching are tested. Needs broader authorization, stale/concurrent decision, empty/error and audit-history coverage. |
| ID-04 Password recovery | `password_recovery_screen.dart` + `password_update_screen.dart` + auth recovery event | Partial, source implemented. Reset email uses `metra2027://auth-callback`; Android/iOS schemes and passwordRecovery event/new-password update flow are added. Supabase redirect allow-list and real-device email round-trip remain unverified. |
| ID-05 Account/profile | `features/account/account_profile_screen.dart` | Improved in this task. Displays identity provider, account state, registration request state, review note and UTC submission time using `GET /api/v1/account/registration-status`. It still cannot show assigned stations or effective roles/permissions. |
| ID-06 Access denied/session expired | `features/account/account_access_state_screen.dart` + `account_state_gate.dart` | Partial, source implemented. Shows blocked state, reason, retry and sign-out; status lookup failure fails closed. A distinct revoked-token/session-expired event path and comprehensive protected-view clearing tests remain. |
| AD-01 User directory | `features/admin/station_assignment_screen.dart` uses station users | Partial and station-scoped only. No global user directory/search or full account detail. |
| AD-02 User details | Own-account profile plus station assignment detail sheet | Partial. Assignment metadata is visible; verified personal details, assignment history and effective permission detail API remain unavailable. |
| AD-03 Role/permission administration | `features/admin/authority_access_screen.dart` | Partial, API-backed baseline. Lists authority-scoped membership/permission queues, allows self-request, approve/reject/revoke and reads append-only audit events. Effective permissions for the signed-in user are not yet displayed; user-targeted requests and validity-end editing are not yet in the UI. |
| AD-04 Station assignment | `features/admin/station_assignment_screen.dart` | Improved partial. Server-provided roles, request/decision/revoke, mandatory reasons, explicit optional UTC `valid_to`, and an assignment detail sheet now exist. Still needs a searchable authorized target-user directory and lifecycle/cross-station tests. |

## 2. Verified backend contract boundaries

- `GET /api/v1/account/registration-status` derives the subject from the verified JWT and returns the registration-status projection: `account_state`, `state_reason`, latest `request_id`, `request_status`, `submitted_at`, and `review_note`.
- That endpoint does **not** return authority memberships, station assignments, effective permission grants, or a complete current-user access context.
- Station user listing is exposed as `GET /api/v1/stations/{stationId}/users` and requires `users.station.view`.
- Station assignment operations are station-scoped and require `users.station.manage`; the client obtains assignable roles from the server rather than inventing them.
- Registration review uses server-side station/authority authorization. Client navigation must not be treated as permission.
- Authority membership and permission-grant lifecycle API/UI are now wired in the canonical Flutter branch through `AuthorityAccessScreen`; the API enforces membership/permission scope and append-only audit. The screen is a partial workflow: it does not yet display the caller's effective access context, does not request membership on behalf of another user, and does not edit validity end dates.

## 3. Security findings

1. **Session is not equivalent to an active METRA account.** The canonical gate now checks the server registration-status projection before opening `MetraHome`. Only `active` opens the operational shell; pending/null routes to registration/status, while suspended/disabled/rejected/unknown and lookup failures fail closed. This is still a client gate, not a replacement for server authorization.
2. **Navigation is not role-aware.** The home “More” menu and static role-workspace catalogue expose navigation labels without a current-user permission projection. This is not authorization, but it can confuse users and is not accepted as a completed role experience.
3. **No effective-access projection.** The profile cannot truthfully display a user's current stations, authority memberships or permission grants with the existing registration-status endpoint.
4. **No global access-state experience.** Pending, suspended, disabled, revoked and expired states are not consistently handled at the app shell.
5. **Password recovery release verification remains open.** The deep-link and new-password form are now implemented; Supabase Dashboard allow-list and real-device recovery round-trip must pass before release.
6. **Authority access UI is not self-authorizing.** `AuthorityAccessScreen` is exposed in More, but every read/write operation depends on server-side permissions; 403 responses are shown as scope-denied states. Do not infer authority roles from the selected authority or tab.

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


## ACC-03 — Authority membership and permission UI — 2026-11-11T16:37:06.421Z

- Added `flutter-app/lib/features/admin/authority_access_screen.dart` and linked it from the canonical More menu.
- Added client methods for authority catalogue, membership roles, permission options, pending/active access queues, append-only audit reads, membership request/decision/revocation and permission-grant request/decision/revocation.
- The UI only requests a membership for the signed-in user; it only requests permission codes returned by the server for the caller's current approved membership. It does not grant locally.
- Pending membership/grant queues expose approve/reject with mandatory reason; active/scheduled records expose revocation with mandatory reason. The server remains the authority and enforces review/revoke permissions and state conflicts.
- The audit tab reads the server audit log and displays subject, actor, action, reason and UTC event time.
- Added `flutter-app/test/authority_access_screen_test.dart` for authority catalogue, queue and audit reads.
- No database changes were made. Existing migrations/RPCs are read-only references for this UI; no migration or grant was applied.
- Remaining: caller access-context display, target-user selection for delegated membership requests, valid-to scheduling controls, broader forbidden/transition tests, and Flutter CI execution.


## ACC-04 — Account-state gate and registration duplicate guard — 2026-11-11T16:41:30.308Z

- Added `MetraAccountStateGate` and `MetraAccountAccessStateScreen`.
- `MetraAuthGate` now calls the authenticated server registration-status endpoint before opening the operational home.
- Only `account_state=active` opens `MetraHome`; pending/null states route to registration/status; suspended/disabled/rejected/unknown states are blocked; status API errors fail closed with retry and sign-out.
- Registration screen now shows both account state and request approval stage and suppresses duplicate submission while station/system approval is pending.
- Added widget tests for active, pending, disabled and API-error gate states, and for preventing a duplicate pending registration.
- This does not replace API authorization; each protected operation remains server-enforced. The effective permission/assignment context is still not returned to the Flutter shell.
- No database changes or migration execution.


## ACC-05 — Station assignment validity and detail view — 2026-11-11T16:45:52.938Z

- Added optional `valid_to` entry to the station assignment request form. When supplied, it must parse as an ISO-8601 timestamp with UTC marker/offset and be in the future; it is normalized to UTC before submission. Empty means open-ended.
- Added a read-only assignment detail bottom sheet showing assignment/user IDs, role, status, UTC validity window, reason, requester and creation time.
- Added widget coverage for submitting an expiry and opening the assignment detail sheet.
- User selection still uses an entered user UUID because no searchable eligible-user lookup API is present. The server remains authoritative for target-account and station-scope validation.


## ACC-06 — Password recovery completion — 2026-11-11T16:51:58.537Z

- Added `MetraPasswordUpdateScreen` with minimum length, confirmation matching, loading/success and redacted failure states.
- `MetraAuthGate` now listens for Supabase `AuthChangeEvent.passwordRecovery` and routes to the password update screen; success rechecks the METRA account status before any operational page.
- Password recovery email requests now use `metra2027://auth-callback`.
- Registered the custom scheme in Android manifest and iOS Info.plist.
- Added password-update widget tests and documented the required Supabase Additional Redirect URL in `docs/security/SUPABASE-AUTH-REDIRECT-SETUP.md`.
- **External gate:** the redirect URI has not been added to Supabase Dashboard; test with an actual email link on Android/iOS before release.


## ACC-06 — Password recovery completion — 2026-11-11T16:56:51.541Z

- Added `MetraPasswordUpdateScreen` with minimum-length and confirmation validation, loading/success states and redacted provider failures.
- `MetraAuthGate` handles Supabase `AuthChangeEvent.passwordRecovery`, routes to the new-password form, and rechecks METRA account status after a successful update.
- Recovery requests use `metra2027://auth-callback`; Android manifest and iOS URL scheme registration are included.
- Added `docs/security/SUPABASE-AUTH-REDIRECT-SETUP.md`. Supabase Dashboard allow-list and real-device email-link verification remain release gates.

## ACC-07 — Station assignment audit history — 2026-11-11T16:56:51.541Z

- Added `getStationAuditLog` client method and `StationAuditLogScreen` using the existing station-scoped `GET /api/v1/stations/{stationId}/audit-log` endpoint.
- Linked the audit log from station assignment management. The screen displays actor, target, role, previous/resulting status, UTC validity and reason; server permission failures remain visible without exposing provider internals.
- Added widget test for the audit read model.
