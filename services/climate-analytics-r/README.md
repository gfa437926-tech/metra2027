# METRA Climate Analytics — R worker

**Status:** isolated worker bootstrap with reproducible run provenance; not connected to ASP.NET Core, production observations, database storage, Angular, or Flutter.

## Scope implemented

- Validates the Climatol job request, workspace containment, and matching non-empty .dat/.est pair.
- Copies inputs to a unique job directory and verifies SHA-256 equality before execution.
- Invokes `climatol::homogen()` with UTC, graphics, verbose logging, and the package's documented defaults.
- Writes `metra-provenance.json` with request, UTC start/end times, R/package versions, effective Climatol formal defaults, input/output SHA-256 hashes, source-integrity result, and completion/failure state.
- Retains failed-job provenance for diagnosis; original input files are checked after execution.
- Uses an atomic workspace lock to reject overlapping jobs in the same R process/workspace because the current Climatol adapter changes the process working directory. The lock is released on normal R exit from the worker; after an abrupt process termination, an operator must confirm no worker remains before removing the stale `.metra-climatol-worker.lock` directory. This is serialized execution, not parallel-job support.
- Includes orchestration tests using an injected runner and an end-to-end smoke test against the CRAN Climatol `Temp.dat` / `Temp.est` demonstration dataset (monthly, five stations, 1961–2005). The fixture is package demonstration data, not METRA observations; the smoke test checks execution/provenance, not scientific validity.

## Job input contract

The request contains `variable`, `start_year`, `end_year`, `input_dir`, and `output_dir`. The input directory must contain `VRB_YEAR-YEAR.dat` and the matching `.est` file.

Climatol documents .dat as the time-series matrix and .est as station longitude, latitude, elevation, code, and name. METRA's export mapping, units, frequency, missing-value codes, station metadata, station histories, and study period must be approved before production data can be exported.

## Concurrency and lock recovery

The current adapter uses `setwd()` because Climatol writes outputs relative to the working directory. R documents `setwd()` as changing the working directory of the R process, so this adapter rejects overlapping jobs under one workspace rather than claiming safe concurrent execution. See the [R `getwd`/`setwd` reference](https://search.r-project.org/R/refmans/base/html/getwd.html). A stale lock after forced termination must be inspected and manually removed only after confirming the recorded PID is no longer running.

## Local checks

From this directory, with R and dependencies installed:

```sh
R CMD build .
R CMD INSTALL metraClimate_0.2.0.tar.gz
R -e 'testthat::test_dir("tests/testthat")'
```

## Scientific and safety boundaries

- No SQL, migrations, RLS, seeds, Supabase access, or database credentials.
- No public listener or .NET integration.
- No invented station data, units, thresholds, reference periods, or acceptance criteria.
- No automatic promotion of homogenized values to official observations.
- The generic daily summary helper is not a variable-specific climate-normal/index implementation.
- Homogenized series, filled values, detected outliers, and break adjustments remain derived outputs subject to human scientific review.

## Outstanding gates

1. Approve the METRA-to-Climatol export contract and station-history source.
2. Run the CRAN Climatol example-data smoke test in CI with Climatol 4.5-0 pinned; pin the remaining R/OS toolchain for full reproducibility.
3. Review Climatol parameters separately for each variable and temporal resolution.
4. Add authenticated, private .NET orchestration with process/resource limits, cancellation, idempotency, and audit.
5. Add quarantined artifact storage and reviewer comparison/approval workflow.
6. Validate on an independently curated reference dataset before scientific acceptance.

## References

- https://cran.r-project.org/web/packages/climatol/
- https://www.climatol.eu/


## Cancellation and timeout boundary

The R worker currently runs Climatol synchronously in the R process. Do not promise in-process cancellation for a running `climatol::homogen()` call. Before production integration, .NET must supervise a dedicated R process per job (or serialize a single worker), apply approved wall-clock and resource limits, and terminate the complete process tree on cancellation/timeout. Record job and process/container identity so stale-lock recovery can account for PID reuse and container PID namespaces. Preserve available worker provenance and separately record supervisor-forced termination if the worker cannot finish its manifest. Timeout values, grace periods, CPU/memory/disk ceilings, and retention are deployment policy decisions requiring approval; this repository does not invent them. Stale locks remain manual-review only; no automatic deletion is implemented.
