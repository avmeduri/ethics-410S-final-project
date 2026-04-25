user_lib <- Sys.getenv("R_LIBS_USER")
if (identical(user_lib, "")) {
  user_lib <- file.path(path.expand("~"), "Library", "R", "arm64", "4.5", "library")
  Sys.setenv(R_LIBS_USER = user_lib)
}

if (is.null(getOption("repos")) || identical(getOption("repos")[["CRAN"]], "@CRAN@")) {
  options(repos = c(CRAN = "https://cloud.r-project.org"))
}

if (!dir.exists(user_lib)) dir.create(user_lib, recursive = TRUE, showWarnings = FALSE)
.libPaths(unique(c(user_lib, .libPaths())))

pkgs <- c(
  "shiny",
  "shinydashboard",
  "shinydashboardPlus",
  "ggplot2",
  "dplyr",
  "tidyr",
  "readr",
  "readxl",
  "lubridate",
  "stringr",
  "scales",
  "leaflet",
  "plotly",
  "DT",
  "purrr",
  "sf",
  "units",
  "fontawesome"
)

need <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
if (length(need) > 0) {
  install.packages(need, lib = user_lib)
}

message("OK: dashboard dependencies installed/available.")
