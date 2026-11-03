# METRA Legacy Supabase — Read-Only Schema and Security Review

Inspection date: 2026-11-02  
Legacy project: `INSERT`  
Project reference: `vktcvkwqszehgmhqjrkb`  
Region: `us-east-1`  
PostgreSQL: `17.6.1.036`  
Project status: `ACTIVE_HEALTHY`

New METRA 2027 target: `metra2027-angular` (`tbdnklyxjvbrilvnwgmq`, `eu-west-2`, PostgreSQL 17.11). The target remains separate and its `public` schema had no application tables at the latest read-only verification.

## 1. Scope and safety

This review used Supabase project metadata, table and column catalogues, migration history, read-only SELECT/count queries, and Supabase security/performance advisors.

No DDL, DML, RLS, grants, views, functions, Auth settings, keys, users or stored records were changed. No passwords, password hashes, access tokens, refresh tokens or other credential values were queried.

**Preservation rule:** the `INSERT` project remains the legacy source of classic METRA data. Do not migrate, rename, delete, alter, disable, or otherwise modify it as part of this review.

## 2. Observed legacy schema

- 24 base tables exist in `public`.
- 22 of the 24 public tables have RLS disabled.
- The two FieldClimate tables, `fieldclimate` and `fieldclimate_stations`, report RLS enabled.
- The project has separate classic-station and FieldClimate station/readings objects.
- The project migration history includes the FieldClimate tables, FieldClimate read-only views, classic public read views, and classic latest-hourly views.

The legacy schema is not a clean canonical model. It contains mixed identifier types, text-encoded scientific measurements, free-text station/user fields, legacy credential columns and inconsistent timestamps. Preserve source values for audit/reconciliation; do not copy the old schema one-for-one into the new METRA model.

## 3. Station catalogue evidence

Read-only counts:

| Source | Stations | With coordinates | Without coordinates | Type metadata |
|---|---:|---:|---:|---|
| `public.stations` (classic) | 29 | 17 | 12 | `station_type` is NULL for all 29 |
| `public.fieldclimate_stations` (automatic) | 33 | 33 | 0 | Automatic source is identifiable from the table |

Important conclusions:

- There are 62 source station records across the two source tables before deduplication or canonical crosswalk.
- The 29 classic station rows have legacy integer IDs. Preserve those as source identifiers; do not reuse them as new METRA canonical IDs.
- All 33 automatic stations have coordinates, but their names include Arabic and Latin variants and may overlap geographically or semantically with classic station names.
- Do not match classic and automatic stations by display name alone. Use authoritative station codes, coordinates, source metadata and owner-confirmed crosswalks.
- `الإدارة العامة` appears in the classic station table with no coordinates; it must not automatically be classified as a meteorological station. It may be an organizational scope.
- Missing classic coordinates must remain missing until an authoritative source supplies them. Do not invent coordinates or use approximate city centres.

## 4. Observed role and station labels in records

Distinct role values in `public.users` include:
- empty string;
- `رئيس الاتصالات`;
- `رئيس دائرة الشبكات`;
- `رئيس دائرة الورشات`;
- `رئيس محطة`;
- `راصد جوي`;
- `متنبئ جوي`;
- `مدقق`;
- `مدير النظام`;
- `مساعد متنبئ`.

Distinct role values in `public.registration_queue` include:
- `دائرة الشبكات`;
- `رئيس الاتصالات`;
- `رئيس الورشات`;
- `رئيس دائرة الشبكات`;
- `رئيس محطة`;
- `راصد جوي`;
- `مبرمج الدعم الفني`;
- `متنبئ جوي`;
- `متنبئ جوي ` (trailing whitespace observed);
- `متنبئ جوي راصد`;
- `متنبئ مكلف بالرصد`;
- `مدقق`;
- `مدير النظام`;
- `مدير مركز`;
- `مساعد متنبئ`.

This is materially broader than the six registration-form options and the ten legacy redirect-map labels. These are raw historical values, not approved canonical roles. No value should be silently merged, renamed or deactivated.

The station strings in `users` and `registration_queue` also include variants such as `دمشق`, `محطة دمشق`, `مطار دمشق`, `مطار دمشق الدولي`, `طرطوس الزراعي -عمريت`, `مركز طرطوس الزراعي`, and `الكريم` versus `حماه- الكريم`. A formal crosswalk is required.

## 5. Scientific record volume observed

Counts are a read-only snapshot from 2026-11-02:

| Legacy table | Rows |
|---|---:|
| `daily_reports` | 3,743 |
| `hourly_reports` | 31,949 |
| `climate_reports` | 1,413 |
| `agricultural_reports` | 176 |
| `soil_temperatures` | 797 |
| `rainfall_reports` | 0 |

Daily report period values include `06utc`, `18utc`, and `24h`, with inconsistent display strings for the 24-hour period. Monthly and annual reports were not identified as separate tables in the inspected public schema; determine whether they are calculated products, other report types, or missing source domains before physical modelling.

The canonical METRA model must preserve daily, hourly, monthly/annual, climate, rainfall, agricultural and soil-temperature workflows as distinct typed domains where their scientific meaning differs. Do not collapse them into an untyped JSON record.

## 6. Security advisor findings — legacy project only

Supabase security advisor reported the following at inspection time:

| Finding | Severity | Count |
|---|---|---:|
| RLS disabled in public schema | ERROR | 22 tables |
| Policies exist but RLS is disabled | ERROR | 11 tables |
| Security-definer views | ERROR | 11 views |
| Mutable function search_path | WARN | 32 functions |

The performance advisor also reported 35 sets of multiple permissive policies and one duplicate index.

These findings require a separate, carefully planned security remediation for the legacy project. Because existing clients, views and collectors may depend on its current behavior, this review does **not** enable RLS, revoke grants, change views/functions, or alter policies. Do not treat the presence of RLS policy definitions as protection while RLS itself is disabled.

## 7. Implications for METRA 2027

1. Keep `INSERT` as a read-only legacy source during target design and reconciliation.
2. Keep `metra2027-angular` as the separate target for the new .NET-backed METRA application; do not copy legacy tables directly.
3. Design a canonical station catalogue that represents classic and automatic stations together, but records station class, source system and source identifier separately.
4. Keep FieldClimate collector-specific ingestion storage separate where required; the METRA API should provide one normalized station/observation contract to Angular and Flutter.
5. Build a reviewed crosswalk for the 29 classic and 33 automatic source stations. Report duplicates, name aliases and missing coordinates; do not merge or drop records silently.
6. Reconcile raw role values from actual records before finalizing role codes and permission grants.
7. Define typed scientific models for the observed record domains and explicitly resolve monthly/annual report semantics.
8. Do not migrate legacy `password_hash`, `program_password`, session tokens or other credential material. Supabase Auth will own new credentials.
9. Prepare a source-to-target mapping and dry-run counts before any future migration. Obtain explicit approval before writing to the target.

## 8. Explicitly not performed

- No changes to the `INSERT` project.
- No changes to the `metra2027-angular` target.
- No data export or migration.
- No credential or personal-profile data query.
- No RLS/grant/policy/view/function remediation.
- No station matching, role normalization, or canonical ID assignment.
