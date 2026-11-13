# C9.3 — PR Topology and Release Boundary

**Reviewed branch head:** `388de939afcd3a3f5e115ac2df1180c35feaca7c`  
**PR #36:** `work/backend-db-integration-full-2026-11-13` → `main`  
**PR #34:** `fix/flutter-client-ci-mainline-2026-11-11` → `main`  
**Decision:** PR #36 supersedes the current PR #34 branch history; neither PR is merged by this work.

## 1. Verified GitHub state

- `main` reviewed SHA: `6ff6f36a80106d19f4ba6b8bb8cf0316a911cc34`.
- PR #36 is open, non-draft, unmerged, and GitHub reports `mergeable=true`, `mergeable_state=clean`.
- PR #36 head: `388de939afcd3a3f5e115ac2df1180c35feaca7c`; 204 commits and 190 changed files at the latest metadata check.
- PR #34 is open, draft, and unmerged. Its head is `dd377081f7f211d3c15e5ca1db2cf8e551fda8e6`; 86 commits and 22 changed files.
- All 86 commits currently listed for PR #34 are also present in PR #36. PR #36 therefore contains the full PR #34 history plus subsequent work.
- PR #36 has no recorded review comments or approvals at this check.

## 2. CI evidence

### PR #36 exact head `388de939`

All six exact-head checks completed successfully:
- Backend build.
- Path N empty PostgreSQL schema build.
- Isolated PostgreSQL archive authorization.
- Isolated grant uniqueness.
- Flutter analyze/test (both configured client workflows).

This proves the checked CI suites passed on this commit. It does not prove hosted Supabase deployment, Staging identity-provider E2E, scientific-owner approval, or Production readiness.

### PR #34 exact head `dd377081`

- Angular build: success.
- Flutter analyze/test: failure in `forecast_centre_screen_test.dart`; the test expected exactly two coordinate-provenance labels but found one.
- The current PR #36 history includes later test changes and the exact-head Flutter CI passes above. PR #34 remains draft and should not be merged independently in its older failing state.

## 3. Consequence and safe sequencing

PR #36 is the superset branch. Merging PR #34 first is not recommended: it is still draft, its exact-head Flutter check failed, and all its commits are already included in PR #36.

Recommended owner review sequence:
1. Review PR #36 as the single candidate containing the combined history.
2. Complete the security, scientific-contract, and Staging gates described in the remaining-work reports.
3. If the owner approves PR #36, merge that PR only after the required checks are green on the exact merge candidate.
4. Close PR #34 as superseded only after confirming PR #36's merge and preserving the historical discussion.

No merge, PR close, base retarget, force-push, or deployment is performed automatically.

## 4. Change boundary

No hosted Supabase schema or data was changed, no legacy project was accessed, and no Staging project was created. The configured METRA Supabase project was inspected read-only.

## 5. Release decision

**PR #36 is CI-green at the reviewed head but is not Production Ready.** Mergeability is not security approval, scientific approval, Staging evidence, or deployment authorization.
