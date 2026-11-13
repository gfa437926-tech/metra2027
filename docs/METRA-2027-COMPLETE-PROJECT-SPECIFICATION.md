# METRA 2027 — Complete project specification (controlled index)

**Document state:** Initial controlled project baseline; detailed requirements remain incomplete and require owner sign-off.  
**Audit baseline:** 2026-11-11, main commit `87f71356083843b2abdef76baf011a82510686be`.

This path was absent on the audited baseline. This document is a new index and baseline, not a recovered historical specification.

## Product architecture evidenced

| Layer | Technology | Repository path | Responsibility |
|---|---|---|---|
| Web client | Angular 20 | `angular-app/` | Web presentation and client workflows |
| Mobile client | Flutter | `mobile/metra_mobile/` | Android/iOS client |
| Backend | ASP.NET Core 10 / C# | `backend/Metra.Api/` | Authentication integration, authorization, validation and privileged persistence |
| Data | Supabase/PostgreSQL | `supabase/migrations/`, `database/` | Durable data, constraints, RPCs and audit |

The architecture document establishes the API as the only privileged database boundary. Angular and Flutter must use the same versioned API and must not independently implement authoritative business rules.

## Product capability groups

1. Identity, registration, membership and station assignments.
2. Station catalogue, coordinates and data quality.
3. Daily and hourly observations.
4. Rainfall, climate, phenomena, agriculture and soil temperature.
5. Review, correction, approval, audit and archival.
6. Reports, statistics, monthly/annual calculations and exports.
7. Paper-register and mechanical-recorder verification.
8. Climate homogeneity using R and Climatol.
9. Forecast-centre station comparison and live meteorological values.
10. Administration, security, deployment and monitoring.

The presence of these groups in requirements or prior conversations does not establish implementation. See the traceability matrix for current repository evidence and gaps.

## Non-negotiable constraints

- UTC-only time semantics; no local-time workflow or conversion.
- The legacy database is out of scope and must remain unchanged.
- Do not apply schema changes or migrations without explicit schema review and approval.
- Keep the three application lifecycles independent while sharing API contracts.
- Never expose service-role credentials in client apps or source control.
- Preserve historical documents; use dated addenda and decision records.
- No direct merge to `main`; all work must be reviewed through PRs.

## Controlled supporting documents

- [Architecture](architecture/README.md)
- [Workflow inventory](architecture/WORKFLOW-INVENTORY.md)
- [Legacy audit](architecture/LEGACY-AUDIT.md)
- [Requirements traceability](requirements/TRACEABILITY-MATRIX.md)
- [Page and test specification](requirements/METRA-2027-COMPLETE-PAGE-AND-TEST-SPECIFICATION.md)
- [Documentation audit](requirements/DOCUMENTATION-AUDIT.md)
- [UTC decision](architecture/DECISION-LOG-UTC.md)
- [Assistant boundaries](architecture/ASSISTANT-BOUNDARIES.md)

## Open specification work

The complete field catalogue, page acceptance criteria, full role-permission mapping, report formula definitions, R/Climatol data contract, paper-audit evidence lifecycle, forecast-centre freshness/quality contract and production operational requirements remain to be signed off. The Requirements Traceability Matrix is the controlled status source.
