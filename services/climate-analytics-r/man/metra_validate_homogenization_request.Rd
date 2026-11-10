\name{metra_validate_homogenization_request}
\alias{metra_validate_homogenization_request}
\title{Validate a METRA Climatol job request}
\usage{
metra_validate_homogenization_request(
  request,
  workspace_root = Sys.getenv("METRA_CLIMATE_WORK_ROOT")
)
}
\arguments{
\item{request}{A named list containing variable, start_year, end_year, input_dir, and output_dir.}
\item{workspace_root}{Existing root directory that contains all job input and output directories.}
}
\value{A normalized request list with validated input file paths.}
\description{Validates request fields, year bounds, workspace containment, and the matching non-empty Climatol .dat and .est input pair. It does not modify source files.}
