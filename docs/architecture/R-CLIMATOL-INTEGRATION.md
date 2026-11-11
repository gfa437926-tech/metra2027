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


## Process isolation, cancellation, and timeout contract

The current worker is not safe to host as concurrent calls inside a shared long-lived R process: Climatol execution changes process-wide working-directory state, and the workspace lock only serializes calls that share the same lock root. The preferred .NET integration model is therefore one supervised R process per job (or a strictly serialized single-worker service until process supervision exists), with a unique job workspace and no shared mutable working directory.

Cancellation and wall-clock timeout must be enforced by the external .NET supervisor, not by an in-process flag that cannot reliably interrupt a synchronous `climatol::homogen()` call. The supervisor contract must: record a job ID and process/container identity; stop accepting duplicate submissions for the same idempotency key; request graceful termination; after an approved grace period terminate the complete child-process tree; wait for process exit; preserve the worker's failed provenance when available; and mark supervisor-forced termination distinctly when the worker could not write its final manifest. Resource ceilings and timeout values are policy decisions and must be approved per deployment/job class rather than guessed here.

A lock left after forced termination is not proof that its PID is still active: process IDs can be reused and may be scoped to a container. Recovery must correlate the recorded PID with host/container identity and process start identity, verify that the owning process is gone, preserve an audit event, and only then allow an operator-controlled removal. No automatic stale-lock deletion is implemented or specified by this document. This is an architecture contract only; no .NET supervisor or cancellation implementation is claimed.
