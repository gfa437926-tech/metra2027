# METRA Climate Analytics — R worker

**Status:** isolated worker bootstrap with reproducible run provenance; not connected to ASP.NET Core, production observations, database storage, Angular, or Flutter.

## Scope implemented

- Validates the Climatol job request, workspace containment, and matching non-empty .dat/.est pair.
- Copies inputs to a unique job directory and verifies SHA-256 equality before execution.
- Invokes `climatol::homogen()` with UTC, graphics, verbose logging, and the package's documented defaults.
- Writes `metra-provenance.json` with request, UTC start/end times, R/package versions, effective Climatol formal defaults, input/output SHA-256 hashes, source-integrity result, and completion/failure state.
- Retains failed-job provenance for diagnosis; original input files are checked after execution.
- Includes unit tests using an injected runner. These test orchestration and integrity, not scientific validity.

## Job input contract

The request contains `variable`, `start_year`, `end_year`, `input_dir`, and `output_dir`. The input directory must contain `VRB_YEAR-YEAR.dat` and the matching `.est` file.

Climatol documents .dat as the time-series matrix and .est as station longitude, latitude, elevation, code, and name. METRA's export mapping, units, frequency, missing-value codes, station metadata, station histories, and study period must be approved before production data can be exported.

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
2. Add representative synthetic fixtures and a pinned, reproducible container/toolchain.
3. Review Climatol parameters separately for each variable and temporal resolution.
4. Add authenticated, private .NET orchestration with process/resource limits, cancellation, idempotency, and audit.
5. Add quarantined artifact storage and reviewer comparison/approval workflow.
6. Validate on an independently curated reference dataset before scientific acceptance.

## References

- https://cran.r-project.org/web/packages/climatol/
- https://www.climatol.eu/
