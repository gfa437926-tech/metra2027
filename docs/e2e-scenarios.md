# METRA 2027 — E2E scenarios (staging)

These scenarios require a **staging** environment with test users and stations.
They are **not** executed in Client CI. Do not run against production data.

## Preconditions

- Staging API base URL configured (no production hosts).
- Test JWT users:
  - operator (submit only) assigned to Station A
  - reviewer (observation.review) assigned to Station A only
  - outsider assigned to Station B only
- Seeded empty observation queues for Stations A and B

## Scenarios

1. **Login session**
   - Sign in as operator → home loads with Station A selected.
2. **Hourly draft + submit**
   - Open ساعي · متصل → fill required fields → values persist as local draft → submit → success snackbar → draft cleared.
3. **Review queue visibility**
   - Sign in as reviewer → مراجعة · متصل → submitted hourly appears.
4. **Approve**
   - Approve → status leaves queue → 409 on second approve.
5. **Return for correction**
   - Submit another → return with note → operator can resubmit.
6. **IDOR isolation**
   - Outsider cannot list Station A queue (403) and cannot decide on Station A ids.
7. **Session expiry**
   - Expire token → next API call shows Arabic re-login message; no stack traces.

## Catalogue forms (local only)

Agricultural / hourly climate / rainfall / soil / equipment / telecom / IT:
local validation only until an approved API contract exists. E2E must assert
the amber banner and that no network write occurs.
