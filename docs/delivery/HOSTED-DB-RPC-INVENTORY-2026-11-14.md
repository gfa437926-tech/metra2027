# Hosted experimental DB RPC inventory

**Project ref:** `tbdnklyxjvbrilvnwgmq`  
**Source:** owner SQL Editor read-only (2026-11-14)  
**Filter:** public functions matching permission / archive / observation

## Functions present

| schema | function_name |
| --- | --- |
| public | decide_authority_permission_grant |
| public | get_authority_permission_options |
| public | metra_decide_observation |
| public | metra_submit_observation |
| public | metra_user_has_authority_permission |
| public | metra_user_has_station_owner_authority_permission |
| public | metra_user_has_station_permission |
| public | reject_metra_observation_audit_mutation |
| public | request_authority_permission_grant |
| public | revoke_authority_permission_grant |

## Interpretation

### Present and relevant

- **Station permission core:** `metra_user_has_station_permission` (R4 target; body not yet verified for ArchiveRead station bind).
- **Authority permission lifecycle:** request / decide / revoke + options catalogue.
- **Observation write path RPCs exist hosted:** `metra_submit_observation`, `metra_decide_observation`.
- **Audit immutability guard:** `reject_metra_observation_audit_mutation`.

### Not found under this filter

- No function name containing `archive`.
- Therefore **no evidence** of a deployed observation-archive read RPC on this project from this query.
- API archive endpoints should remain **fail-closed (503)** until an approved archive service/RPC exists and is tested.

### App gating vs hosted reality

| Capability | Hosted RPC | Flutter / API posture (repo) |
| --- | --- | --- |
| Permission checks | Yes | Used via backend/SQL policies |
| Authority grants | Yes | liveApi reads; writes via backend |
| Observation submit | **RPC exists** | Still **gated** in mobile until scientific contract + integration tests approved |
| Observation decide | **RPC exists** | Still **gated** |
| Archive read | **No RPC found** | mock / 503 fail-closed |

## Required follow-up (read-only SQL)

Verify R4 body and observation signatures without applying changes:

```sql
SELECT pg_get_functiondef(p.oid)
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'metra_user_has_station_permission';

SELECT pg_get_functiondef(p.oid)
FROM pg_proc p
JOIN pg_namespace n ON n.nspname = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN ('metra_submit_observation', 'metra_decide_observation');
```

(Fix join if needed: `n.oid = p.pronamespace`.)

## Constraints

- Inventory only; no hosted DDL/DML from this document.
- Do not treat RPC existence alone as production go-live for scientific observation paths.
