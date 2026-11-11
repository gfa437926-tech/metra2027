# METRA R / Climatol Integration Architecture

**Status:** isolated R worker bootstrap; not connected to ASP.NET Core or production data.

## Responsibility split

- ASP.NET Core is the system boundary for identity, permissions, job authorization, audit events, and API contracts.
- The R worker owns scientific time-series processing through CRAN's climatol package.
- The worker receives bounded, staged input files and writes derived artifacts only.
- Angular is the review and analysis workstation. Flutter is not a scientific calibration workstation in this phase.

## Implemented worker slice

Location: `services/climate-analytics-r`

- R package with request validation and workspace containment.
- Required Climatol .dat/.est input pair validation.
- Per-job staging directory and SHA-256 checks before/after execution.
- Climatol homogen() invocation with UTC timezone handling.
- Provenance JSON with request, timestamps, R/package versions, effective Climatol formal defaults, input/output hashes, and failure state.
- Unit tests with an injected runner and a GitHub Actions R CMD check.

The worker has no HTTP listener, database connection, credentials, or automatic publication behavior.

## Climatol input contract

The documented input pair is named VRB_YEAR-YEAR.dat and VRB_YEAR-YEAR.est. The .dat file contains the time series matrix; the .est file contains station longitude, latitude, elevation, station code, and station name.

METRA must not generate these files until the authoritative mapping is approved for:
- variable identifiers and units;
- daily/monthly/sub-daily temporal resolution;
- missing and accumulated-precipitation codes;
- station coordinates, elevation, identifiers, and validity periods;
- quality flags and station history;
- completeness requirements and selected reference period.

## Job lifecycle

1. .NET authorizes the user and validates station/variable scope.
2. A controlled export adapter creates a versioned immutable input package.
3. The worker validates paths and the required input pair.
4. The worker stages inputs and verifies SHA-256 equality.
5. Climatol executes only in the isolated job directory.
6. The worker records runtime, settings, input/output hashes, and status in a provenance manifest.
7. Outputs are quarantined as derived artifacts.
8. A reviewer inspects breakpoints, outliers, diagnostic plots, and resulting series.
9. Only a separately authorized approval process may publish a derived climate series.

## Operational controls required before integration

- private network boundary and authenticated .NET-to-worker identity;
- per-job CPU, memory, disk, and wall-clock limits;
- cancellation and cleanup policy;
- immutable job and artifact hashes;
- audit events for submission, execution, review, approval, and rejection;
- concurrency limits and retry/idempotency policy;
- no direct worker credentials for Supabase or production PostgreSQL;
- independent scientific review and documented method/version metadata.

## Scientific configuration

Climatol exposes method and quality-control parameters whose defaults and suitability depend on data frequency, variable, and station network. This worker records the installed package's formal defaults but does not assert that they are approved for METRA. Variable-specific parameter profiles require scientific sign-off.

## References

- CRAN package documentation: https://cran.r-project.org/web/packages/climatol/
- Climatol project and user guides: https://www.climatol.eu/
