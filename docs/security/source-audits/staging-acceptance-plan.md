# METRA Weather Intelligence — staging acceptance plan

**Status:** prepared for review; not executed  
**Repository:** `gfa437926-tech/metra-weather-intelligence2026`  
**Date:** 2026-11-10

## Safety boundary

This plan is for an isolated staging environment belonging only to the new METRA project. It must not connect to, read from, write to, or migrate the legacy database or legacy repository. No production credentials belong in CI logs, test fixtures, screenshots, or this document.

Do not apply SQL or change hosted Supabase state as part of preparing this plan. Before execution, obtain explicit approval for the target staging project, test identities, test station records, and any test data writes.

## Entry criteria

- A staging Supabase project is explicitly identified and confirmed to be the new independent project.
- Staging URL and publishable key are supplied through protected environment secrets; service-role secrets remain server-side only.
- The deployed Edge Functions correspond to a reviewed commit and use least-privilege runtime credentials.
- At least two distinct test reviewer identities exist for workflows that require separation of duties.
- Test stations are clearly marked as synthetic/demo and cannot be mistaken for operational stations.
- An approved cleanup procedure is documented for synthetic records only.
- The app's production build is not pointed at staging or production by accident.

## Acceptance scenarios

| ID | Area | Scenario | Expected result |
|---|---|---|---|
| AUTH-01 | Authentication | Sign in with valid staging account | Session established; user enters only the permitted app state |
| AUTH-02 | Account gate | Pending, inactive, or blocked account attempts entry | Access denied; no station or observation data exposed |
| AUTH-03 | Session | Expired/revoked session calls a protected Edge Function | Request rejected; app returns to safe signed-out state |
| REG-01 | Registration | Submit a valid request for an approved active demo station | One request created; duplicate retry is idempotent |
| REG-02 | Registration | Submit against pending, rejected, inactive, or unverified station | Request rejected with safe actionable error |
| REG-03 | Registration review | Unauthorized reviewer attempts first-stage decision | Forbidden; no state or audit mutation |
| REG-04 | Registration review | Same actor attempts both stages where separation is required | Second stage rejected |
| REG-05 | Registration review | Two eligible distinct reviewers complete the workflow | Expected state transition and audit events recorded |
| STA-01 | Station directory | User requests station list without directory permission | Forbidden; no station data returned |
| STA-02 | Station isolation | User assigned to station A requests station B's restricted records | No cross-station data returned |
| STA-03 | Station review | Reviewer submits stale expected status | Conflict returned; no overwrite |
| STA-04 | Station review | Reviewer attempts to approve a demo station | Rejected or explicitly constrained by reviewed policy |
| OBS-01 | Observation | Assigned observer submits valid station observation | Submission stored for assigned station only |
| OBS-02 | Observation | Observer submits malformed/out-of-range payload | Validation error; no partial write |
| OBS-03 | Observation | Observer attempts review/approval | Forbidden |
| OBS-04 | Observation review | Authorized station reviewer approves or returns submitted report | Correct transition and immutable audit event |
| OBS-05 | Observation isolation | Reviewer from station A accesses station B observation | Not found/forbidden without leaking record existence |
| AUD-01 | Audit | Attempt to update/delete an audit event through client-facing routes | Denied |
| MAP-01 | Map | Station has missing or invalid coordinates | No fabricated pin; station remains discoverable in list |
| MAP-02 | Map | Multiple stations share coordinates | Cluster/overlap handling preserves access to each station |
| NET-01 | Resilience | Edge Function/network timeout during submission | Clear retry path; no duplicate submission |
| WEB-01 | Web | Run the staging app in supported Chromium browsers | No blocking console errors; core flows pass |
| MOB-01 | Mobile | Build and exercise Android and iOS | Auth, map, RTL layout, lifecycle, and network recovery pass on real test devices |

## Evidence to capture

For each scenario record:
- test ID, UTC timestamp, build commit, environment identifier (never secrets);
- actor role and synthetic station identifier;
- request/response status and sanitized error code;
- before/after state and audit-event identifiers where applicable;
- screenshot or short recording for UI and responsive behavior;
- pass/fail, defect reference, and retest result.

Never capture access tokens, passwords, service-role keys, personal data, or full sensitive payloads.

## Stop conditions

Stop the test immediately if:
- the environment resolves to the legacy or production project;
- any test identity can access another station's protected data;
- an unauthorized actor can approve registrations, stations, or observations;
- an audit event can be altered or deleted;
- test writes appear outside clearly identified synthetic records;
- a workflow reports success despite a failed or rolled-back transaction.

## Exit criteria

- All critical AUTH, REG, STA, OBS, and AUD scenarios pass.
- No unresolved cross-station access or privilege-escalation defect remains.
- Web browser tests pass and Android/iOS device tests are recorded separately.
- Security review signs off origin policy, secrets handling, rate controls, session lifecycle, and audit visibility.
- Test data cleanup is verified without touching non-synthetic records.

## Current execution status

This document is a test plan only. No staging credentials were supplied in this continuation, no hosted database was queried or modified, and no end-to-end scenario was executed.
