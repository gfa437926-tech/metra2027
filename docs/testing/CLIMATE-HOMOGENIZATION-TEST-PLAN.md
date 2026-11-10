# Climate Homogenization Test Plan

**Status:** initial R worker unit tests added; scientific and integration tests pending.

## Current automated tests

- valid request resolves the matching .dat and .est files;
- directories outside the configured workspace are rejected;
- invalid variable identifiers and reversed year ranges are rejected;
- the runner receives UTC and runs against staged copies;\n- daily climatology monthly/yearly summaries use calendar-day completeness, preserve missingness, and reject duplicate station-date records;
- original source input files remain present after execution.

## Required next tests

### R package
- empty, missing, malformed, and oversized input files;
- symbolic-link path escape attempts;
- collisions and concurrent jobs;
- Climatol non-zero/error behavior and partial artifact output;
- cleanup and cancellation;
- deterministic package installation and R CMD check.

### Scientific
- approved fixture datasets with known metadata;
- station ordering and series alignment;
- missing periods and all-stations-missing time steps;
- variable-specific parameter review;
- diagnostic output review by climate scientists;
- independent reference data and documented acceptance criteria.

### Integration
- .NET authorization and service identity;
- bounded execution and cancellation;
- job idempotency and audit trail;
- artifact quarantine, hashes, and access control;
- Angular review and approval workflow;
- prevention of raw-series mutation.

No synthetic fixture is represented as real METRA observations.
