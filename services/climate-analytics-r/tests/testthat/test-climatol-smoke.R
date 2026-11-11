test_that("Climatol runs end-to-end with its published Temp example dataset", {
  skip_if_not_installed("climatol")

  fixture <- new.env(parent = globalenv())
  utils::data("climatol_data", package = "climatol", envir = fixture)
  expect_true(is.matrix(fixture$Temp.dat) || is.data.frame(fixture$Temp.dat))
  expect_true(is.data.frame(fixture$Temp.est) || is.matrix(fixture$Temp.est))

  root <- tempfile("metra-climatol-fixture-")
  input <- file.path(root, "input")
  output <- file.path(root, "output")
  dir.create(input, recursive = TRUE)
  dir.create(output)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)

  # CRAN's documented monthly five-station example: 1961–2005.
  # It is package demonstration data, not METRA station observations.
  write(fixture$Temp.dat, file = file.path(input, "Temp_1961-2005.dat"))
  utils::write.table(
    fixture$Temp.est,
    file = file.path(input, "Temp_1961-2005.est"),
    row.names = FALSE,
    col.names = FALSE,
    quote = FALSE
  )

  source_data_hash <- digest::digest(
    file = file.path(input, "Temp_1961-2005.dat"),
    algo = "sha256"
  )
  result <- metra_run_homogenization(
    list(
      variable = "Temp",
      start_year = 1961,
      end_year = 2005,
      input_dir = input,
      output_dir = output
    ),
    workspace_root = root
  )

  expect_equal(result$status, "completed")
  expect_true(length(result$artifacts) > 1L)
  expect_true(all(file.exists(file.path(result$output_directory, result$artifacts))))
  expect_identical(
    digest::digest(file = file.path(input, "Temp_1961-2005.dat"), algo = "sha256"),
    source_data_hash
  )

  provenance <- jsonlite::fromJSON(result$provenance_file, simplifyVector = FALSE)
  expect_equal(provenance$status, "completed")
  expect_true(provenance$source_unchanged)
  expect_match(provenance$runtime$climatol, "^4\\.5")
  expect_gt(length(provenance$outputs), 0L)
})
