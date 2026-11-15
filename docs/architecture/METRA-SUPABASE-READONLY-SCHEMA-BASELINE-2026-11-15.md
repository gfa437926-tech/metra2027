# METRA 2027 — Supabase read-only schema baseline

**Inspection date:** 2026-11-15  
**Project ref:** `tbdnklyxjvbrilvnwgmq`  
**Project name:** `metra2027-angular`  
**Region:** `eu-west-2`  
**Database:** PostgreSQL 17.11  
**Inspection mode:** read-only metadata/catalogue queries and Supabase advisors. No SQL writes, migrations, seeds, bucket changes, or Edge Function deployments were performed.

## 1. Executive findings

The project is **not an empty database**. It contains an established multi-schema METRA foundation and 86 recorded Supabase migrations. The earlier assumption that this project was empty is stale and must not be used to plan a fresh initial migration.

The application-owned schemas inspected contain 46 tables across 10 namespaces:

| Schema | Tables |
|---|---:|
| `catalog` | 7 |
| `iam` | 12 |
| `observations` | 6 |
| `operations` | 5 |
| `weather` | 6 |
| `alerts` | 3 |
| `audit` | 1 |
| `files` | 1 |
| `integration` | 2 |
| `ref` | 3 |
| **Total** | **46** |

There are no application tables in `public`; the domain model is organized in dedicated schemas. The project also has the Supabase-managed schemas (`auth`, `storage`, `realtime`, `vault`, etc.), which are not counted in the 46 application tables.

## 2. Current row-count snapshot

The following five application tables had rows at inspection time:

| Table | Rows |
|---|---:|
| `iam.roles` | 10 |
| `iam.permissions` | 27 |
| `iam.role_permissions` | 78 |
| `catalog.station_types` | 7 |
| `ref.observation_types` | 3 |

The other 41 application tables returned zero rows in the table metadata snapshot. In particular, `catalog.stations` had zero rows; this inspection did not seed or import station records. These counts are a point-in-time metadata snapshot, not a promise about future contents.

## 3. Migration history and source-control drift

- Supabase reports **86 applied migration records**.
- The inspected Git branch contains only **5 SQL files** under `supabase/migrations/`.
- The latest recorded Supabase migration is `20261114204951_met ra_api_runtime_privileges` (version `20261114204951`); the exact recorded name is `metra_api_runtime_privileges`.
- The repository's latest tracked migration is `20261103220500_harden_observation_decision_null_validation.sql`.

This is a material migration-history/source-control mismatch. A deployable, reproducible schema cannot be certified from the five tracked SQL files alone. Do not create a new baseline migration, reset the project, replay guessed SQL, or apply additional DDL until the 86-version history and live schema have been reconciled into a reviewed, reproducible source of truth.

## 4. Security metadata snapshot

- All 46 inspected application tables have Row Level Security enabled.
- The read-only privilege check found no `anon` or `authenticated` SELECT or INSERT table privilege on those 46 tables.
- Supabase Security Advisor reported 21 informational `rls_enabled_no_policy` findings. These tables have RLS enabled but no policies; at inspection time the checked client roles also lacked SELECT/INSERT grants. This is consistent with a server-mediated access design, but must be confirmed against Data API exposed schemas, the complete GRANT matrix (including UPDATE/DELETE), .NET runtime credentials, and RPC execute grants before production approval.
- No security advisor error-level finding was returned in this inspection. An informational advisor result is not a full penetration test or proof of correct authorization.
- The Performance Advisor reported 76 unused-index informational findings. With most operational tables empty and a recently built schema, these are not grounds for dropping indexes. Re-evaluate only after representative workload and query-plan evidence exists.

## 5. Current domain coverage and gaps

Existing application schemas cover:
- Identity, organizations, units, memberships, role assignments, permissions and registration workflow (`iam`).
- Station catalogue, identifiers, types, locations, operating periods and reviews (`catalog`).
- Observation submissions, values, revisions, review decisions, quality flags and attachments (`observations`).
- Equipment and support incident/fault workflows (`operations`).
- Weather providers, ingestion, forecast runs/points, mappings and payload references (`weather`).
- Alerts, audit, file metadata, integration runs and reference units/parameters (`alerts`, `audit`, `files`, `integration`, `ref`).

The inspected application schema does not yet include dedicated recorder capture/image/trace digitization tables, climate-series/homogeneity/adjustment tables, or AI dataset/experiment/model-registry tables. The existing ERD document is a logical proposal for these domains, not evidence that their physical tables are already deployed.

Five active Edge Functions were reported by the project inventory: `station-directory`, `registration`, `registration-approvals`, `observations`, and `station-review`; all reported `verify_jwt=true`. This inventory does not prove the functions are integrated into the intended .NET application path or that their internal authorization is correct.

## 6. Required reconciliation before further database work

1. Export/obtain the exact SQL source for all 86 recorded migrations and map each version to the Git history.
2. Compare the migration replay result against the live schema, constraints, indexes, triggers, functions, grants, RLS policies and exposed-schema settings.
3. Review the 21 no-policy findings and the complete privilege matrix, including UPDATE, DELETE and function EXECUTE.
4. Confirm the intended authority/tenant model, new station catalogue source, observation contracts and service-role boundary.
5. Review and approve the scientific ERD and column dictionary, including recorder, climate and AI domains.
6. Only then prepare migrations for a disposable empty PostgreSQL test database, replay all migrations, run cross-authority/station authorization tests and obtain explicit approval before any hosted schema write.

## 7. Safety boundary

This report is an observation-only baseline. It does not authorize:
- Any change to the legacy database.
- Any Supabase DDL, migration, seed, storage-bucket or policy change.
- Any use of the old station list or old operational data.
- Any production claim for recorder OCR, CLIMATOL, AI training, or mobile distribution.

The 86-migration reconciliation is now a release blocker because source control does not currently contain the complete applied history.
