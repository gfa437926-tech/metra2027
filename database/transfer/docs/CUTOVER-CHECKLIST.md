# Cutover checklist — experimental `tbdnklyxjvbrilvnwgmq` → new project

## Before any target write

- [ ] Source ref confirmed: `tbdnklyxjvbrilvnwgmq`
- [ ] Target ref assigned by owner (different from source)
- [ ] Source backup artifact retained offline (`01_export_source.sh` output)
- [ ] Restore drill performed into a throwaway DB or local Postgres
- [ ] Legacy METRA databases not used

## Target project bootstrap

- [ ] New Supabase project created under the intended org/account
- [ ] Auth site URL + redirect URLs configured for staging/prod apps
- [ ] New `anon` and `service_role` keys stored only in target secrets
- [ ] Backend env: `Supabase__Url`, `Supabase__ServiceRoleKey` = **target**
- [ ] Flutter defines: `METRA_SUPABASE_URL`, publishable key = **target**

## Data / schema

- [ ] Schema import completed without error
- [ ] Public data import completed
- [ ] Auth users path completed (see AUTH-USER-TRANSFER.md)
- [ ] Row-count compare within agreed tolerance
- [ ] Critical RPCs present: submit/decide observation; atomic read set if approved
- [ ] RLS policies present; client roles cannot read protected tables anonymously

## Application verification

- [ ] `/api/v1/health` OK on staging API
- [ ] `/api/v1/ready` behavior understood (may 503 until atomic RPCs exist)
- [ ] Login + station directory for a test user
- [ ] Archive remains fail-closed until RPCs + grants exist — do not fake data
- [ ] Observation submit stays gated until scientific/atomic contract is signed off

## Source project retention

- [ ] Source **not** deleted
- [ ] Source backup verified restorable
- [ ] Owner explicit approval required before any source teardown
