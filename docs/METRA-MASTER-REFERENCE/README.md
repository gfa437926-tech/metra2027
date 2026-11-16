# METRA Master Reference v3 — مواصفات تنفيذية

**Branch:** `docs/metra-master-reference-v3-2026-11-15`  
**Based on:** PR #51 / `docs/metra-master-reference-v2-2026-11-15`  
**Repos:** this file

## Integrity
- Labels: **proven** vs **proposed** vs **needs scientific/admin approval**
- No invented WMO codes or scientific limits beyond JS-extracted values (still need formal adoption)
- No DB migrations, no secrets, no merge of #49/#50/#51

## v3 additions
| Area | Deliverable |
|---|---|
| Fields | 174 records, per-form tables, COMPLETE-FIELD-CATALOG-174.md |
| Forms | 9 form specs linked to field tables |
| Flutter screens | 16 files under screens/ |
| API | api/ENDPOINTS-INVENTORY.md from Metra.Api Map* |
| Roles | roles/ROLES-AND-PERMISSIONS-MATRIX.md |
| Workflows | workflows/CORE-WORKFLOWS.md (+ mermaid) |
| CLIMATOL | climatol/CLIMATOL-SPEC.md (NOT in legacy code) |
| AI/Records | ai/AI-AND-RECORDS-SPEC.md |
| Database | database/LOGICAL-DATA-MODEL.md (spec only) |
| Testing | testing/TEST-MATRIX.md |

## Proven counts
- 174 fields / 9 forms (re-extracted from metra-old HTML)
- 15 hourly numeric bounds from enhanced-validation.js
- Daily comparison bounds in daily_validation.js
- Agri temperature message -20..60
- Backend endpoints from C# sources; Flutter client methods aligned

## Explicitly incomplete
- English UI labels for fields (absent in legacy HTML)
- Full Field ID binding of every daily validate* line
- Runtime CI execution of all tests in this job
- CLIMATOL algorithm selection; live OCR/AI; archive (503)
