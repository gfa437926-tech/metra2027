# METRA 2027 — Supabase Read-Only Schema Review

Inspection date: 2026-11-02
Project: metra2027-angular
Project reference: tbdnklyxjvbrilvnwgmq
Project URL: https://tbdnklyxjvbrilvnwgmq.supabase.co
Database engine: PostgreSQL 17.11
Project status at inspection: ACTIVE_HEALTHY

## Scope and safety

This review used read-only project metadata, table catalogue, migration listing, extension listing, SQL catalogue queries, and Supabase security/performance advisors. No DDL, DML, Auth settings, API key, signing key, or RLS policy was changed.

## Findings

1. The public schema has no application tables, views, or materialized views at inspection time.
2. The Supabase migration listing returned no application migrations.
3. The managed Auth schema is present, including users, identities, sessions, MFA, recovery, and audit-related system relations.
4. The Auth users relation reported zero rows at inspection time.
5. The project includes standard managed schemas such as auth, realtime, storage, extensions, and vault. These are platform-owned; METRA must not modify their internal tables.
6. Supabase security advisor returned no lint notices.
7. Supabase performance advisor returned no lint notices.

The absence of public application tables means there is currently no METRA profile, registration request, role, permission, station assignment, or application audit schema in this project. This is a read-only finding, not authorization to create those objects.

## Implications for the identity recommendation

Supabase Auth is the recommended credential and identity provider because its managed Auth subsystem already exists in the selected project. It does not replace the missing METRA application domain model.

ASP.NET Core 10 must remain the authority for:
- METRA user/profile linkage;
- registration requests and their two approval stages;
- account lifecycle state;
- role grants and permission definitions;
- station master and station assignments;
- application audit history.

The Auth user ID/subject must be linked to a METRA account through an explicit, unique, server-controlled mapping. Email must not be used as the durable identity key.

## Required next review before any schema proposal

- Inspect Auth provider enablement, email/phone confirmation, redirect allow-list, MFA settings, password policy, session lifetime, and rate limits.
- Inspect JWT signing algorithm and current/standby/revoked public-key metadata. Do not retrieve or expose private key material.
- Confirm the authoritative station catalogue source and the final Arabic role catalogue.
- Review proposed entity relationships, uniqueness rules, indexes, retention requirements, and transaction boundaries.
- Design RLS for each actual access pattern; do not add broad authenticated-user policies.
- Prepare a migration proposal and present the complete SQL plus rollback/data-preservation plan for explicit approval.

## Explicitly not performed

- No tables, columns, constraints, indexes, triggers, functions, views, policies, or schemas were created or changed.
- No user, registration, station, role, or permission data was inserted, updated, or deleted.
- No Supabase Auth provider, email, MFA, session, or JWT setting was changed.
- No key rotation or credential generation was performed.
