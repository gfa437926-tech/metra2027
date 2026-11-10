\name{metra_run_homogenization}
\alias{metra_run_homogenization}
\title{Run an isolated Climatol homogenization job}
\usage{
metra_run_homogenization(
  request,
  workspace_root = Sys.getenv("METRA_CLIMATE_WORK_ROOT"),
  runner = climatol::homogen
)
}
\arguments{
\item{request}{A named list accepted by metra_validate_homogenization_request.}
\item{workspace_root}{Existing root directory that contains all job input and output directories.}
\item{runner}{Homogenization function; injectable for deterministic tests.}
}
\value{A list describing the completed job, generated artifacts, UTC timezone, and Climatol version.}
\description{Copies the validated input pair into a unique output job directory and runs Climatol there. Original inputs are not modified. This function does not publish results or alter official observations.}
