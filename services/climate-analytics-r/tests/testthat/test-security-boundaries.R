test_that("symlinked input directories cannot escape the workspace", {
  skip_on_os("windows")

  root <- tempfile("metra-work-")
  outside <- tempfile("metra-outside-")
  dir.create(root)
  dir.create(outside)
  on.exit(unlink(c(root, outside), recursive = TRUE), add = TRUE)

  input_link <- file.path(root, "input-link")
  expect_true(file.symlink(outside, input_link))
  output <- file.path(root, "output")
  dir.create(output)

  expect_error(
    metra_validate_homogenization_request(
      list(variable = "TX", start_year = 2000, end_year = 2001,
           input_dir = input_link, output_dir = output),
      workspace_root = root
    ),
    "inside METRA_CLIMATE_WORK_ROOT"
  )
})

test_that("symlinked Climatol input files cannot escape input_dir", {
  skip_on_os("windows")

  root <- tempfile("metra-work-")
  input <- file.path(root, "input")
  output <- file.path(root, "output")
  outside <- file.path(root, "outside.dat")
  dir.create(input, recursive = TRUE)
  dir.create(output)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)

  writeLines("external data", outside)
  writeLines("35 36 100 TX Station", file.path(input, "TX_2000-2001.est"))
  expect_true(file.symlink(outside, file.path(input, "TX_2000-2001.dat")))

  expect_error(
    metra_validate_homogenization_request(
      list(variable = "TX", start_year = 2000, end_year = 2001,
           input_dir = input, output_dir = output),
      workspace_root = root
    ),
    "must resolve inside input_dir"
  )
})

test_that("input and output directories cannot be the same path", {
  root <- tempfile("metra-work-")
  input <- file.path(root, "shared")
  dir.create(input, recursive = TRUE)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  writeLines("1 2", file.path(input, "TX_2000-2001.dat"))
  writeLines("35 36 100 TX Station", file.path(input, "TX_2000-2001.est"))

  expect_error(
    metra_validate_homogenization_request(
      list(variable = "TX", start_year = 2000, end_year = 2001,
           input_dir = input, output_dir = input),
      workspace_root = root
    ),
    "must be different directories"
  )
})


test_that("directory entries cannot be supplied as Climatol data files", {
  root <- tempfile("metra-work-")
  input <- file.path(root, "input")
  output <- file.path(root, "output")
  dir.create(input, recursive = TRUE)
  dir.create(output)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)

  dir.create(file.path(input, "TX_2000-2001.dat"))
  writeLines("35 36 100 TX Station", file.path(input, "TX_2000-2001.est"))

  expect_error(
    metra_validate_homogenization_request(
      list(variable = "TX", start_year = 2000, end_year = 2001,
           input_dir = input, output_dir = output),
      workspace_root = root
    ),
    "regular Climatol input file"
  )
})

test_that("dot-dot path traversal is rejected after canonical resolution", {
  root <- tempfile("metra-work-")
  outside <- tempfile("metra-outside-")
  dir.create(root)
  dir.create(outside)
  on.exit(unlink(c(root, outside), recursive = TRUE), add = TRUE)

  traversal <- file.path(root, "..", basename(outside))
  expect_error(
    metra_validate_homogenization_request(
      list(variable = "TX", start_year = 2000, end_year = 2001,
           input_dir = traversal, output_dir = root),
      workspace_root = root
    ),
    "inside METRA_CLIMATE_WORK_ROOT"
  )
})
