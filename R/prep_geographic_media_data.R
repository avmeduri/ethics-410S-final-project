prep_geographic_media_data <- function(
  ccc_dir = "data/ccc",
  out_dir = "data/prepared"
) {
  if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

  # Required packages
  required_pkgs <- c("dplyr", "tidyr", "readr", "lubridate", "stringr", 
                     "purrr", "leaflet", "sf", "units", "scales")
  for (pkg in required_pkgs) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      stop("Missing package: ", pkg)
    }
  }

  `%>%` <- dplyr::`%>%`

  # Read CCC data
  message("Reading CCC data files...")
  ccc_paths <- c(
    file.path(ccc_dir, "ccc_compiled_20172020.csv"),
    file.path(ccc_dir, "ccc_compiled_20212024.csv"),
    file.path(ccc_dir, "ccc-phase3-public.csv")
  )
  
  read_ccc_csv <- function(path) {
    message("Reading: ", basename(path))
    readr::read_csv(
      file = path,
      show_col_types = FALSE,
      progress = FALSE,
      locale = readr::locale(encoding = "latin1")
    )
  }

  ccc_1720 <- read_ccc_csv(ccc_paths[[1]])
  ccc_2124 <- read_ccc_csv(ccc_paths[[2]])
  ccc_p3 <- read_ccc_csv(ccc_paths[[3]])

  # Normalize CCC data
  normalize_ccc_full <- function(df, source) {
    df <- dplyr::rename_with(df, tolower)
    
    is_phase3 <- grepl("phase3", source, fixed = TRUE)
    
    if (is_phase3) {
      return(
        df %>%
          dplyr::transmute(
            source = source,
            date = lubridate::as_date(.data$date, format = "%m/%d/%Y"),
            locality = dplyr::coalesce(.data$locality, .data$resolved_locality),
            state = as.character(.data$resolved_state),
            lat = as.numeric(.data$lat),
            lon = as.numeric(.data$lon),
            event_type = dplyr::coalesce(as.character(.data$event_type), "unknown"),
            organizations = dplyr::coalesce(as.character(.data$organizations), ""),
            participants = dplyr::coalesce(as.character(.data$participants), ""),
            claims_summary = dplyr::coalesce(as.character(.data$claims_summary), ""),
            issues = dplyr::coalesce(as.character(.data$issues), ""),
            valence = as.numeric(.data$valence),
            online = as.numeric(.data$online),
            size_text = dplyr::coalesce(as.character(.data$size_text), ""),
            arrests = as.numeric(.data$arrests),
            property_damage = as.numeric(.data$property_damage),
            notes = dplyr::coalesce(as.character(.data$notes), ""),
            # Extract all source columns
            !!!dplyr::select(df, dplyr::starts_with("source")) %>% 
              purrr::set_names(~paste0("source_", seq_along(.)))
          )
      )
    }
    
    # Compiled files (also contain resolved_* fields; do not use the phase3 parser)
    if (!all(c("date", "state", "type") %in% names(df))) {
      stop("Unexpected CCC compiled schema for file: ", source)
    }
    
    # Check if this file uses 'actors' or 'organizations' column
    org_col <- if ("actors" %in% names(df)) "actors" else "organizations"
    claims_col <- if ("claims_summary" %in% names(df)) "claims_summary" else "claims"
    issues_col <- if ("issue_tags" %in% names(df)) "issue_tags" else "issues"
    
    df %>%
      dplyr::transmute(
        source = source,
        date = lubridate::as_date(.data$date),
        locality = dplyr::coalesce(.data$locality, .data$resolved_locality),
        state = as.character(.data$state),
        lat = as.numeric(.data$lat),
        lon = as.numeric(.data$lon),
        event_type = dplyr::coalesce(as.character(.data$type), "unknown"),
        organizations = dplyr::coalesce(as.character(.data[[org_col]]), ""),
        participants = dplyr::coalesce(as.character(.data$size_text), ""),
        claims_summary = dplyr::coalesce(as.character(.data[[claims_col]]), ""),
        issues = dplyr::coalesce(as.character(.data[[issues_col]]), ""),
        valence = as.numeric(.data$valence),
        online = as.numeric(.data$online),
        size_text = dplyr::coalesce(as.character(.data$size_text), ""),
        arrests = as.numeric(.data$arrests_any),
        property_damage = as.numeric(.data$property_damage_any),
        notes = dplyr::coalesce(as.character(.data$notes), ""),
        # Extract all source columns
        !!!dplyr::select(df, dplyr::starts_with("source_")) %>% 
          purrr::set_names(~paste0("source_", seq_along(.)))
      )
  }

  # Combine all CCC data
  message("Combining and processing CCC data...")
  ccc_full <- dplyr::bind_rows(
    normalize_ccc_full(ccc_1720, "ccc_compiled_20172020.csv"),
    normalize_ccc_full(ccc_2124, "ccc_compiled_20212024.csv"),
    normalize_ccc_full(ccc_p3, "ccc-phase3-public.csv")
  ) %>%
    dplyr::filter(!is.na(.data$date), !is.na(.data$state)) %>%
    dplyr::mutate(
      state = stringr::str_trim(.data$state),
      state = dplyr::if_else(.data$state == "Washington DC", "DC", .data$state),
      year = lubridate::year(.data$date),
      month = lubridate::month(.data$date),
      # Clean up organizations
      organizations = stringr::str_replace_all(.data$organizations, ";\\s*", "; "),
      organizations = stringr::str_trim(.data$organizations),
      # Count sources
      source_cols = purrr::keep(names(.), ~grepl("^source_", .x)),
      n_sources = rowSums(!is.na(dplyr::select(., dplyr::all_of(.data$source_cols)))),
      # Urban classification (simplified - using population density proxy)
      urban = dplyr::case_when(
        .data$state %in% c("CA", "NY", "TX", "FL", "IL", "PA", "OH", "GA", "NC", "MI") ~ TRUE,
        TRUE ~ FALSE
      ),
      # Issue categorization
      main_issue = dplyr::case_when(
        stringr::str_detect(.data$issues, "policing|police") ~ "Policing",
        stringr::str_detect(.data$issues, "environment|climate|energy") ~ "Environment", 
        stringr::str_detect(.data$issues, "foreign|war|military") ~ "Foreign Affairs",
        stringr::str_detect(.data$issues, "economy|banking|finance") ~ "Economy",
        stringr::str_detect(.data$issues, "health|medical") ~ "Healthcare",
        stringr::str_detect(.data$issues, "education|school") ~ "Education",
        stringr::str_detect(.data$issues, "immigration") ~ "Immigration",
        TRUE ~ "Other"
      )
    ) %>%
    dplyr::filter(.data$state %in% c(state.abb, "DC"))

  # Create geographic summaries
  message("Creating geographic summaries...")
  geo_summary <- ccc_full %>%
    dplyr::filter(!is.na(.data$lat), !is.na(.data$lon)) %>%
    dplyr::group_by(.data$state, .data$urban) %>%
    dplyr::summarise(
      n_events = n(),
      n_with_sources = sum(.data$n_sources > 0, na.rm = TRUE),
      mean_sources = mean(.data$n_sources, na.rm = TRUE),
      n_online = sum(.data$online == 1, na.rm = TRUE),
      n_arrests = sum(.data$arrests > 0, na.rm = TRUE),
      n_property_damage = sum(.data$property_damage > 0, na.rm = TRUE),
      unique_organizations = n_distinct(.data$organizations),
      .groups = "drop"
    ) %>%
    dplyr::mutate(
      source_coverage_rate = .data$n_with_sources / .data$n_events,
      online_rate = .data$n_online / .data$n_events,
      arrest_rate = .data$n_arrests / .data$n_events,
      damage_rate = .data$n_property_damage / .data$n_events
    )

  # Create temporal summaries
  message("Creating temporal summaries...")
  temporal_summary <- ccc_full %>%
    dplyr::group_by(.data$year, .data$month, .data$main_issue, .data$online) %>%
    dplyr::summarise(
      n_events = n(),
      mean_sources = mean(.data$n_sources, na.rm = TRUE),
      n_states = n_distinct(.data$state),
      .groups = "drop"
    ) %>%
    dplyr::mutate(date = lubridate::make_date(.data$year, .data$month))

  # Create organizational analysis
  message("Creating organizational analysis...")
  org_analysis <- ccc_full %>%
    dplyr::filter(.data$organizations != "") %>%
    dplyr::mutate(
      org_list = stringr::str_split(.data$organizations, ";\\s*")
    ) %>%
    tidyr::unnest(.data$org_list) %>%
    dplyr::mutate(org_list = stringr::str_trim(.data$org_list)) %>%
    dplyr::filter(.data$org_list != "", !is.na(.data$org_list)) %>%
    dplyr::group_by(.data$org_list, .data$state, .data$main_issue) %>%
    dplyr::summarise(
      n_events = n(),
      n_states = n_distinct(.data$state),
      mean_sources = mean(.data$n_sources, na.rm = TRUE),
      online_events = sum(.data$online == 1, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    dplyr::rename(organization = .data$org_list) %>%
    dplyr::arrange(dplyr::desc(.data$n_events))

  # Create media coverage analysis
  message("Creating media coverage analysis...")
  media_analysis <- ccc_full %>%
    dplyr::group_by(.data$main_issue, .data$event_type, .data$urban, .data$online) %>%
    dplyr::summarise(
      n_events = n(),
      mean_sources = mean(.data$n_sources, na.rm = TRUE),
      median_sources = median(.data$n_sources, na.rm = TRUE),
      max_sources = max(.data$n_sources, na.rm = TRUE),
      source_coverage_rate = mean(.data$n_sources > 0, na.rm = TRUE),
      .groups = "drop"
    )

  # Create coordinate data for mapping
  message("Creating coordinate data for mapping...")
  coords_for_map <- ccc_full %>%
    dplyr::filter(!is.na(.data$lat), !is.na(.data$lon)) %>%
    dplyr::select(
      .data$date, .data$state, .data$locality, .data$lat, .data$lon,
      .data$event_type, .data$main_issue, .data$n_sources, .data$online,
      .data$urban, .data$arrests, .data$property_damage
    )

  # Save prepared data
  message("Saving prepared data...")
  readr::write_rds(ccc_full, file.path(out_dir, "ccc_full_geographic.rds"), compress = "gz")
  readr::write_rds(geo_summary, file.path(out_dir, "geographic_summary.rds"), compress = "gz")
  readr::write_rds(temporal_summary, file.path(out_dir, "temporal_summary.rds"), compress = "gz")
  readr::write_rds(org_analysis, file.path(out_dir, "organizational_analysis.rds"), compress = "gz")
  readr::write_rds(media_analysis, file.path(out_dir, "media_analysis.rds"), compress = "gz")
  readr::write_rds(coords_for_map, file.path(out_dir, "coordinates_for_map.rds"), compress = "gz")

  # Create metadata
  meta <- data.frame(
    prepared_at = Sys.time(),
    ccc_sources = paste(ccc_paths, collapse = "; "),
    total_events = nrow(ccc_full),
    date_range = paste(min(ccc_full$date), "to", max(ccc_full$date)),
    states_covered = length(unique(ccc_full$state)),
    organizations = nrow(org_analysis),
    notes = "Geographic and media coverage analysis prepared for dashboard visualization. Urban classification simplified by state population. Issue categorization based on keyword matching.",
    stringsAsFactors = FALSE
  )
  readr::write_rds(meta, file.path(out_dir, "geographic_meta.rds"), compress = "gz")

  message("Geographic and media data preparation complete!")
  message("Total events processed: ", nrow(ccc_full))
  message("Date range: ", min(ccc_full$date), " to ", max(ccc_full$date))
  message("States covered: ", length(unique(ccc_full$state)))
  
  invisible(out_dir)
}
