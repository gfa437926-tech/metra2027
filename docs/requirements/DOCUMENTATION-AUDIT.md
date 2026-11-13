# Documentation inventory and consistency audit

Baseline: `main` commit `87f71356083843b2abdef76baf011a82510686be` (2026-11-11).

## Findings

The requested entry-point documents were not present at the requested paths on the audited baseline:

- `واجهات/مهما.md`
- `واجهات/تغيير.md`
- `واجهات/README.md`
- `docs/requirements/METRA-2027-COMPLETE-PAGE-AND-TEST-SPECIFICATION.md`
- `docs/METRA-2027-COMPLETE-PROJECT-SPECIFICATION.md`

This branch creates these paths as governance/index documents. They are newly established records, not recovered copies of missing historical documents.

## Existing documentation inventory

| Path | Subject | Assessment |
|---|---|---|
| `README.md` | Repository overview, setup, deployment and verification | Current top-level entry point; states production integration is incomplete |
| `docs/architecture/README.md` | Architecture responsibilities, rules and delivery stages | Primary architecture baseline; preserve |
| `docs/architecture/WORKFLOW-INVENTORY.md` | Initial legacy workflow inventory | Explicitly preliminary; not full requirements |
| `docs/architecture/LEGACY-AUDIT.md` | Legacy overlap and risk inventory | Historical audit; do not delete |
| `docs/api/operational-observation-submission.md` | Observation submission contract | Explicitly limits implemented workflow; review/list/detail follow-up noted |
| `docs/api/authority-access.md` | Authority membership and permission contracts | Detailed contract; verify against live endpoint and migration versions |
| `docs/security/role-permission-matrix.md` | Role-to-permission policy | Policy evidence; not proof every UI action is complete |
| `docs/deployment/MULTI-ENVIRONMENT-HOSTING.md` | Environment and hosting runbook | Deployment plan, not deployment proof |
| `docs/data-quality/station-coordinate-audit.md` | Station coordinate completeness | Data-quality audit; coordinates require verification |
| `docs/form-label-mapping-*.md` | Legacy form-label mappings | Supporting mapping documents; check coverage against every form |

## Duplication and conflict risks

1. Legacy root contains numerous independent HTML/JS/CSS screens while Angular is the current web client. Treat legacy pages as reference evidence, not competing current implementation.
2. Multiple documents describe authority/registration/permission lifecycle at different levels. The role-permission matrix is policy; API documents are contract; migrations are executable database evidence. They must not be collapsed into one source or assumed synchronized without comparison.
3. The initial workflow inventory explicitly says rainfall, climate-hourly, phenomena, maintenance, calculation definitions, and complete field validation are not certified. New route names do not close those gaps.
4. Top-level README records successful CI runs dated 2026-11-04 and a Pages deployment blocked by an empty `METRA_API_BASE_URL` secret. These are dated evidence and must be refreshed before a release claim.
5. README describes independent Angular, Flutter and API lifecycles; architecture README defines the API as sole privileged backend. Client direct database access would conflict with that boundary.
6. Time-related statements must be reconciled under the UTC-only policy. Any local-time display or conversion described in older material is superseded for new requirements unless the product owner explicitly changes the policy.

## Governance rules

- Keep historical audit and decision records; supersede them with dated addenda rather than deleting them.
- Every requirement receives a stable ID in `TRACEABILITY-MATRIX.md`.
- A requirement cannot be marked complete without implementation evidence and appropriate tests; production claims additionally require environment-level verification.
- Each API contract must reference its owning capability, route, authorization permission, persistence object/migration and tests.
- Record unresolved choices as open decisions with an owner role and required evidence; do not silently infer.
- Arabic UI labels are user-facing canonical terms; English identifiers remain stable technical names. Maintain a glossary when either changes.

## Immediate documentation gaps

- Complete signed-off page inventory and acceptance criteria.
- Full field/unit/range/requiredness catalogue per observation type.
- One-to-one route/API/database/test mapping for every feature.
- Flutter parity decision per page.
- Paper record and mechanical recorder audit specification.
- Climatol/R processing contract and reproducibility controls.
- Forecast-centre data source, freshness, geospatial comparison and API contract.
- UTC conformance tests and explicit display rule.
- Release readiness checklist tied to live deployment evidence.
