\name{metra_climatology_summary}
\alias{metra_climatology_summary}
\title{Calculate explicit daily climatology summaries}
\usage{
metra_climatology_summary(data, period, statistic, min_completeness)
}
\arguments{
\item{data}{Data frame with station_id, date (Date class), and numeric value columns.}
\item{period}{Explicit aggregation period: month or year.}
\item{statistic}{Explicit statistic: mean, sum, min, or max.}
\item{min_completeness}{Required completeness fraction between zero and one. No default is applied.}
}
\value{A data frame with value, valid_days, expected_days, completeness, and accepted columns for each station-period.}
\description{Summarizes daily data only. Missing values remain missing, duplicate station-date records are rejected, and values are withheld when the caller-supplied completeness threshold is not met. Variable-specific units and the choice of statistic remain the caller's responsibility.}
