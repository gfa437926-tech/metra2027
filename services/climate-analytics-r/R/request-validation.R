metra_validate_homogenization_request <- function(request, workspace_root = Sys.getenv("METRA_CLIMATE_WORK_ROOT")) {
  required <- c("variable", "start_year", "end_year", "input_dir", "output_dir")
  if (!is.list(request) || !all(required %in% names(request))) {
    stop("Request must contain: ", paste(required, collapse = ", "), call. = FALSE)
  }
  variable <- request$variable
  if (!is.character(variable) || length(variable) != 1L ||
      !grepl("^[A-Za-z][A-Za-z0-9]{0,7}$", variable)) {
    stop("variable must be a short alphanumeric Climatol variable code.", call. = FALSE)
  }
  years <- unlist(list(request$start_year, request$end_year), use.names = FALSE)
  if (length(years) != 2L || !is.numeric(years) || anyNA(years) ||
      any(years %% 1 != 0) || years[1] < 1800 || years[2] > 2200 ||
      years[1] > years[2]) {
    stop("start_year/end_year must be ordered integer years in 1800..2200.", call. = FALSE)
  }
  if (!nzchar(workspace_root) || !dir.exists(workspace_root)) {
    stop("METRA_CLIMATE_WORK_ROOT must point to an existing workspace directory.", call. = FALSE)
  }
  root <- normalizePath(workspace_root, winslash = "/", mustWork = TRUE)
  resolve_child <- function(path, label) {
    if (!is.character(path) || length(path) != 1L || !nzchar(path) || !dir.exists(path)) {
      stop(label, " must be an existing directory.", call. = FALSE)
    }
    resolved <- normalizePath(path, winslash = "/", mustWork = TRUE)
    if (!startsWith(paste0(resolved, "/"), paste0(root, "/"))) {
      stop(label, " must be inside METRA_CLIMATE_WORK_ROOT.", call. = FALSE)
    }
    resolved
  }
  input_dir <- resolve_child(request$input_dir, "input_dir")
  output_dir <- resolve_child(request$output_dir, "output_dir")
  if (identical(input_dir, output_dir)) {
    stop("input_dir and output_dir must be different directories.", call. = FALSE)
  }
  base <- paste0(variable, "_", years[1], "-", years[2])
  data_file <- file.path(input_dir, paste0(base, ".dat"))
  station_file <- file.path(input_dir, paste0(base, ".est"))
  for (file in c(data_file, station_file)) {
    info <- file.info(file)
    if (!file.exists(file) || is.na(info$size) || info$size < 1) {
      stop("Required non-empty Climatol input file is missing: ", basename(file), call. = FALSE)
    }
  }
  list(variable = variable, start_year = as.integer(years[1]), end_year = as.integer(years[2]),
       input_dir = input_dir, output_dir = output_dir,
       data_file = data_file, station_file = station_file)
}
