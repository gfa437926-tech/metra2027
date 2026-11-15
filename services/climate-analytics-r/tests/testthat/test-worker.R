test_that("valid requests resolve the required Climatol input pair", {
  root <- tempfile("metra-work-")
  input <- file.path(root, "input")
  output <- file.path(root, "output")
  dir.create(input, recursive = TRUE)
  dir.create(output)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  writeLines("1 2 3", file.path(input, "TX_1991-2000.dat"))
  writeLines("35 36 100 TX Station", file.path(input, "TX_1991-2000.est"))
  result <- metra_validate_homogenization_request(
    list(variable="TX", start_year=1991, end_year=2000, input_dir=input, output_dir=output),
    workspace_root=root)
  expect_equal(result$variable, "TX")
  expect_true(file.exists(result$data_file))
  expect_true(file.exists(result$station_file))
})

test_that("paths outside the configured workspace are rejected", {
  root <- tempfile("metra-work-")
  outside <- tempfile("metra-outside-")
  dir.create(root)
  dir.create(outside)
  on.exit(unlink(c(root, outside), recursive = TRUE), add = TRUE)
  expect_error(metra_validate_homogenization_request(
    list(variable="RR", start_year=2000, end_year=2001, input_dir=outside, output_dir=root),
    workspace_root=root), "inside METRA_CLIMATE_WORK_ROOT")
})

test_that("invalid year ranges and variable names are rejected", {
  root <- tempfile("metra-work-")
  input <- file.path(root, "input")
  output <- file.path(root, "output")
  dir.create(input, recursive = TRUE)
  dir.create(output)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  base <- list(start_year=2001, end_year=2000, input_dir=input, output_dir=output)
  expect_error(metra_validate_homogenization_request(c(list(variable="RR"), base), root),
               "ordered integer years")
  base$start_year <- 2000
  base$end_year <- 2001
  expect_error(metra_validate_homogenization_request(c(list(variable="../RR"), base), root),
               "short alphanumeric")
})

test_that("Climatol receives staged copies and source inputs remain intact", {
  root <- tempfile("metra-work-")
  input <- file.path(root, "input")
  output <- file.path(root, "output")
  dir.create(input, recursive = TRUE)
  dir.create(output)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  data_path <- file.path(input, "TX_1991-1992.dat")
  station_path <- file.path(input, "TX_1991-1992.est")
  writeLines("1 2 3", data_path)
  writeLines("35 36 100 TX Station", station_path)
  fake_runner <- function(varcli, anyi, anyf, tz, graphics, verb, logf) {
    expect_equal(varcli, "TX")
    expect_equal(tz, "utc")
    writeLines("test artifact", paste0(varcli, "_", anyi, "-", anyf, ".txt"))
    invisible(NULL)
  }
  result <- metra_run_homogenization(
    list(variable="TX", start_year=1991, end_year=1992, input_dir=input, output_dir=output),
    workspace_root=root, runner=fake_runner)
  expect_equal(result$status, "completed")
  expect_true(file.exists(data_path))
  expect_true(file.exists(station_path))
  expect_true(any(grepl("\\.txt$", result$artifacts)))
})
