# METRA Climate Analytics — R worker bootstrap

**Status:** first executable worker slice; not connected to ASP.NET Core, Angular, Flutter, Supabase, or production storage.

## Scope

- Validates a Climatol job request and the required .dat / .est input pair.
- Restricts input and output directories to METRA_CLIMATE_WORK_ROOT.
- Copies submitted inputs into a unique job directory before execution; Climatol never receives the source files as writable working files.
- Runs climatol::homogen() with UTC timezone handling and records generated artifact names.\n- Calculates daily-input monthly/yearly summaries only when the caller explicitly supplies the statistic and completeness threshold; missing values are not converted to zero.
- Includes unit tests with an injected runner; these do not claim scientific validation or model accuracy.

## Job JSON shape

    {
      "variable": "TX",
      "start_year": 1991,
      "end_year": 2000,
      "input_dir": "/workspace/input/example-job",
      "output_dir": "/workspace/output"
    }

This is a contract example, not METRA observation data. The input directory must contain {variable}_{start_year}-{end_year}.dat and the matching .est file.

Climatol documents .dat as a blank-separated time series matrix, station by station, and .est as station longitude, latitude, elevation, code, and name. The owner must approve the actual METRA export mapping, units, missing-value representation, and station metadata before operational jobs are enabled.

## Local checks

From this directory, with R and the listed packages installed:

    R CMD build .
    R CMD INSTALL metraClimate_0.1.0.tar.gz
    R -e 'testthat::test_dir("tests/testthat")'

Install dependencies from the configured CRAN mirror with install.packages(c("climatol", "jsonlite", "testthat")).

## Safety boundaries

- No database connection, SQL, migration, RLS, seed, or Supabase access.
- No API listener or public network port.
- No invented station coordinates, values, units, reference periods, or climate thresholds.
- No automatic promotion of homogenized output to official observations.
- No automatic corrections to original series. Derived output requires scientific review and approval.
- No METRA export adapter until the canonical station catalogue, variable units, temporal resolution, missing-value codes, and completeness rules are approved.

## Next gates

1. Approve the METRA-to-Climatol export mapping and metadata source.
2. Add synthetic fixtures and a reproducible R package/container build.
3. Add a private .NET worker adapter with authorization, bounded execution time, resource limits, and artifact quarantine.
4. Add Angular review UI and an audit trail for raw versus homogenized series.
5. Obtain independent climate-science acceptance before enabling corrections or publication.

## References

- https://cran.r-project.org/web/packages/climatol/
- https://www.climatol.eu/
