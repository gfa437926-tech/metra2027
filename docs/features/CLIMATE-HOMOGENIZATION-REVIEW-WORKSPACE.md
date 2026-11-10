# Climate Homogenization Review Workspace — UI/API Specification

**Status:** analysis specification only. No Angular or Flutter code is changed by this document.

## Purpose

Provide a human review workspace for Climatol outputs. A run is a scientific candidate, not an automatic approval. Raw observations, quality-controlled observations, and homogenized/filled outputs must remain separate, clearly labeled series.

## Review workspace layout

### 1. Run header and provenance

Display:
- immutable job ID and lifecycle status (queued/running/completed/failed/review-required/approved/rejected);
- variable code and human-readable unit label from the approved catalogue;
- temporal resolution and UTC period;
- station-network/catalogue version and station count;
- R, metraClimate, and climatol versions;
- selected method and all effective parameters (including defaults);
- input package SHA-256, output artifact hashes, start/end UTC timestamps;
- reviewer, review timestamp, decision, and rationale once supplied.

Never display a missing unit, threshold, or reference period as an assumed value. Show “not approved / not configured” explicitly.

### 2. Time-series comparison

Provide synchronized charts with separate selectable layers:
- raw source series (immutable);
- quality-controlled series (if an independently versioned QC stage exists);
- homogenized/adjusted series;
- filled estimates, visually distinct from observed and adjusted observations;
- adjustment delta (derived minus raw) as a separate panel.

Allow station selection, date-range zoom, variable/station metadata display, and exact UTC timestamp inspection. Do not interpolate or smooth the displayed data unless the visualization explicitly identifies that transformation.

### 3. Breakpoint review

Show candidate breakpoints in a table and on the chart:
- station code and UTC date/time;
- candidate breakpoint statistic and value exactly as emitted by the algorithm;
- selected reference-series context, where supplied by Climatol;
- station-history events near the candidate date, without automatically asserting causality;
- diagnostic artifact link and reviewer annotation.

A breakpoint is a statistical candidate, not proof of a non-climatic discontinuity. The UI must not auto-label a station move or instrument change as the cause unless supported by approved station-history evidence.

### 4. Outlier and QC review

Display the Climatol outlier report separately from breakpoint findings:
- source value and candidate classification as emitted;
- whether the value was flagged as suspect or removed/corrected by the selected run;
- corresponding adjusted/fill value, if present;
- reason/diagnostic reference and reviewer decision.

Do not silently delete or rewrite raw values. Preserve the algorithm's classification wording and distinguish “suspect” from “probable error” where the output provides that distinction.

### 5. Station context

Provide station catalogue details and validity-dated history:
- code, name, longitude, latitude, elevation, coordinate reference metadata;
- valid-from/to dates for each metadata revision;
- relocation, instrument, screen/exposure, observation practice, and site changes when documented;
- source and approval status of each history event.

Missing history must be shown as unknown, not interpreted as “no station changes”.

### 6. Diagnostics and artifact viewer

List and preview available artifacts from the run:
- Climatol text log;
- corrected-outlier CSV;
- corrected-break CSV;
- diagnostic PDF;
- R result object and any exported series;
- provenance manifest.

The CRAN Climatol manual documents these output types. The artifact list must be discovered from the actual run, not hard-coded as guaranteed files.

### 7. Review decision

Provide explicit actions:
- accept as scientifically reviewed derived product;
- reject;
- request rerun with a documented parameter change;
- request station metadata correction (without changing historical observations).

Every decision requires reviewer identity, UTC timestamp, rationale, and references to the exact run/artifact hashes. Approval does not overwrite raw observations. Publication is a separate, permission-checked operation.

## Proposed API resource shapes (not implemented)

- `POST /api/climate-homogenization/jobs`: submit a validated immutable input package reference and an approved parameter-profile identifier.
- `GET /api/climate-homogenization/jobs/{jobId}`: lifecycle and provenance summary.
- `GET /api/climate-homogenization/jobs/{jobId}/artifacts`: allow-listed artifact metadata and authorized download links.
- `GET /api/climate-homogenization/jobs/{jobId}/comparison`: raw/derived series references and aligned values/flags.
- `POST /api/climate-homogenization/jobs/{jobId}/reviews`: append-only human review decision.
- `POST /api/climate-homogenization/jobs/{jobId}/publication-requests`: separately authorized request to publish an approved derived product.

These routes are proposals only. ASP.NET Core owns authentication, authorization, input validation, audit, rate/resource controls, and artifact access. The R worker must not be directly exposed to browsers or accept arbitrary R expressions.

## Scientific acceptance gates

Before implementation can show “approved”:
- the variable/frequency-specific Climatol profile is approved;
- source-to-Climatol mapping and units are approved;
- station history and reference network are reviewable;
- completeness/missing-value rules are approved;
- independent validation and acceptance criteria are documented;
- a climate-science reviewer signs off.

## Climatol output semantics

The CRAN manual describes `homogen()` outputs including a text log, outlier list, breakpoint list, diagnostic PDF, and R binary result. It also documents `dahstat(stat="series")` flags: 0 for original, 1 for infilled, and 2 for corrected values. The interface should preserve and label these flags rather than infer new categories.

## References

- https://cran.r-project.org/web/packages/climatol/refman/climatol.html
- https://www.climatol.eu/
