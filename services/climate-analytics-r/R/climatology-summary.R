# Summarize daily observations without silently treating missing values as zero.
metra_climatology_summary <- function(data, period, statistic, min_completeness) {
  if (!is.data.frame(data) || !all(c("station_id", "date", "value") %in% names(data))) {
    stop("data must contain station_id, date, and value columns.", call. = FALSE)
  }
  if (!inherits(data$date, "Date") || anyNA(data$date)) {
    stop("date must contain complete Date values; timestamps must be normalized to UTC before conversion.", call. = FALSE)
  }
  if (!is.character(data$station_id) || anyNA(data$station_id) ||
      any(!nzchar(trimws(data$station_id)))) {
    stop("station_id must contain non-empty character identifiers.", call. = FALSE)
  }
  if (!is.numeric(data$value) || any(!is.finite(data$value) & !is.na(data$value))) {
    stop("value must be numeric and finite or NA.", call. = FALSE)
  }
  if (anyDuplicated(data[c("station_id", "date")])) {
    stop("Duplicate station_id/date records are not allowed.", call. = FALSE)
  }
  if (length(period) != 1L || !period %in% c("month", "year")) {
    stop("period must be 'month' or 'year'.", call. = FALSE)
  }
  if (length(statistic) != 1L || !statistic %in% c("mean", "sum", "min", "max")) {
    stop("statistic must be explicitly selected: mean, sum, min, or max.", call. = FALSE)
  }
  if (!is.numeric(min_completeness) || length(min_completeness) != 1L ||
      is.na(min_completeness) || min_completeness < 0 || min_completeness > 1) {
    stop("min_completeness is required and must be between 0 and 1.", call. = FALSE)
  }

  period_key <- if (period == "month") format(data$date, "%Y-%m") else format(data$date, "%Y")
  groups <- split(seq_len(nrow(data)), interaction(data$station_id, period_key, drop = TRUE))
  rows <- lapply(groups, function(index) {
    station <- data$station_id[index[1]]
    key <- period_key[index[1]]
    start <- if (period == "month") as.Date(paste0(key, "-01")) else as.Date(paste0(key, "-01-01"))
    next_start <- if (period == "month") {
      if (as.integer(format(start, "%m")) == 12L) as.Date(paste0(as.integer(format(start, "%Y")) + 1L, "-01-01"))
      else as.Date(paste0(format(start, "%Y-%m"), "-01")) + 31
    } else {
      as.Date(paste0(as.integer(key) + 1L, "-01-01"))
    }
    if (period == "month" && as.integer(format(start, "%m")) != 12L) {
      next_start <- as.Date(format(start, "%Y-%m-01")) + 31
      next_start <- as.Date(format(next_start, "%Y-%m-01"))
    }
    expected <- as.integer(next_start - start)
    values <- data$value[index]
    valid <- values[!is.na(values)]
    valid_days <- length(valid)
    completeness <- valid_days / expected
    accepted <- valid_days > 0L && completeness >= min_completeness
    result_value <- if (!accepted) NA_real_ else switch(
      statistic,
      mean = mean(valid),
      sum = sum(valid),
      min = min(valid),
      max = max(valid)
    )
    data.frame(station_id = station, period = key, statistic = statistic,
               value = as.numeric(result_value), valid_days = valid_days,
               expected_days = expected, completeness = completeness,
               accepted = accepted, stringsAsFactors = FALSE)
  })
  if (length(rows) == 0L) {
    return(data.frame(station_id=character(), period=character(), statistic=character(),
                      value=numeric(), valid_days=integer(), expected_days=integer(),
                      completeness=numeric(), accepted=logical()))
  }
  result <- do.call(rbind, rows)
  rownames(result) <- NULL
  result[order(result$station_id, result$period), , drop = FALSE]
}
