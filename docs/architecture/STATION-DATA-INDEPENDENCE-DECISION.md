# Station Data Independence Decision

Status: owner-directed architecture decision for METRA 2027.

## Decision

The new METRA 2027 operational station catalogue must be created independently. It must not depend on, query, join, synchronize from, or require availability of the historical station datasets.

Historical station data is to remain preserved as a ready, isolated copy for reference and possible future review. Preservation does not make it an operational source and does not authorize migration.

## Required separation

1. **New operational catalogue**
   - Has its own approved data model, identifiers, validation rules, ownership, and lifecycle.
   - Is populated only from newly approved station records and explicitly approved new data sources.
   - Must function when every legacy database/table/source is unavailable.
   - Must not infer station identity, names, types, coordinates, codes, or metadata from historical records.

2. **Historical ready copy**
   - Preserve the original historical datasets unchanged, including their original identifiers and values.
   - Keep the copy isolated from operational APIs, map layers, search, filters, reports, authorization decisions, and analytics.
   - Do not transform, normalize, merge, deduplicate, rename, geocode, or backfill the preserved copy as part of normal application operation.
   - Expose it, if ever needed, only through a separately authorized archive/reference workflow that is read-only by default.
   - Maintain independent backup, integrity verification, and documented restore procedures. A backup is not a live operational dependency.

3. **Future migration**
   - No automatic or bulk migration is authorized by this decision.
   - Any later import requires explicit owner approval, a reviewed field mapping, provenance, duplicate/identity review, coordinate verification, validation results, and an auditable import report.
   - Imported records become operational only after explicit approval; rejected and unreviewed records remain in the archive.

## Engineering consequences

- Remove legacy row counts and legacy schema observations from operational acceptance criteria. They may remain only in a clearly labelled historical archive inventory.
- Do not use the historical Classic/Automatic split as the required shape of the new catalogue. The new catalogue's station categories and types must be defined from the approved METRA 2027 requirements.
- The existing source-qualified Classic/Automatic projection and Angular preview are compatibility/prototype work only. They must not be wired to the new production catalogue or represented as the final station data model.
- The new API and map must read exclusively from the new operational catalogue.
- Tests must prove that the new catalogue can be queried and rendered with no legacy provider configured and no legacy data present.
- No Supabase schema, RLS, grants, data, or production settings are changed by this decision.

## Acceptance gates

- [ ] New operational station model and terminology approved independently of legacy schema.
- [ ] New station identifiers are generated/assigned under the new model; no legacy IDs are reused implicitly.
- [ ] New catalogue API has no legacy database/table/provider dependency.
- [ ] New catalogue UI and map consume only the new catalogue contract.
- [ ] Archive is isolated and read-only, and its unavailability does not affect operations.
- [ ] Automated tests verify operational catalogue behavior with legacy dependencies absent.
- [ ] Any future archive import is explicit, reviewed, permission-controlled, and auditable.

## Current implementation boundary

The existing Classic/Automatic catalogue contract, source-qualified detail routes, and coordinate-plane preview were developed against a historical source shape. Until redesigned against the independently approved METRA 2027 station model, they are not the production station catalogue and must remain disabled/unconfigured. This decision does not delete or alter any historical data.
