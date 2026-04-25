prep_dashboard_data <- function(
  acled_xlsx = "data/US-and-Canada_aggregated_data_up_to_week_of-2026-03-28.xlsx",
  ccc_dir = "data/ccc",
  out_dir = "data/prepared"
) {
  if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

  if (!requireNamespace("readxl", quietly = TRUE)) stop("Missing package: readxl")
  if (!requireNamespace("dplyr", quietly = TRUE)) stop("Missing package: dplyr")
  if (!requireNamespace("tidyr", quietly = TRUE)) stop("Missing package: tidyr")
  if (!requireNamespace("readr", quietly = TRUE)) stop("Missing package: readr")
  if (!requireNamespace("lubridate", quietly = TRUE)) stop("Missing package: lubridate")
  if (!requireNamespace("stringr", quietly = TRUE)) stop("Missing package: stringr")

  `%>%` <- dplyr::`%>%`

  message("Reading ACLED: ", acled_xlsx)
  acled <- readxl::read_excel(acled_xlsx) %>%
    dplyr::rename_with(tolower)

  if (!all(c("week", "country", "admin1", "events") %in% names(acled))) {
    stop("Unexpected ACLED column names after lowercasing. Found: ", paste(names(acled), collapse = ", "))
  }

  acled_us <- acled %>%
    dplyr::filter(.data$country == "United States") %>%
    dplyr::mutate(
      week = lubridate::as_date(.data$week),
      events = as.numeric(.data$events)
    ) %>%
    dplyr::filter(!is.na(.data$week), !is.na(.data$events))

  state_name_to_abb <- c(
    stats::setNames(state.abb, state.name),
    "District of Columbia" = "DC"
  )

  acled_us_week_state <- acled_us %>%
    dplyr::mutate(
      state = unname(state_name_to_abb[as.character(.data$admin1)]),
      state = dplyr::if_else(is.na(.data$state), as.character(.data$admin1), .data$state)
    ) %>%
    dplyr::group_by(.data$week, .data$state, .data$admin1) %>%
    dplyr::summarise(acled_events = sum(.data$events, na.rm = TRUE), .groups = "drop")

  acled_us_week <- acled_us_week_state %>%
    dplyr::group_by(.data$week) %>%
    dplyr::summarise(acled_events = sum(.data$acled_events, na.rm = TRUE), .groups = "drop")

  acled_comp_week <- acled_us %>%
    dplyr::group_by(.data$week, .data$event_type, .data$sub_event_type) %>%
    dplyr::summarise(acled_events = sum(.data$events, na.rm = TRUE), .groups = "drop")

  read_ccc_csv <- function(path) {
    message("Reading CCC: ", path)
    readr::read_csv(
      file = path,
      show_col_types = FALSE,
      progress = FALSE,
      locale = readr::locale(encoding = "latin1")
    )
  }

  ccc_paths <- c(
    file.path(ccc_dir, "ccc_compiled_20172020.csv"),
    file.path(ccc_dir, "ccc_compiled_20212024.csv"),
    file.path(ccc_dir, "ccc-phase3-public.csv")
  )
  missing <- ccc_paths[!file.exists(ccc_paths)]
  if (length(missing) > 0) stop("Missing CCC files:\n", paste(missing, collapse = "\n"))

  ccc_1720 <- read_ccc_csv(ccc_paths[[1]])
  ccc_2124 <- read_ccc_csv(ccc_paths[[2]])
  ccc_p3 <- read_ccc_csv(ccc_paths[[3]])

  normalize_ccc <- function(df, source) {
    df <- dplyr::rename_with(df, tolower)

    is_phase3 <- grepl("phase3", source, fixed = TRUE)

    if (is_phase3) {
      if (!all(c("date", "resolved_state", "event_type") %in% names(df))) {
        stop("Unexpected CCC phase3 schema for file: ", source)
      }

      return(
        df %>%
          dplyr::transmute(
            source = source,
            date = lubridate::as_date(.data$date, format = "%m/%d/%Y"),
            state = as.character(.data$resolved_state),
            ccc_category = dplyr::coalesce(as.character(.data$event_type), NA_character_),
            online = suppressWarnings(as.integer(.data$online))
          )
      )
    }

    # compiled files (also contain resolved_* fields; do not use the phase3 parser)
    if (!all(c("date", "state", "type") %in% names(df))) {
      stop("Unexpected CCC compiled schema for file: ", source)
    }

    df %>%
      dplyr::transmute(
        source = source,
        date = lubridate::as_date(.data$date),
        state = as.character(.data$state),
        ccc_category = dplyr::coalesce(as.character(.data$type), NA_character_),
        online = suppressWarnings(as.integer(.data$online))
      )
  }

  ccc <- dplyr::bind_rows(
    normalize_ccc(ccc_1720, "ccc_compiled_20172020.csv"),
    normalize_ccc(ccc_2124, "ccc_compiled_20212024.csv"),
    normalize_ccc(ccc_p3, "ccc-phase3-public.csv")
  ) %>%
    dplyr::filter(!is.na(.data$date)) %>%
    dplyr::mutate(
      state = stringr::str_trim(.data$state),
      state = dplyr::if_else(.data$state == "Washington DC", "DC", .data$state)
    ) %>%
    dplyr::filter(.data$state %in% state.abb) %>%
    dplyr::mutate(
      # Align CCC event dates to ACLED's Saturday-dated `WEEK` labels.
      # Empirically, ACLED weeks are dated on Saturdays; CCC weekly buckets should match those labels.
      week = lubridate::floor_date(.data$date + lubridate::days(1), "week", week_start = 6)
    )

  ccc_week_state <- ccc %>%
    dplyr::count(.data$week, .data$state, name = "ccc_events")

  ccc_week <- ccc_week_state %>%
    dplyr::group_by(.data$week) %>%
    dplyr::summarise(ccc_events = sum(.data$ccc_events, na.rm = TRUE), .groups = "drop")

  ccc_comp_week <- ccc %>%
    dplyr::count(.data$week, .data$ccc_category, name = "ccc_events")

  joined_week <- dplyr::full_join(acled_us_week, ccc_week, by = "week") %>%
    dplyr::mutate(
      acled_events = tidyr::replace_na(.data$acled_events, 0L),
      ccc_events = tidyr::replace_na(.data$ccc_events, 0L),
      diff = .data$ccc_events - .data$acled_events
    )

  joined_week_state <- dplyr::full_join(
    acled_us_week_state %>% dplyr::select("week", "state", "admin1", "acled_events"),
    ccc_week_state,
    by = c("week", "state")
  ) %>%
    dplyr::mutate(
      acled_events = tidyr::replace_na(.data$acled_events, 0L),
      ccc_events = tidyr::replace_na(.data$ccc_events, 0L),
      diff = .data$ccc_events - .data$acled_events
    )

  readr::write_rds(acled_us_week, file.path(out_dir, "acled_us_week.rds"), compress = "gz")
  readr::write_rds(acled_us_week_state, file.path(out_dir, "acled_us_week_state.rds"), compress = "gz")
  readr::write_rds(acled_comp_week, file.path(out_dir, "acled_comp_week.rds"), compress = "gz")

  readr::write_rds(ccc_week, file.path(out_dir, "ccc_week.rds"), compress = "gz")
  readr::write_rds(ccc_week_state, file.path(out_dir, "ccc_week_state.rds"), compress = "gz")
  readr::write_rds(ccc_comp_week, file.path(out_dir, "ccc_comp_week.rds"), compress = "gz")

  readr::write_rds(joined_week, file.path(out_dir, "joined_week.rds"), compress = "gz")
  readr::write_rds(joined_week_state, file.path(out_dir, "joined_week_state.rds"), compress = "gz")

  meta <- data.frame(
    prepared_at = Sys.time(),
    acled_source = acled_xlsx,
    ccc_sources = paste(ccc_paths, collapse = "; "),
    notes = paste0(
      "US-only filter: ACLED country==United States; CCC state in state.abb. ",
      "Week alignment: ACLED WEEK is Saturday-dated in this file; CCC maps each event date to the Saturday label via floor_date(date + 1 day, week, week_start=6). ",
      "State alignment: ACLED ADMIN1 full state names are mapped to USPS abbreviations; District of Columbia maps to DC. ",
      "CCC schemas differ across files; ccc_category is coalesce(type) for compiled files and event_type for phase3."
    ),
    stringsAsFactors = FALSE
  )
  readr::write_rds(meta, file.path(out_dir, "meta.rds"), compress = "gz")

  message("Wrote prepared summaries to: ", normalizePath(out_dir))
  invisible(out_dir)
}
