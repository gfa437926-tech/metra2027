# Stage C3 — Remaining Work and Dependencies

| Item | Classification |
|------|----------------|
| .NET domain/API unit tests (253) | **مكتمل** locally |
| Security headers | **مكتمل** |
| Grant uniqueness isolated SQL + CI job definition | **مكتمل محلياً ويحتاج CI** after push |
| Path N / archive isolation CI jobs | **مكتمل محلياً ويحتاج CI** |
| R4 production RPC on hosted | **يحتاج موافقة على قاعدة مستضافة** |
| Unique indexes on hosted | **يحتاج موافقة على قاعدة مستضافة** |
| Archive endpoint real data path | **مؤجل بسبب قيد أمني** (stays 503) |
| Flutter mock removal / live API bind | **مؤجل** / out of scope |
| Angular | **خارج النطاق** |
| Branch push + Draft PR | **يحتاج موافقة** |
| OpenAPI full per-endpoint examples for every route | **غير منفذ بالكامل** (inventory started) |
| Rate limiting | **غير منفذ** (document gap; needs product thresholds) |
| Dedicated concurrency stress beyond SQL unique probe | **جزئي** |
| Path H hosted upgrade rehearsal on real staging | **يحتاج موافقة مستضافة** |
| METRA OLD | **ممنوع** |

### Hosted gate checklist (not started)
1. Explicit approval  
2. Backup  
3. `01_precheck.sql`  
4. Manual duplicate active grant resolution  
5. Apply R4 then unique indexes  
6. Postcheck + smoke  
7. Rollback scripts ready  
