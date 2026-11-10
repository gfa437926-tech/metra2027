# METRA Climate Data Homogenization

**Status:** R/Climatol worker bootstrap exists on work/climate-analytics-r-bootstrap. End-to-end workflow is not yet integrated or accepted.

## Purpose

Provide a controlled scientific workflow for detecting and assessing non-climatic discontinuities in meteorological time series, producing derived homogeneous series while preserving the original observations.

## Functional stages

1. Select parameter, temporal resolution, station group, and reference period.
2. Review station history: relocation, instrument changes, exposure, observation practice, and metadata corrections.
3. Validate input completeness, units, timestamps, duplicate records, missing values, and station metadata.
4. Prepare the documented Climatol input pair from approved source data.
5. Run quality control and homogenization in the isolated R worker.
6. Review diagnostic plots, outliers, detected breaks, and reconstructed series.
7. Record reviewer decision, method parameters, software version, input hash, and output hash.
8. Publish an approved derived series separately from raw observations.

## Scientific safeguards

- A detected statistical break is a candidate discontinuity, not proof of an instrument error.
- A real climate shift must not be removed merely because it is statistically unusual.
- Homogenized values are derived products and never overwrite source observations.
- Every adjustment must be traceable to inputs, method version, parameters, and human review.
- No fixed acceptance thresholds are invented in this specification.
- Daily/sub-daily processing must follow Climatol guidance and must not reuse monthly defaults without scientific justification.

## Current implementation

The R worker validates the request, stages input copies, invokes climatol::homogen() with UTC handling, and inventories artifacts. It is not yet connected to METRA data exports, the .NET API, database persistence, or Angular review pages.

## Required acceptance

- representative approved METRA input fixtures;
- reproducible R package and container checks;
- tests for invalid/missing data and station metadata;
- expert review of Climatol parameters by variable and frequency;
- independent validation dataset and documented acceptance criteria;
- explicit approval before derived-series publication.
