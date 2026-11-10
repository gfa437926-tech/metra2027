# METRA R / Climatol Integration Architecture

**Status:** worker bootstrap committed on the isolated branch; not yet connected to ASP.NET Core or production data.

## Responsibility split

- ASP.NET Core remains the system boundary for identity, permissions, job authorization, audit events, and API contracts.
- The R worker owns scientific time-series processing through the CRAN climatol package.
- PostgreSQL remains the system of record; the R worker receives bounded, staged input files and writes derived artifacts only.
- Angular is the review and analysis workstation. Flutter is not a scientific calibration workstation in this phase.

## Implemented worker slice

Location: services/climate-analytics-r

- R package with request validation.
- Workspace-root containment checks, including canonicalized input file paths.
- Required Climatol .dat / .est pair validation.
- Input staging into a unique job directory.
- Climatol homogen() invocation with UTC time-zone configuration.
- Artifact inventory returned to the caller.
- Unit tests using an injected runner.
- GitHub Actions package-check workflow.

The worker has no HTTP listener, database connection, credentials, or automatic publication behavior.

## Climatol input contract

The documented input pair is named VRB_YEAR-YEAR.dat and VRB_YEAR-YEAR.est. The .dat file is a blank-separated chronological matrix with station series arranged station-by-station. The .est file contains longitude, latitude, elevation, station code, and station name.

METRA must not generate these files until the authoritative mapping is approved for:
- variable identifiers and units;
- daily/monthly/sub-daily temporal resolution;
- missing and accumulated-precipitation codes;
- station coordinates, elevation, identifiers, and validity periods;
- quality flags and station history;
- completeness requirements and selected reference period.

No station metadata or observations are embedded in this worker.

## Job lifecycle

1. .NET authorizes the user and validates the requested station/variable scope.
2. A controlled export adapter creates a versioned immutable input package.
3. The worker validates paths and input file presence.
4. The worker copies inputs into an isolated per-job directory.
5. Climatol executes there; original input files remain untouched.
6. Outputs are quarantined as derived artifacts.
7. A reviewer inspects breakpoints, outliers, diagnostic plots, and resulting series.
8. Only a separately authorized approval process can publish a derived climate series.

## Operational controls required before integration

- private network boundary and authenticated .NET-to-worker calls;
- per-job CPU, memory, disk, and wall-clock limits;
- cancellation and cleanup policy;
- immutable job and artifact hashes;
- audit events for submission, execution, review, approval, and rejection;
- concurrency limits and retry/idempotency policy;
- no direct worker credentials for Supabase or production PostgreSQL;
- independent scientific review and documented method/version metadata.

## References

- CRAN: https://cran.r-project.org/web/packages/climatol/
- Climatol project and user guides: https://www.climatol.eu/
