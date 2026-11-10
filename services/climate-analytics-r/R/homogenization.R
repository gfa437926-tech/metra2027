metra_run_homogenization <- function(request, workspace_root = Sys.getenv("METRA_CLIMATE_WORK_ROOT"),
                                     runner = climatol::homogen) {
  validated <- metra_validate_homogenization_request(request, workspace_root)
  job_dir <- tempfile(pattern = "metra-climatol-", tmpdir = validated$output_dir)
  if (!dir.create(job_dir, showWarnings = FALSE)) {
    stop("Could not create an isolated job directory.", call. = FALSE)
  }
  copied <- file.copy(c(validated$data_file, validated$station_file), job_dir,
                      overwrite = FALSE, copy.mode = FALSE, copy.date = TRUE)
  if (length(copied) != 2L || !all(copied)) {
    unlink(job_dir, recursive = TRUE)
    stop("Could not stage immutable input copies for the job.", call. = FALSE)
  }
  original_wd <- getwd()
  on.exit(setwd(original_wd), add = TRUE)
  setwd(job_dir)
  runner(varcli = validated$variable, anyi = validated$start_year, anyf = validated$end_year,
         tz = "utc", graphics = TRUE, verb = TRUE, logf = TRUE)
  list(status = "completed", variable = validated$variable,
       start_year = validated$start_year, end_year = validated$end_year,
       timezone = "UTC", input_files = c(basename(validated$data_file), basename(validated$station_file)),
       output_directory = job_dir, artifacts = list.files(job_dir, all.files = FALSE, no.. = TRUE),
       climatol_version = as.character(utils::packageVersion("climatol")))
}
