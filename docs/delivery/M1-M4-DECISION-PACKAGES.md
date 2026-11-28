# METRA 2027 — Decision packages M1–M4 (approval required)

**Status:** Documentation only. **No SQL / migration / RLS / RPC / .NET change applied.**  
**Owner action required:** Approve or reject each package independently.

Related prior docs: `docs/api-contracts/U1-DB-CHANGE-REQUIRED.md`, `SEVEN-FORMS-APPROVAL-DECISIONS.md`.

---

## M1 — Expand observation_type allow-list for rainfall + soil

### Problem
`metra_observations.observation_type` CHECK and `metra_submit_observation` only allow `daily|hourly|phenomenon`. Rainfall/soil Flutter forms cannot persist.

### Desired behavior
Server accepts `rainfall` and `soil` on the same operational submit/review path after validation.

### Affected objects
- Table `public.metra_observations` CHECK on `observation_type`
- Function `public.metra_submit_observation` type guard
- Optional later: validators in .NET for payload shapes

### RLS / permissions
No new permission codes required if `observation.create` / review codes remain.

### .NET impact
Allow-list in domain validators / request guards must include new types (M3 overlap).

### Flutter impact
Switch catalog rainfall/soil from `LocalCatalogObservationRepository` to shared submit flow after M1+M3+M4.

### Migration test plan
1. Insert daily still succeeds.  
2. Insert rainfall succeeds with valid payload.  
3. Insert unknown type still fails.  
4. Review decide works on rainfall rows.

### Compatibility risks
Existing clients assuming only three types must tolerate new values in queues.

### Rollback
Restore prior CHECK and RPC body; reject new types again.

### Decision
- [ ] Approve M1  
- [ ] Reject M1  
- [ ] Defer  

---

## M2 — Audit event_type / audit structure changes

### Problem
If catalog or fault forms need distinct audit event taxonomy, current audit may be insufficient.

### Desired behavior
Only change if product requires new event types beyond current observation audit.

### Default recommendation
**Defer** unless a concrete missing audit query is identified. Prefer reusing existing observation audit for rainfall/soil after M1.

### Decision
- [ ] Approve scoped M2 (list exact event types)  
- [ ] Reject / defer M2  

---

## M3 — .NET guards and validators for expanded types

### Problem
Even with DB allow-list, API may reject rainfall/soil at validation layer.

### Desired behavior
Domain validators + request guards accept approved payload schemas for new types; reject invalid payloads fail-closed.

### Depends on
M1 (or coordinated same release).

### Decision
- [ ] Approve M3 with attached JSON schemas  
- [ ] Reject / defer  

---

## M4 — Server persistence path for catalog forms in Flutter

### Problem
Flutter intentionally blocks server submit for catalog forms until contracts exist.

### Desired behavior
After M1+M3, enable submit for approved types only; keep others local.

### Flutter scope
Wire rainfall/soil first (U1). Agricultural / hourlyclimate / faults remain deferred per D1–D7 decisions unless separately approved.

### Decision
- [ ] Approve M4 for rainfall+soil only  
- [ ] Approve broader form set (list codes)  
- [ ] Reject / defer  

---

## Explicit non-goals under these packages
- No modification of legacy DB outside metra operational schema without separate approval.
- No inventing notification / CLIMATOL / AI / OCR / report-export APIs.
- No automatic merge of any PR.
