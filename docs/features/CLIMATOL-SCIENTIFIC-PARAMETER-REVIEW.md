# Climatol Scientific Parameter Review — METRA

**Status:** reference for scientific approval only. None of the values below is adopted as a METRA production profile.

## Why this gate exists

Climatol's homogen() function performs quality control, homogenization, missing-data infilling, outlier handling, and detection/correction of shifts. Its parameters depend on variable, temporal resolution, station network, reference series, and metadata. Package defaults are software defaults, not METRA-approved scientific thresholds.

The reviewed CRAN reference is Climatol 4.5-0 (2026-05-20). Recheck the installed version's reference manual before approving a profile.

## Parameters requiring explicit review

| Parameter | Documented Climatol 4.5-0 behavior | METRA decision |
|---|---|---|
| test | snht default; cuct is documented as experimental | Select only after method review |
| nref | Up to 10 reference series in detection stages and 4 in final adjustments by default | Review network density and reference suitability |
| std | Normalization choices: deviations, ratios (when means > 1), or standardization | Select by variable/data distribution |
| swa | Default step is 365 terms for daily data and 60 otherwise | Confirm temporal resolution and sampling |
| niqd | Default c(5,6,3) for outlier/second-difference/run-length QC | Do not adopt without variable-specific review |
| dz.max, dz.min | Default upper threshold 0.01 and lower threshold tied to it; can distinguish suspect from probable errors | Approve thresholds and action semantics |
| inht | Default 25; manual notes 15 may help monthly precipitation; daily/subdaily need much higher values if tested directly | Decide analysis scale and validate |
| cumc | Code for accumulated missing daily precipitation | Must map from an approved source code; never guess |
| na.strings | Default missing-value token NA | Map approved METRA missing codes exactly |
| vmin, vmax | Optional physical limits for the variable | Only from an authoritative variable definition |
| ini, x, tinc | Control initial date / irregular time vector / time increment | Required when data do not match regular-calendar assumptions |
| tz | Default utc; relevant for subdaily data | Keep UTC-only contract; validate source timestamps |
| annual | Annual graph aggregation choice: mean, sum/total | Choose per variable and reporting purpose |
| force, onlyQC | Control direct daily/subdaily homogenization and QC-only operation | Explicitly approve workflow stage |

## Frequency-specific caution

The Climatol manual states that daily or subdaily inhomogeneities should generally be detected on monthly aggregates produced with dd2m. If direct daily/subdaily detection is used, the manual describes much higher inht values (200–300) as an initial guess, not a universal threshold. Monthly temperature and other variables have a documented default context around 25; monthly precipitation may need separate assessment because of its higher variability.

Therefore:
- do not apply one parameter profile to daily, monthly, and subdaily series;
- do not treat package defaults as scientifically accepted for METRA station data;
- consider monthly aggregation for detection while preserving daily observations for appropriate downstream adjustment, after method review;
- evaluate precipitation accumulation codes and missingness separately;
- review station-network reference quality and station-history metadata before interpreting detected breaks.

## Outputs that must be reviewed

The manual describes:
- text processing log;
- corrected-outlier list (*_out.csv);
- corrected-break list (*_brk.csv);
- diagnostic PDF;
- R binary result (*.rda) containing original and homogenized matrices, station metadata, and diagnostics.

The dahstat(stat="series") export can include flags: 0 original, 1 infilled, 2 corrected. The METRA review layer must preserve these distinctions.

## Approval record required

For every approved profile, record:
- variable identifier and units;
- temporal resolution and calendar assumptions;
- Climatol/R versions;
- all explicit parameter values and package defaults;
- station selection and reference network;
- missing/accumulated-precipitation code mapping;
- study period and station-history source;
- validation dataset, diagnostics, and acceptance criteria;
- approver, UTC approval timestamp, and rationale.

## References

- CRAN Climatol 4.5-0 reference manual: https://cran.r-project.org/web/packages/climatol/refman/climatol.html
- Climatol project and user guides: https://www.climatol.eu/
