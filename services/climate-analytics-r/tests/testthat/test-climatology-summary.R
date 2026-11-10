test_that("monthly summaries use calendar-day completeness and preserve missingness", {
  dates <- seq(as.Date("2024-02-01"), as.Date("2024-02-29"), by = "day")
  values <- rep(1, length(dates))
  values[29] <- NA_real_
  data <- data.frame(station_id=rep("ST001", length(dates)), date=dates, value=values)
  result <- metra_climatology_summary(data, period="month", statistic="mean",
                                      min_completeness=0.95)
  expect_equal(result$expected_days, 29L)
  expect_equal(result$valid_days, 28L)
  expect_equal(result$completeness, 28/29)
  expect_true(result$accepted)
  expect_equal(result$value, 1)
})

test_that("insufficient completeness withholds the summary value", {
  dates <- as.Date(c("2023-01-01", "2023-01-02"))
  data <- data.frame(station_id=c("ST001","ST001"), date=dates, value=c(0, NA_real_))
  result <- metra_climatology_summary(data, period="year", statistic="sum",
                                      min_completeness=0.5)
  expect_equal(result$expected_days, 365L)
  expect_false(result$accepted)
  expect_true(is.na(result$value))
})

test_that("duplicate station dates and implicit aggregation choices are rejected", {
  data <- data.frame(station_id=c("ST001","ST001"),
                     date=as.Date(c("2020-01-01","2020-01-01")),
                     value=c(1,2))
  expect_error(metra_climatology_summary(data, "month", "mean", 0.8), "Duplicate")
  data$date[2] <- as.Date("2020-01-02")
  expect_error(metra_climatology_summary(data, "month", "mean", NULL), "required")
})
