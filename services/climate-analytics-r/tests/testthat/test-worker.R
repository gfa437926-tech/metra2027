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
  expect_true(file.exists(result$provenance_file))
  provenance <- jsonlite::fromJSON(result$provenance_file, simplifyVector = FALSE)
  expect_true(provenance$source_unchanged)
  expect_equal(provenance$status, "completed")
  expect_match(provenance$inputs[[1]]$sha256_before, "^[0-9a-f]{64}$")
  expect_match(provenance$outputs[[1]]$sha256, "^[0-9a-f]{64}$")
  expect_match(provenance$runtime$R, "^R version")
})

test_that("failed Climatol executions retain a failed provenance record", {
  root <- tempfile("metra-work-")
  input <- file.path(root, "input")
  output <- file.path(root, "output")
  dir.create(input, recursive = TRUE)
  dir.create(output)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  writeLines("1 2", file.path(input, "TX_1991-1991.dat"))
  writeLines("35 36 100 TX Station", file.path(input, "TX_1991-1991.est"))
  failing_runner <- function(...) stop("simulated Climatol failure")
  expect_error(metra_run_homogenization(
    list(variable="TX", start_year=1991, end_year=1991, input_dir=input, output_dir=output),
    workspace_root=root, runner=failing_runner), "simulated Climatol failure")
  job_dirs <- list.dirs(output, recursive = FALSE, full.names = TRUE)
  expect_length(job_dirs, 1L)
  manifest <- file.path(job_dirs[[1]], "metra-provenance.json")
  expect_true(file.exists(manifest))
  provenance <- jsonlite::fromJSON(manifest, simplifyVector = FALSE)
  expect_equal(provenance$status, "failed")
  expect_match(provenance$error, "simulated Climatol failure")
  expect_true(provenance$source_unchanged)
})


test_that("non-finite and non-real year values are rejected cleanly", {
  root <- tempfile("metra-work-")
  input <- file.path(root, "input")
  output <- file.path(root, "output")
  dir.create(input, recursive = TRUE)
  dir.create(output)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  base <- list(variable = "TX", end_year = 2001, input_dir = input, output_dir = output)

  expect_error(
    metra_validate_homogenization_request(
      c(list(start_year = Inf), base), workspace_root = root
    ),
    "ordered integer years"
  )
  expect_error(
    metra_validate_homogenization_request(
      c(list(start_year = 2000 + 1i), base), workspace_root = root
    ),
    "ordered integer years"
  )
})


test_that("worker restores the caller working directory after success and failure", {
  root <- tempfile("metra-work-")
  input <- file.path(root, "input")
  output <- file.path(root, "output")
  dir.create(input, recursive = TRUE)
  dir.create(output)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  writeLines("1 2", file.path(input, "TX_1991-1991.dat"))
  writeLines("35 36 100 TX Station", file.path(input, "TX_1991-1991.est"))
  request <- list(variable = "TX", start_year = 1991, end_year = 1991,
                  input_dir = input, output_dir = output)
  caller_wd <- getwd()

  metra_run_homogenization(request, workspace_root = root,
    runner = function(...) writeLines("ok", "success.txt"))
  expect_identical(getwd(), caller_wd)

  expect_error(metra_run_homogenization(request, workspace_root = root,
    runner = function(...) stop("expected runner failure")),
    "expected runner failure")
  expect_identical(getwd(), caller_wd)
})

test_that("repeated jobs retain separate output directories and manifests", {
  root <- tempfile("metra-work-")
  input <- file.path(root, "input")
  output <- file.path(root, "output")
  dir.create(input, recursive = TRUE)
  dir.create(output)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  writeLines("1 2", file.path(input, "TX_1991-1991.dat"))
  writeLines("35 36 100 TX Station", file.path(input, "TX_1991-1991.est"))
  request <- list(variable = "TX", start_year = 1991, end_year = 1991,
                  input_dir = input, output_dir = output)
  runner <- function(...) writeLines("isolated", "artifact.txt")

  first <- metra_run_homogenization(request, workspace_root = root, runner = runner)
  second <- metra_run_homogenization(request, workspace_root = root, runner = runner)

  expect_false(identical(first$output_directory, second$output_directory))
  expect_true(file.exists(first$provenance_file))
  expect_true(file.exists(second$provenance_file))
  expect_true(file.exists(file.path(first$output_directory, "artifact.txt")))
  expect_true(file.exists(file.path(second$output_directory, "artifact.txt")))
})


test_that("worker rejects overlapping jobs sharing the process working directory", {
  root <- tempfile("metra-work-")
  input <- file.path(root, "input")
  output <- file.path(root, "output")
  dir.create(input, recursive = TRUE)
  dir.create(output)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  writeLines("1 2", file.path(input, "TX_1991-1991.dat"))
  writeLines("35 36 100 TX Station", file.path(input, "TX_1991-1991.est"))
  request <- list(variable = "TX", start_year = 1991, end_year = 1991,
                  input_dir = input, output_dir = output)

  runner <- function(...) {
    expect_true(dir.exists(file.path(root, ".metra-climatol-worker.lock")))
    expect_error(
      metra_run_homogenization(request, workspace_root = root,
        runner = function(...) writeLines("nested", "nested.txt")),
      "Another Climatol job is active"
    )
    writeLines("outer job completed", "outer.txt")
  }

  result <- metra_run_homogenization(request, workspace_root = root, runner = runner)
  expect_equal(result$status, "completed")
  expect_false(dir.exists(file.path(root, ".metra-climatol-worker.lock")))
})


test_that("worker releases the workspace lock after runner failure", {
  root <- tempfile("metra-work-")
  input <- file.path(root, "input")
  output <- file.path(root, "output")
  dir.create(input, recursive = TRUE)
  dir.create(output)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  writeLines("1 2", file.path(input, "TX_1991-1991.dat"))
  writeLines("35 36 100 TX Station", file.path(input, "TX_1991-1991.est"))
  request <- list(variable = "TX", start_year = 1991, end_year = 1991,
                  input_dir = input, output_dir = output)

  expect_error(
    metra_run_homogenization(request, workspace_root = root,
      runner = function(...) stop("forced worker failure")),
    "forced worker failure"
  )
  expect_false(dir.exists(file.path(root, ".metra-climatol-worker.lock")))
})

test_that("worker refuses a pre-existing lock without deleting it", {
  root <- tempfile("metra-work-")
  input <- file.path(root, "input")
  output <- file.path(root, "output")
  lock <- file.path(root, ".metra-climatol-worker.lock")
  dir.create(input, recursive = TRUE)
  dir.create(output)
  dir.create(lock)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  writeLines(c("pid=not-verified", "started_at_utc=operator-review"),
             file.path(lock, "owner.txt"))
  writeLines("1 2", file.path(input, "TX_1991-1991.dat"))
  writeLines("35 36 100 TX Station", file.path(input, "TX_1991-1991.est"))
  request <- list(variable = "TX", start_year = 1991, end_year = 1991,
                  input_dir = input, output_dir = output)

  expect_error(
    metra_run_homogenization(request, workspace_root = root,
      runner = function(...) writeLines("must not run", "unexpected.txt")),
    "Another Climatol job is active"
  )
  expect_true(dir.exists(lock))
  expect_true(file.exists(file.path(lock, "owner.txt")))
  expect_length(list.files(output, all.files = TRUE, no.. = TRUE), 0L)
})


test_that("worker records lock ownership metadata while the runner is active", {
  root <- tempfile("metra-work-")
  input <- file.path(root, "input")
  output <- file.path(root, "output")
  lock <- file.path(root, ".metra-climatol-worker.lock")
  dir.create(input, recursive = TRUE)
  dir.create(output)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  writeLines("1 2", file.path(input, "TX_1991-1991.dat"))
  writeLines("35 36 100 TX Station", file.path(input, "TX_1991-1991.est"))
  request <- list(variable = "TX", start_year = 1991, end_year = 1991,
                  input_dir = input, output_dir = output)

  result <- metra_run_homogenization(request, workspace_root = root,
    runner = function(...) {
      owner <- readLines(file.path(lock, "owner.txt"))
      expect_true(any(owner == paste0("pid=", Sys.getpid())))
      expect_true(any(grepl("^started_at_utc=.*UTC$", owner)))
      writeLines("ok", "metadata-check.txt")
    })

  expect_equal(result$status, "completed")
  expect_false(dir.exists(lock))
})

test_that("source mutation marks provenance failed and releases the workspace lock", {
  root <- tempfile("metra-work-")
  input <- file.path(root, "input")
  output <- file.path(root, "output")
  data_path <- file.path(input, "TX_1991-1991.dat")
  lock <- file.path(root, ".metra-climatol-worker.lock")
  dir.create(input, recursive = TRUE)
  dir.create(output)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  writeLines("1 2", data_path)
  writeLines("35 36 100 TX Station", file.path(input, "TX_1991-1991.est"))
  request <- list(variable = "TX", start_year = 1991, end_year = 1991,
                  input_dir = input, output_dir = output)

  expect_error(
    metra_run_homogenization(request, workspace_root = root,
      runner = function(...) {
        writeLines("tampered", data_path)
        writeLines("diagnostic", "runner-output.txt")
      }),
    "Source input integrity check failed"
  )

  job_dirs <- list.dirs(output, recursive = FALSE, full.names = TRUE)
  expect_length(job_dirs, 1L)
  manifest <- jsonlite::fromJSON(
    file.path(job_dirs[[1]], "metra-provenance.json"),
    simplifyVector = FALSE
  )
  expect_equal(manifest$status, "failed")
  expect_false(manifest$source_unchanged)
  expect_false(dir.exists(lock))
})
