metra_run_homogenization <- function(request, workspace_root = Sys.getenv("METRA_CLIMATE_WORK_ROOT"),
                                     runner = climatol::homogen) {
  validated <- metra_validate_homogenization_request(request, workspace_root)
  job_dir <- tempfile(pattern = "metra-climatol-", tmpdir = validated$output_dir)
  if (!dir.create(job_dir, showWarnings = FALSE)) {
    stop("Could not create an isolated job directory.", call. = FALSE)
  }

  input_paths <- c(validated$data_file, validated$station_file)
  input_hashes_before <- vapply(input_paths, digest::digest, character(1),
                                algo = "sha256", file = TRUE)
  copied <- file.copy(input_paths, job_dir, overwrite = FALSE,
                      copy.mode = FALSE, copy.date = TRUE)
  if (length(copied) != 2L || !all(copied)) {
    unlink(job_dir, recursive = TRUE)
    stop("Could not stage immutable input copies for the job.", call. = FALSE)
  }

  staged_paths <- file.path(job_dir, basename(input_paths))
  staged_hashes <- vapply(staged_paths, digest::digest, character(1),
                          algo = "sha256", file = TRUE)
  if (!identical(unname(input_hashes_before), unname(staged_hashes))) {
    stop("Staged input integrity check failed.", call. = FALSE)
  }

  original_wd <- getwd()
  on.exit(setwd(original_wd), add = TRUE)
  started_at <- format(Sys.time(), tz = "UTC", usetz = TRUE)
  setwd(job_dir)

  run_error <- tryCatch({
    runner(varcli = validated$variable, anyi = validated$start_year,
           anyf = validated$end_year, tz = "utc",
           graphics = TRUE, verb = TRUE, logf = TRUE)
    NULL
  }, error = function(error) error)

  source_hashes_after <- vapply(input_paths, digest::digest, character(1),
                                algo = "sha256", file = TRUE)
  source_unchanged <- identical(unname(input_hashes_before),
                                unname(source_hashes_after))
  artifact_paths <- list.files(job_dir, recursive = TRUE, all.files = FALSE,
                               no.. = TRUE, full.names = TRUE)
  artifact_paths <- artifact_paths[file.info(artifact_paths)$isdir %in% FALSE]
  artifact_paths <- artifact_paths[!artifact_paths %in% staged_paths]
  artifact_names <- substring(artifact_paths, nchar(job_dir) + 2L)
  output_hashes <- if (length(artifact_paths)) {
    stats::setNames(vapply(artifact_paths, digest::digest, character(1),
                           algo = "sha256", file = TRUE), artifact_names)
  } else {
    character()
  }

  status <- if (is.null(run_error) && source_unchanged) "completed" else "failed"
  finished_at <- format(Sys.time(), tz = "UTC", usetz = TRUE)
  provenance <- list(
    schema_version = "1",
    job_id = basename(job_dir),
    status = status,
    started_at_utc = started_at,
    finished_at_utc = finished_at,
    request = list(variable = validated$variable,
                   start_year = validated$start_year,
                   end_year = validated$end_year),
    execution = list(timezone = "UTC", graphics = TRUE, verbose = TRUE,
                     log_file = TRUE,
                     climatol_formals = lapply(as.list(formals(climatol::homogen)),
                       function(value) paste(deparse(value), collapse = ""))),
    runtime = list(R = R.version.string,
                   metraClimate = as.character(utils::packageVersion("metraClimate")),
                   climatol = as.character(utils::packageVersion("climatol")),
                   digest = as.character(utils::packageVersion("digest"))),
    inputs = lapply(seq_along(input_paths), function(i) {
      list(name = basename(input_paths[i]),
           bytes = unname(file.info(input_paths[i])$size),
           sha256_before = unname(input_hashes_before[i]),
           staged_sha256 = unname(staged_hashes[i]),
           sha256_after = unname(source_hashes_after[i]))
    }),
    source_unchanged = source_unchanged,
    outputs = lapply(seq_along(output_hashes), function(i) {
      list(name = names(output_hashes)[i], sha256 = unname(output_hashes[i]))
    }),
    error = if (is.null(run_error)) NULL else conditionMessage(run_error)
  )

  manifest_path <- file.path(job_dir, "metra-provenance.json")
  jsonlite::write_json(provenance, manifest_path, auto_unbox = TRUE,
                       pretty = TRUE, null = "null", na = "null")
  if (!source_unchanged) {
    stop("Source input integrity check failed; job was marked failed in provenance.", call. = FALSE)
  }
  if (!is.null(run_error)) {
    stop(run_error)
  }

  list(status = status, variable = validated$variable,
       start_year = validated$start_year, end_year = validated$end_year,
       timezone = "UTC", output_directory = job_dir,
       artifacts = c(artifact_names, "metra-provenance.json"),
       provenance_file = manifest_path,
       climatol_version = as.character(utils::packageVersion("climatol")))
}
