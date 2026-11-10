# METRA Climatology System

**Status:** requirements and architecture stage. No production climate aggregates or reports are implemented by this worker bootstrap.

## Scope

- daily, monthly, seasonal, and annual climatological summaries;
- temperature, precipitation, wind, pressure, humidity, and sunshine where source data support them;
- climate extremes and indices using an approved definition set;
- trends and comparisons across explicitly selected periods;
- station and regional comparisons with station history and elevation context;
- maps only where data density, metadata, and interpolation method are scientifically defensible;
- exportable reports with period, completeness, units, source, method, and software version.

## Data rules

- All timestamps and reporting periods are based on UTC.
- Every statistic identifies its reference period and completeness rule.
- Missing values remain missing; they are never silently converted to zero.
- Raw, quality-controlled, and homogenized series remain distinct products.
- Regional and national summaries must document station inclusion/exclusion.
- No climate normal, extreme threshold, index definition, or reference period is assumed without an approved standard.

## Relationship to homogenization

Climatology calculations may consume raw, quality-controlled, or approved homogenized series. The selected series class must be visible in every result. Homogenized data are not automatically preferred in all scientific contexts; the analyst must be able to compare the original and derived series.

## Implementation status

The R worker bootstrap now includes a generic daily-input monthly/yearly summary function. It requires an explicit statistic and completeness threshold, uses calendar-day denominators, rejects duplicate station-date records, and withholds values below the requested completeness. It is not yet a production climatology module: variable-specific aggregation rules, climate indices, maps, reporting APIs, and user interfaces remain future work.
