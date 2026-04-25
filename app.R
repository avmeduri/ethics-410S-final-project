library(shiny)
library(shinydashboard)
library(ggplot2)
library(plotly)
library(dplyr)
library(readr)
library(scales)
library(leaflet)
library(DT)
library(lubridate)
library(tidyr)
library(shinycssloaders)


prep_paths <- function() {
  list(
    ccc_full        = file.path("data", "prepared", "ccc_events_with_media_sources.rds"),
    geo_summary     = file.path("data", "prepared", "ccc_geographic_summary.rds"),
    temporal_summary = file.path("data", "prepared", "ccc_temporal_summary.rds"),
    org_analysis    = file.path("data", "prepared", "ccc_organizational_analysis.rds"),
    coords_for_map  = file.path("data", "prepared", "ccc_coordinates_for_map.rds"),
    meta            = file.path("data", "prepared", "ccc_dataset_metadata.rds"),
    acled_comp_week = file.path("data", "prepared", "acled_protests_weekly.rds"),
    ccc_week        = file.path("data", "prepared", "ccc_events_weekly.rds")
  )
}

load_if_exists <- function(path) {
  if (file.exists(path)) readr::read_rds(path) else NULL
}

COL <- list(
  blue   = "#2980b9",
  dark   = "#2c3e50",
  red    = "#c0392b",
  gray   = "#7f8c8d",
  ltgray = "#bdc3c7",
  green  = "#27ae60",
  orange = "#e67e22"
)

plot_theme <- function(base_size = 13) {
  theme_minimal(base_size = base_size) %+replace%
    theme(
      plot.background   = element_rect(fill = "white", color = NA),
      panel.background  = element_rect(fill = "white", color = NA),
      panel.grid.major  = element_line(color = "#e8e8e8", linewidth = 0.4),
      panel.grid.minor  = element_blank(),
      axis.title        = element_text(color = COL$dark, size = rel(0.9)),
      axis.text         = element_text(color = "#444"),
      plot.title        = element_text(color = COL$dark, face = "bold", size = rel(1.05)),
      plot.subtitle     = element_text(color = COL$gray, size = rel(0.82), margin = margin(b = 8)),
      plot.margin       = margin(10, 12, 10, 12),
      strip.text        = element_text(color = COL$dark, face = "bold"),
      legend.title      = element_text(size = rel(0.85)),
      legend.text       = element_text(size = rel(0.8))
    )
}

to_plotly <- function(p) {
  ggplotly(p, tooltip = "text") |>
    plotly::config(displayModeBar = FALSE) |>
    plotly::layout(
      font = list(family = "Helvetica Neue, Arial, sans-serif"),
      hoverlabel = list(bgcolor = "white", font = list(size = 12))
    )
}

desc_style <- "color: #555; font-size: 0.9em; margin-bottom: 10px; line-height: 1.5;"

clean_event_type <- function(x) {
  x <- gsub(";\\s*", " & ", x)
  tools::toTitleCase(x)
}

filter_panel <- fluidRow(
  box(
    title = "Filters", status = "primary", solidHeader = TRUE,
    width = 12, collapsible = TRUE, collapsed = FALSE,
    column(3, dateRangeInput("date_range", "Time Period")),
    column(2, selectInput("issues", "Issue", choices = "All", multiple = TRUE)),
    column(2, selectInput("event_types", "Event Type", choices = "All", multiple = TRUE)),
    column(3,
      checkboxGroupInput("geography", "Location",
                        choices = c("Urban" = "urban", "Rural" = "rural",
                                    "Online only" = "online", "All" = "all"),
                        selected = "all", inline = TRUE)
    ),
    column(2,
      tags$div(style = "margin-top: 25px;",
        actionButton("apply_filters", "Apply Filters",
                     icon = icon("filter"),
                     class = "btn-primary",
                     style = paste0("background-color: ", COL$blue, "; ",
                                    "color: white; border: none; font-weight: 600; ",
                                    "border-radius: 4px; width: 100%; margin-bottom: 5px;")),
        downloadButton("download_data", "Export Data",
                       style = "width: 100%; font-size: 12px;")
      )
    )
  )
)


ui <- dashboardPage(
  skin = "blue",
  dashboardHeader(
    title = tags$span(icon("bullhorn"), " U.S. Protest Media Coverage"),
    titleWidth = 280,
    tags$li(class = "dropdown",
      tags$a(href = "#", style = "padding: 10px 15px; color: white; font-size: 13px;",
             icon("eye"), " Analyzing Media Visibility Across 138K+ Events")
    )
  ),

  dashboardSidebar(
    width = 250,
    sidebarMenu(id = "active_tab",
      menuItem("Key Findings",             tabName = "findings",  icon = icon("lightbulb")),
      menuItem("CCC vs. ACLED Comparison", tabName = "gap",       icon = icon("chart-line")),
      menuItem("Spatial Coverage",         tabName = "map",       icon = icon("map")),
      menuItem("What Gets Covered?",       tabName = "coverage",  icon = icon("newspaper")),
      menuItem("Geography of Visibility",  tabName = "geography", icon = icon("globe-americas")),
      menuItem("Coverage Over Time",       tabName = "time",      icon = icon("clock")),
      menuItem("About the Data",           tabName = "about",     icon = icon("info-circle"))
    )
  ),

  dashboardBody(

    tags$head(tags$style(HTML(paste0("
      .sidebar .checkbox label,
      .sidebar .checkbox-inline label,
      .sidebar .radio label,
      .sidebar .radio-inline label {
        color: #b8c7ce !important;
        font-weight: 400 !important;
      }
      .sidebar .checkbox-inline { margin-right: 10px; }
      .content-wrapper { background-color: #ecf0f5; }
      .box.box-solid.box-primary > .box-header {
        background-color: ", COL$dark, ";
        border-color: ", COL$dark, ";
      }
      .box.box-solid.box-primary {
        border-color: ", COL$dark, ";
      }
      .box { border-radius: 4px; margin-bottom: 20px; }
      .nav-tabs-custom > .tab-content { padding: 15px; }
      .content-wrapper > .content { padding: 20px; }
      .box .box-body { padding: 15px; }
      .row.equal-height { display: flex; flex-wrap: wrap; }
      .row.equal-height > [class*='col-'] { display: flex; flex-direction: column; }
      .row.equal-height .box { flex: 1; min-height: 0; }
      .row.equal-height .box .box-body { min-height: 0; overflow: hidden; }
      .js-plotly-plot, .plotly { width: 100% !important; }
      .plotly .main-svg { width: 100% !important; }
    ")))),

    tags$script(HTML("
      $(document).ready(function() {
        setTimeout(function() { $(window).trigger('resize'); }, 500);
        $('body').on('click', '.sidebar-menu a, .treeview-menu a', function() {
          setTimeout(function() { $(window).trigger('resize'); }, 200);
          setTimeout(function() { $(window).trigger('resize'); }, 500);
          setTimeout(function() {
            $('.js-plotly-plot').each(function() {
              Plotly.Plots.resize(this);
            });
          }, 600);
        });
      });
    ")),

    conditionalPanel(
      condition = "input.active_tab == 'map' || input.active_tab == 'coverage' || input.active_tab == 'geography' || input.active_tab == 'time'",
      filter_panel
    ),

    tabItems(

      tabItem(tabName = "findings",
        fluidRow(
          box(
            width = 12, status = "primary", solidHeader = TRUE,
            title = "What Shapes Which Protests Get Media Coverage?",
            p(tags$strong("Core argument: "),
              "Protest visibility is structured by resources, geography, framing, and political context. ",
              "This dashboard draws on two datasets: the ",
              tags$strong("Crowd Counting Consortium (CCC)"),
              ", which aims to record every U.S. protest event and tracks how many distinct media outlets ",
              "cover each one, and ",
              tags$strong("ACLED"),
              " (Armed Conflict Location & Event Data Project), an expert-curated dataset used by researchers ",
              "and policymakers. The CCC's media source count is the primary measure of visibility throughout ",
              "this dashboard. The comparison between CCC and ACLED reveals a persistent gap between ",
              "protests that occur and those that enter institutional records. ",
              "Across over 138,000 events, the findings below show that which protests become ",
              "visible is shaped not by whether they occur, but by ",
              tags$em("who"), " organizes them, ", tags$em("where"), " they happen, ",
              tags$em("what"), " they demand, and ", tags$em("when"), " they erupt.",
              style = "font-size: 1.05em; line-height: 1.7; color: #333;")
          )
        ),
        tags$h4("How Concentrated Is Media Coverage?",
          style = "margin: 5px 0 10px 15px; color: #2c3e50; font-weight: 600;"),
        fluidRow(
          valueBoxOutput("vb_total_events", width = 3),
          valueBoxOutput("vb_single_source", width = 3),
          valueBoxOutput("vb_five_plus", width = 3),
          valueBoxOutput("vb_median_sources", width = 3)
        ),
        tags$h4("What Drives Media Visibility?",
          style = "margin: 15px 0 10px 15px; color: #2c3e50; font-weight: 600;"),
        fluidRow(
          valueBoxOutput("vb_arrests_effect", width = 3),
          valueBoxOutput("vb_org_effect", width = 3),
          valueBoxOutput("vb_size_effect", width = 3),
          valueBoxOutput("vb_urban_effect", width = 3)
        ),
        tags$h4("Findings by Theme",
          style = "margin: 15px 0 10px 15px; color: #2c3e50; font-weight: 600;"),
        fluidRow(class = "equal-height",
          box(
            title = tags$span(icon("chart-line"), " CCC vs ACLED: What Gets Recorded?"),
            status = "primary", solidHeader = TRUE, width = 4,
            uiOutput("findings_legibility")
          ),
          box(
            title = tags$span(icon("cogs"), " Resources & Characteristics"),
            status = "primary", solidHeader = TRUE, width = 4,
            uiOutput("findings_resources")
          ),
          box(
            title = tags$span(icon("newspaper"), " Framing & Political Context"),
            status = "primary", solidHeader = TRUE, width = 4,
            uiOutput("findings_framing")
          )
        ),
        fluidRow(
          box(
            width = 12,
            p(icon("arrow-right"), " Explore each tab in the sidebar for interactive visualizations with full detail.",
              style = "text-align: center; color: #555; font-style: italic; margin: 0;")
          )
        )
      ),

      tabItem(tabName = "gap",
        fluidRow(
          box(
            title = "How Many Protests Make It Into Institutional Records?",
            status = "primary", solidHeader = TRUE, width = 12,
            p("Institutions act on what they can measure. This chart compares two independent protest ",
              "datasets during their overlapping coverage period to show the difference ",
              "between protests that occur and protests that enter institutional records. ",
              "The Crowd Counting Consortium (CCC) aims to record every U.S. protest event. ",
              "ACLED is an expert-curated dataset used by researchers and policymakers to inform decisions. ",
              "To ensure a fair comparison, ACLED is filtered to protest events only ",
              "(excluding riots, strategic developments, and other non-protest categories), ",
              "and only weeks where both datasets have data are shown. ",
              "The persistent gap between these records represents protests that are politically invisible ",
              "to the institutions that rely on curated data.",
              style = desc_style),
            withSpinner(plotlyOutput("gap_lines_plot", height = "420px"), type = 6, color = "#2980b9")
          )
        ),
        fluidRow(
          box(
            title = "The Gap: CCC Events Minus ACLED Protest Events per Week",
            status = "primary", solidHeader = TRUE, width = 12,
            p("Positive values (blue) indicate weeks where CCC recorded more protest events ",
              "than ACLED. Negative values (red) indicate weeks where ACLED recorded more. ",
              "Persistent positive gaps suggest protests that CCC captures but do not appear ",
              "in the curated institutional record.",
              style = desc_style),
            withSpinner(plotlyOutput("gap_area_plot", height = "360px"), type = 6, color = "#2980b9")
          )
        ),
        fluidRow(
          box(
            title = "Summary",
            status = "primary", solidHeader = TRUE, width = 12,
            verbatimTextOutput("gap_summary")
          )
        )
      ),

      tabItem(tabName = "map",
        fluidRow(
          box(
            title = "Where Does Media Cover Protests?",
            status = "primary", solidHeader = TRUE, width = 12,
            p("Each point is a protest event. Point size reflects the number of media sources ",
              "that reported on that event. Larger points received more media coverage.",
              style = desc_style),
            withSpinner(leafletOutput("protest_map", height = "540px"), type = 6, color = "#2980b9"),
            hr(),
            verbatimTextOutput("map_info")
          )
        )
      ),

      tabItem(tabName = "coverage",
        fluidRow(
          column(6,
            selectInput("coverage_chart", "Select Visualization:",
              choices = c(
                "How Concentrated Is Visibility?" = "visibility_dist",
                "Average Media Sources by Issue" = "issue_mean",
                "Distribution of Media Sources by Issue" = "issue_box",
                "Coverage by Detailed Issue Combination" = "sub_issues",
                "Average Media Sources by Event Type (Top 10)" = "trait_type",
                "Media Coverage: Arrests and Property Damage" = "trait_arrest_damage",
                "Media Coverage: Organizations" = "trait_orgs",
                "Does Repression Amplify Visibility?" = "repression",
                "Media Coverage by Protest Valence" = "valence",
                "Does Protest Size Drive Coverage?" = "size_coverage",
                "Which Claims Get Media Attention?" = "claims_coverage"
              ),
              selected = "visibility_dist",
              width = "100%"
            )
          )
        ),
        conditionalPanel(
          condition = "input.coverage_chart == 'visibility_dist'",
          fluidRow(
            box(
              title = "The Distribution of Media Visibility",
              status = "primary", solidHeader = TRUE, width = 12,
              p("How many media sources cover each protest event? The bars show the number of events ",
                "at each level of media coverage. The red line tracks the cumulative percentage. ",
                "Most protests receive minimal media attention: over half are covered by a single source, ",
                "and fewer than 6% receive coverage from five or more outlets.",
                style = desc_style),
              withSpinner(plotlyOutput("visibility_dist_plot", height = "420px"), type = 6, color = "#2980b9")
            )
          )
        ),
        conditionalPanel(
          condition = "input.coverage_chart == 'issue_mean'",
          fluidRow(
            box(
              title = "Average Media Sources per Event by Issue",
              status = "primary", solidHeader = TRUE, width = 12,
              p("Mean number of media sources covering each protest event, grouped by issue category.",
                style = desc_style),
              withSpinner(plotlyOutput("issue_mean_plot", height = "400px"), type = 6, color = "#2980b9")
            )
          )
        ),
        conditionalPanel(
          condition = "input.coverage_chart == 'issue_box'",
          fluidRow(
            box(
              title = "Distribution of Media Sources by Issue",
              status = "primary", solidHeader = TRUE, width = 12,
              p("Spread of media source counts within each issue category. ",
                "Shows how consistently events within an issue are covered.",
                style = desc_style),
              withSpinner(plotlyOutput("issue_box_plot", height = "400px"), type = 6, color = "#2980b9")
            )
          )
        ),
        conditionalPanel(
          condition = "input.coverage_chart == 'sub_issues'",
          fluidRow(
            column(4,
              selectInput("sub_issue_category", "Filter by Main Category:",
                choices = c("All Categories" = "all"),
                width = "100%"
              )
            )
          ),
          fluidRow(
            box(
              title = "Media Coverage by Detailed Issue Combination",
              status = "primary", solidHeader = TRUE, width = 12,
              p("Average media sources for the most common specific issue combinations within each category. ",
                "Select a main category above to drill down. Issue tags like 'policing + racism' or ",
                "'covid + healthcare + racism' reveal which specific grievance combinations attract more ",
                "media attention, and which remain less visible even within the same broad category.",
                style = desc_style),
              withSpinner(plotlyOutput("sub_issue_plot", height = "480px"), type = 6, color = "#2980b9")
            )
          )
        ),
        conditionalPanel(
          condition = "input.coverage_chart == 'trait_type'",
          fluidRow(
            box(
              title = "Average Media Sources by Event Type (Top 10)",
              status = "primary", solidHeader = TRUE, width = 12,
              p("Average number of media sources per event for the 10 most common event types.",
                style = desc_style),
              withSpinner(plotlyOutput("trait_type_plot", height = "380px"), type = 6, color = "#2980b9")
            )
          )
        ),
        conditionalPanel(
          condition = "input.coverage_chart == 'trait_arrest_damage'",
          fluidRow(class = "equal-height",
            box(
              title = "Media Coverage: Events with vs without Arrests",
              status = "primary", solidHeader = TRUE, width = 6,
              p("Average media sources for events where arrests were reported ",
                "versus events without arrests.",
                style = desc_style),
              withSpinner(plotlyOutput("trait_arrests_plot", height = "380px"), type = 6, color = "#2980b9")
            ),
            box(
              title = "Media Coverage: Events with vs without Property Damage",
              status = "primary", solidHeader = TRUE, width = 6,
              p("Average media sources for events where property damage was reported ",
                "versus events without property damage.",
                style = desc_style),
              withSpinner(plotlyOutput("trait_damage_plot", height = "380px"), type = 6, color = "#2980b9")
            )
          )
        ),
        conditionalPanel(
          condition = "input.coverage_chart == 'trait_orgs'",
          fluidRow(class = "equal-height",
            box(
              title = "Media Coverage: Organized vs Unorganized Events",
              status = "primary", solidHeader = TRUE, width = 6,
              p("Average media sources for events with at least one named organization ",
                "versus events with no organizational affiliation recorded.",
                style = desc_style),
              withSpinner(plotlyOutput("trait_org_plot", height = "380px"), type = 6, color = "#2980b9")
            ),
            box(
              title = "Top 15 Organizations by Media Coverage",
              status = "primary", solidHeader = TRUE, width = 6,
              p("Organizations with the highest average media sources per event, ",
                "among those with at least 50 recorded events.",
                style = desc_style),
              withSpinner(plotlyOutput("trait_org_top_plot", height = "380px"), type = 6, color = "#2980b9")
            )
          )
        ),
        conditionalPanel(
          condition = "input.coverage_chart == 'repression'",
          fluidRow(
            box(
              title = "Does Repression Amplify Visibility?",
              status = "primary", solidHeader = TRUE, width = 12,
              p("Average media sources for protests grouped by whether arrests and/or property damage ",
                "were reported. Events involving both forms of repression receive dramatically more ",
                "coverage, suggesting that state responses and disruption make protests more legible to media.",
                style = desc_style),
              withSpinner(plotlyOutput("repression_plot", height = "380px"), type = 6, color = "#2980b9")
            )
          )
        ),
        conditionalPanel(
          condition = "input.coverage_chart == 'valence'",
          fluidRow(
            box(
              title = "Media Coverage by Protest Valence",
              status = "primary", solidHeader = TRUE, width = 12,
              p("Media coverage by coded political valence. Bars show the mean; diamonds show the median; ",
                "horizontal ticks show the 25th and 75th percentiles. ",
                "Valence captures the political orientation of participants: left-leaning (e.g., social justice, ",
                "climate), right-leaning (e.g., anti-mandate, gun rights), or unclassified. ",
                "Differences in coverage by valence suggest media framing may shape which political ",
                "perspectives become visible.",
                style = desc_style),
              withSpinner(plotlyOutput("valence_plot", height = "380px"), type = 6, color = "#2980b9")
            )
          )
        ),
        conditionalPanel(
          condition = "input.coverage_chart == 'size_coverage'",
          fluidRow(
            box(
              title = "Does Protest Size Drive Media Coverage?",
              status = "primary", solidHeader = TRUE, width = 12,
              p("Average media sources per event by protest size category. ",
                "Larger protests receive dramatically more media coverage than smaller ones. ",
                "This directly supports the resource mobilization argument: movements that can ",
                "mobilize more people (which requires organizational resources, infrastructure, ",
                "and coordination) become far more visible to media. Size data is available for ",
                "about one-third of all events.",
                style = desc_style),
              withSpinner(plotlyOutput("size_coverage_plot", height = "420px"), type = 6, color = "#2980b9")
            )
          )
        ),
        conditionalPanel(
          condition = "input.coverage_chart == 'claims_coverage'",
          fluidRow(
            box(
              title = "Which Claims Get Media Attention?",
              status = "primary", solidHeader = TRUE, width = 12,
              p("Average media sources per event for the most common protest claims. ",
                "Not all grievances receive equal media attention. Claims that align with ongoing ",
                "news cycles or involve visible conflict tend to attract more coverage, while routine ",
                "or less dramatic demands remain less visible regardless of how many events raise them.",
                style = desc_style),
              withSpinner(plotlyOutput("claims_coverage_plot", height = "480px"), type = 6, color = "#2980b9")
            )
          )
        )
      ),

      tabItem(tabName = "geography",
        fluidRow(
          column(6,
            selectInput("geography_chart", "Select Visualization:",
              choices = c(
                "Urban vs Rural Coverage by Issue" = "geo_urban_rural",
                "Average Media Sources by State (Top 20)" = "geo_state",
                "Event Volume vs Coverage by State" = "geo_scatter"
              ),
              selected = "geo_urban_rural",
              width = "100%"
            )
          )
        ),
        conditionalPanel(
          condition = "input.geography_chart == 'geo_urban_rural'",
          fluidRow(
            box(
              title = "Media Coverage: Urban vs Rural by Issue",
              status = "primary", solidHeader = TRUE, width = 12,
              p("Average number of media sources per event, comparing urban and rural locations ",
                "within each issue category.",
                style = desc_style),
              withSpinner(plotlyOutput("geo_urban_rural_plot", height = "400px"), type = 6, color = "#2980b9")
            )
          )
        ),
        conditionalPanel(
          condition = "input.geography_chart == 'geo_state'",
          fluidRow(
            box(
              title = "Average Media Sources by State (Top 20 by Event Volume)",
              status = "primary", solidHeader = TRUE, width = 12,
              p("Mean number of media sources per protest event for the 20 states with the most events.",
                style = desc_style),
              withSpinner(plotlyOutput("geo_state_sources_plot", height = "400px"), type = 6, color = "#2980b9")
            )
          )
        ),
        conditionalPanel(
          condition = "input.geography_chart == 'geo_scatter'",
          fluidRow(
            box(
              title = "Event Volume vs Average Coverage by State",
              status = "primary", solidHeader = TRUE, width = 12,
              p("Each point is a state. The x-axis shows total protest events; the y-axis shows the ",
                "average number of media sources per event in that state. Point size reflects the percentage ",
                "of that state's protests occurring in urban areas.",
                style = desc_style),
              withSpinner(plotlyOutput("geo_scatter_plot", height = "420px"), type = 6, color = "#2980b9")
            )
          )
        )
      ),

      tabItem(tabName = "time",
        fluidRow(
          column(6,
            selectInput("time_chart", "Select Visualization:",
              choices = c(
                "Monthly Average Media Sources per Event" = "time_trend",
                "Monthly Average by Issue (Top 5)" = "time_issue",
                "Protest Volume Around Key Political Moments" = "political_opportunity"
              ),
              selected = "time_trend",
              width = "100%"
            )
          )
        ),
        conditionalPanel(
          condition = "input.time_chart == 'time_trend'",
          fluidRow(
            box(
              title = "Monthly Average Media Sources per Event",
              status = "primary", solidHeader = TRUE, width = 12,
              p("Average number of media sources per protest event by month. ",
                "The gray bars show total event volume for context.",
                style = desc_style),
              withSpinner(plotlyOutput("time_trend_plot", height = "400px"), type = 6, color = "#2980b9")
            )
          )
        ),
        conditionalPanel(
          condition = "input.time_chart == 'time_issue'",
          fluidRow(
            box(
              title = "Monthly Average Media Sources by Issue (Top 5 Issues)",
              status = "primary", solidHeader = TRUE, width = 12,
              p("Average media sources per event over time for the five issue categories with ",
                "the most total events. Limited to top 5 for readability.",
                style = desc_style),
              withSpinner(plotlyOutput("time_issue_plot", height = "420px"), type = 6, color = "#2980b9")
            )
          )
        ),
        conditionalPanel(
          condition = "input.time_chart == 'political_opportunity'",
          fluidRow(
            box(
              title = "Protest Volume and Coverage Around Key Political Moments",
              status = "primary", solidHeader = TRUE, width = 12,
              p("Weekly protest event counts with annotations for major political moments. ",
                "Spikes in volume and coverage around these events reflect political opportunity ",
                "structures (i.e., windows when grievances become actionable and protests become more ",
                "legible to institutions and media).",
                style = desc_style),
              withSpinner(plotlyOutput("political_opportunity_plot", height = "550px"), type = 6, color = "#2980b9")
            )
          )
        )
      ),

      tabItem(tabName = "about",
        fluidRow(
          box(
            title = "About This Dashboard", status = "primary", solidHeader = TRUE, width = 12,
            h4("Datasets"),
            tags$div(style = "margin-bottom: 15px;",
              tags$strong("Crowd Counting Consortium (CCC)"),
              p("A near-comprehensive record of U.S. protest events maintained by researchers at ",
                "Harvard Kennedy School and the University of Connecticut. CCC aims to capture every ",
                "protest event regardless of size or media attention. Each event includes a count of ",
                "distinct media sources that covered it (the ", tags$code("n_sources"), " variable), ",
                "which this dashboard uses as the primary measure of media visibility.",
                style = "margin-top: 4px;")
            ),
            tags$div(style = "margin-bottom: 15px;",
              tags$strong("ACLED (Armed Conflict Location & Event Data Project)"),
              p("An expert-curated dataset of political events worldwide, used by researchers, ",
                "policymakers, and journalists. ACLED records protests, riots, strategic developments, ",
                "and other political events. In the CCC vs ACLED Comparison tab, ACLED is filtered to protest ",
                "events only (Peaceful protest and Protest with intervention) to enable a fair comparison ",
                "with CCC.",
                style = "margin-top: 4px;")
            ),
            hr(),
            h4("CCC Dataset Summary"),
            uiOutput("dataset_summary"),
            hr(),
            h4("Variable Definitions (CCC)"),
            tags$table(class = "table table-striped table-bordered",
              tags$thead(tags$tr(tags$th("Variable"), tags$th("Type"), tags$th("Description"))),
              tags$tbody(
                tags$tr(tags$td("date"), tags$td("Date"), tags$td("Date of the protest event")),
                tags$tr(tags$td("state"), tags$td("Text"), tags$td("U.S. state where the event occurred")),
                tags$tr(tags$td("locality"), tags$td("Text"), tags$td("City or locality name")),
                tags$tr(tags$td("lat / lon"), tags$td("Numeric"), tags$td("Geographic coordinates")),
                tags$tr(tags$td("event_type"), tags$td("Text"),
                        tags$td("Type of protest action (e.g., rally, march, demonstration)")),
                tags$tr(tags$td("main_issue"), tags$td("Text"),
                        tags$td("Primary issue category (e.g., Policing, Environment, Foreign Affairs)")),
                tags$tr(tags$td("organizations"), tags$td("Text"),
                        tags$td("Named organizations involved in the event")),
                tags$tr(tags$td("n_sources"), tags$td("Integer"),
                        tags$td("Number of distinct media sources that covered this event. ",
                                "This is the primary measure of media visibility. Range: 0–27.")),
                tags$tr(tags$td("online"), tags$td("Binary (0/1)"),
                        tags$td("1 = online/virtual event, 0 = in-person")),
                tags$tr(tags$td("urban"), tags$td("Logical"),
                        tags$td("TRUE = urban location, FALSE = rural")),
                tags$tr(tags$td("arrests"), tags$td("Binary (0/1)"),
                        tags$td("1 = arrests reported, 0 = none")),
                tags$tr(tags$td("property_damage"), tags$td("Binary (0/1)"),
                        tags$td("1 = property damage reported, 0 = none")),
                tags$tr(tags$td("valence"), tags$td("Integer"),
                        tags$td("Coded valence of the event (0, 1, or 2)"))
              )
            )
          )
        )
      )
    )
  )
)


paths <- prep_paths()
CCC_DATA <- load_if_exists(paths$ccc_full)
GEO_SUMMARY <- load_if_exists(paths$geo_summary)
META <- load_if_exists(paths$meta)

server <- function(input, output, session) {

  acled_protest_week <- {
    raw <- load_if_exists(paths$acled_comp_week)
    if (!is.null(raw)) {
      raw |>
        dplyr::filter(event_type == "Protests") |>
        dplyr::group_by(week) |>
        dplyr::summarise(acled_protests = sum(acled_events, na.rm = TRUE), .groups = "drop")
    } else NULL
  }

  ccc_week_data <- load_if_exists(paths$ccc_week)

  gap_data <- {
    if (!is.null(acled_protest_week) && !is.null(ccc_week_data)) {
      overlap_start <- max(min(acled_protest_week$week, na.rm = TRUE),
                           min(ccc_week_data$week, na.rm = TRUE))
      overlap_end   <- min(max(acled_protest_week$week, na.rm = TRUE),
                           max(ccc_week_data$week, na.rm = TRUE))
      dplyr::full_join(ccc_week_data, acled_protest_week, by = "week") |>
        dplyr::mutate(
          ccc_events     = ifelse(is.na(ccc_events), 0L, ccc_events),
          acled_protests = ifelse(is.na(acled_protests), 0L, acled_protests)
        ) |>
        dplyr::filter(week >= overlap_start, week <= overlap_end) |>
        dplyr::mutate(diff = ccc_events - acled_protests) |>
        dplyr::arrange(week)
    } else NULL
  }

  observe({
    if (!is.null(CCC_DATA) && nrow(CCC_DATA) > 0) {
      updateDateRangeInput(session, "date_range",
                          start = min(CCC_DATA$date, na.rm = TRUE),
                          end   = max(CCC_DATA$date, na.rm = TRUE))

      issue_choices <- sort(unique(CCC_DATA$main_issue[!is.na(CCC_DATA$main_issue)]))
      updateSelectInput(session, "issues",
                      choices  = c("All Issues" = "all", setNames(issue_choices, issue_choices)),
                      selected = "all")

      event_choices <- names(sort(table(CCC_DATA$event_type), decreasing = TRUE))[1:10]
      updateSelectInput(session, "event_types",
                      choices  = c("All Types" = "all", setNames(event_choices, event_choices)),
                      selected = "all")
    }
  })

  observeEvent(input$issues, {
    sel <- input$issues
    if (length(sel) > 1 && "all" %in% sel) {
      updateSelectInput(session, "issues", selected = setdiff(sel, "all"))
    }
  }, ignoreInit = TRUE)

  observeEvent(input$event_types, {
    sel <- input$event_types
    if (length(sel) > 1 && "all" %in% sel) {
      updateSelectInput(session, "event_types", selected = setdiff(sel, "all"))
    }
  }, ignoreInit = TRUE)

  filtered_result <- reactiveVal(CCC_DATA)

  observeEvent(input$apply_filters, {
    data <- CCC_DATA
    if (is.null(data)) return()

    result <- data

    if (!is.null(input$date_range[1]) && !is.null(input$date_range[2])) {
      result <- result |>
        dplyr::filter(date >= input$date_range[1],
                      date <= input$date_range[2])
    }

    if (!is.null(input$issues) && length(input$issues) > 0 && !("all" %in% input$issues)) {
      result <- result |> dplyr::filter(main_issue %in% input$issues)
    }

    if (!is.null(input$event_types) && length(input$event_types) > 0 && !("all" %in% input$event_types)) {
      result <- result |> dplyr::filter(event_type %in% input$event_types)
    }

    if (!is.null(input$geography) && !("all" %in% input$geography)) {
      if ("online" %in% input$geography) {
        result <- result |> dplyr::filter(online == 1)
      } else if ("urban" %in% input$geography && !("rural" %in% input$geography)) {
        result <- result |> dplyr::filter(urban == TRUE)
      } else if ("rural" %in% input$geography && !("urban" %in% input$geography)) {
        result <- result |> dplyr::filter(urban == FALSE)
      }
    }

    message("[filter] Applied filters -> ", nrow(result), " rows ",
            "(issues: ", paste(input$issues, collapse=","),
            ", types: ", paste(input$event_types, collapse=","), ")")
    filtered_result(result)
  })

  filtered_data <- reactive({
    req(filtered_result())
    filtered_result()
  })


  output$gap_lines_plot <- renderPlotly({
    gd <- gap_data
    if (is.null(gd) || nrow(gd) == 0) return(NULL)

    plot_ly(gd, x = ~week) |>
      add_lines(y = ~ccc_events, name = "CCC (all protests)",
                line = list(color = COL$blue, width = 2),
                hovertemplate = paste0("CCC (all protests)<br>",
                                       "%{x|%b %d, %Y}<br>",
                                       "Events: %{y:,}<extra></extra>")) |>
      add_lines(y = ~acled_protests, name = "ACLED (protests only)",
                line = list(color = COL$orange, width = 2),
                hovertemplate = paste0("ACLED (protests only)<br>",
                                       "%{x|%b %d, %Y}<br>",
                                       "Events: %{y:,}<extra></extra>")) |>
      plotly::layout(
        xaxis = list(title = ""),
        yaxis = list(title = "Protest Events per Week", separatethousands = TRUE),
        legend = list(orientation = "h", x = 0.2, y = 1.08),
        font = list(family = "Helvetica Neue, Arial, sans-serif"),
        hoverlabel = list(bgcolor = "white", font = list(size = 12)),
        plot_bgcolor = "white", paper_bgcolor = "white"
      ) |>
      plotly::config(displayModeBar = FALSE)
  })

  output$gap_area_plot <- renderPlotly({
    gd <- gap_data
    if (is.null(gd) || nrow(gd) == 0) return(NULL)

    gd_pos <- gd |> dplyr::mutate(val = ifelse(diff >= 0, diff, 0))
    gd_neg <- gd |> dplyr::mutate(val = ifelse(diff < 0, diff, 0))

    plot_ly() |>
      add_bars(data = gd_pos, x = ~week, y = ~val, name = "CCC records more",
               marker = list(color = COL$blue),
               hovertemplate = paste0("%{x|%b %d, %Y}<br>",
                                      "Gap: +%{y}<extra>CCC records more</extra>")) |>
      add_bars(data = gd_neg, x = ~week, y = ~val, name = "ACLED records more",
               marker = list(color = COL$red),
               hovertemplate = paste0("%{x|%b %d, %Y}<br>",
                                      "Gap: %{y}<extra>ACLED records more</extra>")) |>
      plotly::layout(
        barmode = "relative",
        xaxis = list(title = ""),
        yaxis = list(title = "CCC Events − ACLED Protest Events",
                     separatethousands = TRUE),
        legend = list(orientation = "h", x = 0.2, y = 1.08),
        font = list(family = "Helvetica Neue, Arial, sans-serif"),
        hoverlabel = list(bgcolor = "white", font = list(size = 12)),
        plot_bgcolor = "white", paper_bgcolor = "white"
      ) |>
      plotly::config(displayModeBar = FALSE)
  })

  output$gap_summary <- renderText({
    gd <- gap_data
    req(gd)
    overlap <- gd |> dplyr::filter(ccc_events > 0, acled_protests > 0)
    total_ccc   <- sum(gd$ccc_events, na.rm = TRUE)
    total_acled <- sum(gd$acled_protests, na.rm = TRUE)
    weeks_ccc_more  <- sum(gd$diff > 0, na.rm = TRUE)
    weeks_acled_more <- sum(gd$diff < 0, na.rm = TRUE)
    pct_more <- round((total_ccc - total_acled) / total_acled * 100, 1)

    paste0(
      "Overlapping period: ", format(min(overlap$week), "%b %Y"),
      " to ", format(max(overlap$week), "%b %Y"), "\n",
      "Total CCC protest events: ", scales::comma(total_ccc), "\n",
      "Total ACLED protest events: ", scales::comma(total_acled), "\n",
      "CCC records ", abs(pct_more), "% ",
      ifelse(pct_more >= 0, "more", "fewer"),
      " protest events than ACLED over this period\n",
      "Weeks where CCC > ACLED: ", weeks_ccc_more,
      "  |  Weeks where ACLED > CCC: ", weeks_acled_more
    )
  })


  output$protest_map <- renderLeaflet({
    d <- filtered_data()
    req(d)
    coords <- d |> dplyr::filter(!is.na(lat), !is.na(lon))
    if (nrow(coords) > 10000) coords <- coords[sample(nrow(coords), 10000), ]

    leaflet() |>
      addProviderTiles(providers$CartoDB.Positron) |>
      setView(lng = -98.5795, lat = 39.8283, zoom = 4) |>
      addCircleMarkers(
        data = coords,
        lng = ~lon, lat = ~lat,
        radius = ~pmin(n_sources * 1.5 + 2, 18),
        color = ~ifelse(online == 1, COL$red, COL$blue),
        fillOpacity = 0.55, stroke = FALSE,
        popup = ~paste0(
          "<b>", main_issue, "</b><br>",
          "Date: ", as.character(date), "<br>",
          "Location: ", locality, ", ", state, "<br>",
          "Media sources: ", n_sources, "<br>",
          "Type: ", event_type
        )
      ) |>
      addLegend(
        position = "bottomright",
        colors = c(COL$blue, COL$red),
        labels = c("In-person", "Online / Virtual"),
        title = "Event Type",
        opacity = 0.8
      )
  })

  output$map_info <- renderText({
    d <- filtered_data(); req(d)
    paste0("Filtered events: ", scales::comma(nrow(d)),
           "  |  Mean media sources: ", round(mean(d$n_sources, na.rm = TRUE), 2),
           "  |  Median media sources: ", median(d$n_sources, na.rm = TRUE))
  })


  output$issue_mean_plot <- renderPlotly({
    d <- filtered_data(); req(d, nrow(d) > 0)

    issue_avg <- d |>
      dplyr::group_by(main_issue) |>
      dplyr::summarise(mean_sources = mean(n_sources, na.rm = TRUE),
                       n = n(), .groups = "drop")

    p <- ggplot(issue_avg, aes(x = reorder(main_issue, mean_sources), y = mean_sources,
                               text = paste0(main_issue, "\nMean sources: ",
                                             round(mean_sources, 2), "\nEvents: ",
                                             scales::comma(n)))) +
      geom_col(fill = COL$blue) +
      coord_flip() +
      labs(x = NULL, y = "Average Media Sources per Event") +
      plot_theme()
    to_plotly(p)
  })

  output$issue_box_plot <- renderPlotly({
    d <- filtered_data(); req(d, nrow(d) > 0)

    issue_order <- d |>
      dplyr::group_by(main_issue) |>
      dplyr::summarise(med = median(n_sources, na.rm = TRUE), .groups = "drop") |>
      dplyr::arrange(med) |>
      dplyr::pull(main_issue)

    plot_ly(d, y = ~main_issue, x = ~n_sources, type = "box",
            orientation = "h",
            boxpoints = FALSE,
            marker = list(color = COL$blue),
            line = list(color = COL$dark),
            fillcolor = COL$blue,
            hoverinfo = "x") |>
      plotly::layout(
        yaxis = list(title = "", categoryorder = "array", categoryarray = issue_order),
        xaxis = list(title = "Media Sources per Event"),
        font = list(family = "Helvetica Neue, Arial, sans-serif"),
        hoverlabel = list(bgcolor = "white", font = list(size = 12)),
        plot_bgcolor = "white", paper_bgcolor = "white"
      ) |>
      plotly::config(displayModeBar = FALSE)
  })

  output$trait_type_plot <- renderPlotly({
    d <- filtered_data(); req(d, nrow(d) > 0)

    top_types <- names(sort(table(d$event_type), decreasing = TRUE))[1:10]
    type_avg <- d |>
      dplyr::filter(event_type %in% top_types) |>
      dplyr::mutate(event_type_clean = clean_event_type(event_type)) |>
      dplyr::group_by(event_type_clean) |>
      dplyr::summarise(mean_sources = mean(n_sources, na.rm = TRUE),
                       n = n(), .groups = "drop")

    p <- ggplot(type_avg, aes(x = reorder(event_type_clean, mean_sources), y = mean_sources,
                              text = paste0(event_type_clean,
                                            "\nMean sources: ", round(mean_sources, 2),
                                            "\nEvents: ", scales::comma(n)))) +
      geom_col(fill = COL$dark) +
      coord_flip() +
      labs(x = NULL, y = "Average Media Sources per Event") +
      plot_theme()
    to_plotly(p)
  })

  output$trait_arrests_plot <- renderPlotly({
    d <- filtered_data(); req(d, nrow(d) > 0)

    arr <- d |>
      dplyr::mutate(arrests_label = ifelse(arrests == 1, "Arrests Reported", "No Arrests")) |>
      dplyr::group_by(arrests_label) |>
      dplyr::summarise(mean_sources = mean(n_sources, na.rm = TRUE),
                       n = n(), .groups = "drop")

    p <- ggplot(arr, aes(x = arrests_label, y = mean_sources,
                         text = paste0(arrests_label,
                                       "\nMean sources: ", round(mean_sources, 2),
                                       "\nEvents: ", scales::comma(n)))) +
      geom_col(fill = COL$dark) +
      labs(x = NULL, y = "Average Media Sources per Event") +
      plot_theme()
    to_plotly(p)
  })

  output$trait_damage_plot <- renderPlotly({
    d <- filtered_data(); req(d, nrow(d) > 0)

    dmg <- d |>
      dplyr::mutate(damage_label = ifelse(property_damage == 1,
                                          "Damage Reported", "No Damage")) |>
      dplyr::group_by(damage_label) |>
      dplyr::summarise(mean_sources = mean(n_sources, na.rm = TRUE),
                       n = n(), .groups = "drop")

    p <- ggplot(dmg, aes(x = damage_label, y = mean_sources,
                         text = paste0(damage_label,
                                       "\nMean sources: ", round(mean_sources, 2),
                                       "\nEvents: ", scales::comma(n)))) +
      geom_col(fill = COL$dark) +
      labs(x = NULL, y = "Average Media Sources per Event") +
      plot_theme()
    to_plotly(p)
  })

  output$trait_org_plot <- renderPlotly({
    d <- filtered_data(); req(d, nrow(d) > 0)

    org_presence <- d |>
      dplyr::mutate(has_org = ifelse(organizations != "" & !is.na(organizations),
                                     "Has Organization", "No Organization")) |>
      dplyr::group_by(has_org) |>
      dplyr::summarise(mean_sources = mean(n_sources, na.rm = TRUE),
                       n = n(), .groups = "drop")

    p <- ggplot(org_presence, aes(x = has_org, y = mean_sources,
                                  text = paste0(has_org,
                                                "\nMean sources: ", round(mean_sources, 2),
                                                "\nEvents: ", scales::comma(n)))) +
      geom_col(fill = COL$dark) +
      labs(x = NULL, y = "Average Media Sources per Event") +
      plot_theme()
    to_plotly(p)
  })

  output$trait_org_top_plot <- renderPlotly({
    d <- filtered_data(); req(d, nrow(d) > 0)

    org_top <- d |>
      dplyr::filter(organizations != "", !is.na(organizations)) |>
      dplyr::group_by(organizations) |>
      dplyr::summarise(mean_sources = mean(n_sources, na.rm = TRUE),
                       n = n(), .groups = "drop") |>
      dplyr::filter(n >= 50) |>
      dplyr::arrange(desc(mean_sources)) |>
      head(15)

    p <- ggplot(org_top, aes(x = reorder(organizations, mean_sources), y = mean_sources,
                             text = paste0(organizations,
                                           "\nMean sources: ", round(mean_sources, 2),
                                           "\nEvents: ", scales::comma(n)))) +
      geom_col(fill = COL$blue) +
      coord_flip() +
      labs(x = NULL, y = "Average Media Sources per Event") +
      plot_theme(base_size = 11)
    to_plotly(p) |> plotly::layout(margin = list(l = 250))
  })


  output$repression_plot <- renderPlotly({
    d <- filtered_data(); req(d, nrow(d) > 0)

    repression <- d |>
      dplyr::mutate(
        category = dplyr::case_when(
          arrests == 1 & property_damage == 1 ~ "Both Arrests & Damage",
          arrests == 1 & property_damage == 0 ~ "Arrests Only",
          arrests == 0 & property_damage == 1 ~ "Property Damage Only",
          TRUE ~ "Neither"
        ),
        category = factor(category, levels = c("Neither", "Property Damage Only",
                                                "Arrests Only", "Both Arrests & Damage"))
      ) |>
      dplyr::group_by(category) |>
      dplyr::summarise(mean_sources = mean(n_sources, na.rm = TRUE),
                       n = dplyr::n(), .groups = "drop")

    p <- ggplot(repression, aes(x = category, y = mean_sources,
                                text = paste0(category,
                                              "\nMean sources: ", round(mean_sources, 2),
                                              "\nEvents: ", scales::comma(n)))) +
      geom_col(aes(fill = category), show.legend = FALSE) +
      scale_fill_manual(values = c(
        "Neither" = COL$ltgray,
        "Property Damage Only" = COL$orange,
        "Arrests Only" = COL$red,
        "Both Arrests & Damage" = COL$dark
      )) +
      labs(x = NULL, y = "Average Media Sources per Event") +
      plot_theme()
    to_plotly(p)
  })

  output$valence_plot <- renderPlotly({
    d <- filtered_data(); req(d, nrow(d) > 0)

    val_data <- d |>
      dplyr::filter(!is.na(valence)) |>
      dplyr::mutate(
        valence_label = dplyr::case_when(
          valence == 0 ~ "Left-leaning",
          valence == 1 ~ "Neutral / Unclassified",
          valence == 2 ~ "Right-leaning"
        ),
        valence_label = factor(valence_label, levels = c("Left-leaning",
                                                          "Neutral / Unclassified",
                                                          "Right-leaning"))
      )

    stats <- val_data |>
      dplyr::group_by(valence_label) |>
      dplyr::summarise(
        mean_src = mean(n_sources, na.rm = TRUE),
        median_src = median(n_sources, na.rm = TRUE),
        q25 = quantile(n_sources, 0.25, na.rm = TRUE),
        q75 = quantile(n_sources, 0.75, na.rm = TRUE),
        pct_zero = round(mean(n_sources == 0, na.rm = TRUE) * 100, 1),
        n = dplyr::n(),
        .groups = "drop"
      )

    colors <- c("Left-leaning" = COL$blue,
                "Neutral / Unclassified" = COL$gray,
                "Right-leaning" = COL$red)

    plot_ly() |>
      add_bars(data = stats, x = ~valence_label, y = ~mean_src,
               marker = list(color = colors[stats$valence_label], opacity = 0.8),
               name = "Mean",
               hovertemplate = paste0("<b>%{x}</b><br>",
                                      "Mean: %{y:.2f}<extra></extra>")) |>
      add_trace(data = stats, x = ~valence_label,
                y = ~median_src,
                type = "scatter", mode = "markers",
                marker = list(color = COL$dark, size = 12, symbol = "diamond"),
                name = "Median",
                hovertemplate = paste0("<b>%{x}</b><br>",
                                       "Median: %{y}<extra></extra>")) |>
      add_trace(data = stats, x = ~valence_label,
                y = ~q25,
                type = "scatter", mode = "markers",
                marker = list(color = COL$dark, size = 8, symbol = "triangle-up"),
                name = "25th Percentile",
                hovertemplate = paste0("<b>%{x}</b><br>",
                                       "25th Percentile: %{y}<extra></extra>")) |>
      add_trace(data = stats, x = ~valence_label,
                y = ~q75,
                type = "scatter", mode = "markers",
                marker = list(color = COL$dark, size = 8, symbol = "triangle-down"),
                name = "75th Percentile",
                hovertemplate = paste0("<b>%{x}</b><br>",
                                       "75th Percentile: %{y}<extra></extra>")) |>
      plotly::layout(
        xaxis = list(title = ""),
        yaxis = list(title = "Media Sources per Event",
                     range = c(0, max(stats$q75) * 1.8)),
        annotations = lapply(seq_len(nrow(stats)), function(i) {
          list(x = stats$valence_label[i],
               y = stats$q75[i] + max(stats$q75) * 0.25,
               text = paste0("n = ", scales::comma(stats$n[i]),
                             "<br>", stats$pct_zero[i], "% zero coverage"),
               showarrow = FALSE,
               font = list(size = 10, color = COL$dark))
        }),
        legend = list(orientation = "h", x = 0.1, y = 1.08),
        font = list(family = "Helvetica Neue, Arial, sans-serif"),
        hoverlabel = list(bgcolor = "white", font = list(size = 12)),
        plot_bgcolor = "white", paper_bgcolor = "white",
        bargap = 0.4
      ) |>
      plotly::config(displayModeBar = FALSE)
  })


  output$visibility_dist_plot <- renderPlotly({
    d <- filtered_data(); req(d, nrow(d) > 0)

    dist <- d |>
      dplyr::count(n_sources) |>
      dplyr::arrange(n_sources) |>
      dplyr::mutate(
        pct = round(n / sum(n) * 100, 1),
        cum_pct = round(cumsum(n) / sum(n) * 100, 1)
      )

    plot_ly(dist, x = ~n_sources) |>
      add_bars(y = ~n, name = "Number of Events",
               marker = list(color = COL$blue),
               hovertemplate = paste0("<b>%{x} media sources</b><br>",
                                      "Events: %{y:,}<br>",
                                      "<extra></extra>")) |>
      add_lines(y = ~cum_pct, name = "Cumulative Percentage",
                line = list(color = COL$red, width = 2.5),
                yaxis = "y2",
                hovertemplate = paste0("<b>%{x} sources or fewer</b><br>",
                                       "Cumulative: %{y:.1f}%<extra></extra>")) |>
      plotly::layout(
        xaxis = list(title = "Number of Media Sources", dtick = 1),
        yaxis = list(title = "Number of Events"),
        yaxis2 = list(title = "Cumulative Percentage", side = "right",
                      overlaying = "y", range = c(0, 105),
                      ticksuffix = "%"),
        legend = list(orientation = "h", x = 0.55, y = 1.06),
        font = list(family = "Helvetica Neue, Arial, sans-serif"),
        hoverlabel = list(bgcolor = "white", font = list(size = 12)),
        plot_bgcolor = "white", paper_bgcolor = "white",
        margin = list(r = 60),
        annotations = list(
          list(x = 1, y = dist$cum_pct[dist$n_sources == 1],
               xref = "x", yref = "y2",
               text = paste0(dist$pct[dist$n_sources == 1], "% of all protests<br>have just 1 source"),
               showarrow = TRUE, arrowhead = 2, ax = 80, ay = 30,
               font = list(size = 11, color = COL$dark),
               bgcolor = "rgba(255,255,255,0.9)", borderpad = 4),
          list(x = 4, y = dist$cum_pct[dist$n_sources == 4],
               xref = "x", yref = "y2",
               text = paste0("Only ", round(100 - dist$cum_pct[dist$n_sources == 4], 1),
                             "% get 5+ sources"),
               showarrow = TRUE, arrowhead = 2, ax = 100, ay = 40,
               font = list(size = 11, color = COL$dark),
               bgcolor = "rgba(255,255,255,0.9)", borderpad = 4)
        )
      ) |>
      plotly::config(displayModeBar = FALSE)
  })


  observe({
    if (!is.null(CCC_DATA) && nrow(CCC_DATA) > 0) {
      cats <- sort(unique(CCC_DATA$main_issue[!is.na(CCC_DATA$main_issue)]))
      updateSelectInput(session, "sub_issue_category",
                        choices = c("All Categories" = "all", setNames(cats, cats)),
                        selected = "all")
    }
  })

  output$sub_issue_plot <- renderPlotly({
    d <- filtered_data(); req(d, nrow(d) > 0)

    cat_filter <- input$sub_issue_category
    if (!is.null(cat_filter) && cat_filter != "all") {
      d <- d |> dplyr::filter(main_issue == cat_filter)
    }

    sub_issues <- d |>
      dplyr::filter(!is.na(issues), issues != "") |>
      dplyr::group_by(issues) |>
      dplyr::summarise(
        mean_sources = mean(n_sources, na.rm = TRUE),
        n = dplyr::n(),
        .groups = "drop"
      ) |>
      dplyr::filter(n >= 20) |>
      dplyr::arrange(desc(mean_sources)) |>
      head(15) |>
      dplyr::mutate(issues_clean = tools::toTitleCase(gsub(";", " + ", issues)))

    req(nrow(sub_issues) > 0)

    p <- ggplot(sub_issues, aes(x = reorder(issues_clean, mean_sources), y = mean_sources,
                                text = paste0(issues_clean,
                                              "\nMean sources: ", round(mean_sources, 2),
                                              "\nEvents: ", scales::comma(n)))) +
      geom_col(fill = COL$blue) +
      coord_flip() +
      labs(x = NULL, y = "Average Media Sources per Event") +
      plot_theme()
    to_plotly(p)
  })


  output$size_coverage_plot <- renderPlotly({
    d <- filtered_data(); req(d, nrow(d) > 0)

    size_data <- d |>
      dplyr::filter(!is.na(size_cat), size_cat > 0) |>
      dplyr::mutate(
        size_label = dplyr::case_when(
          size_cat == 1 ~ "Small",
          size_cat == 2 ~ "Medium",
          size_cat == 3 ~ "Large",
          size_cat == 4 ~ "Very Large"
        ),
        size_label = factor(size_label, levels = c("Small", "Medium", "Large", "Very Large"))
      ) |>
      dplyr::group_by(size_label) |>
      dplyr::summarise(
        mean_sources = mean(n_sources, na.rm = TRUE),
        median_sources = median(n_sources, na.rm = TRUE),
        n = dplyr::n(),
        .groups = "drop"
      )

    req(nrow(size_data) > 0)

    size_colors <- c("Small" = COL$ltgray, "Medium" = COL$blue,
                     "Large" = COL$orange, "Very Large" = COL$red)

    plot_ly() |>
      add_bars(data = size_data, x = ~size_label, y = ~mean_sources,
               marker = list(color = unname(size_colors[as.character(size_data$size_label)])),
               name = "Mean",
               hovertemplate = paste0("<b>%{x}</b><br>",
                                      "Mean sources: %{y:.2f}<br>",
                                      "<extra></extra>")) |>
      add_trace(data = size_data, x = ~size_label, y = ~median_sources,
                type = "scatter", mode = "markers",
                marker = list(color = COL$dark, size = 12, symbol = "diamond"),
                name = "Median",
                hovertemplate = paste0("<b>%{x}</b><br>",
                                       "Median sources: %{y}<extra></extra>")) |>
      plotly::layout(
        xaxis = list(title = "Protest Size Category"),
        yaxis = list(title = "Media Sources per Event"),
        annotations = lapply(seq_len(nrow(size_data)), function(i) {
          list(x = size_data$size_label[i],
               y = size_data$mean_sources[i] + max(size_data$mean_sources) * 0.08,
               text = paste0("n = ", scales::comma(size_data$n[i])),
               showarrow = FALSE,
               font = list(size = 10, color = COL$dark))
        }),
        legend = list(orientation = "h", x = 0.3, y = 1.06),
        font = list(family = "Helvetica Neue, Arial, sans-serif"),
        hoverlabel = list(bgcolor = "white", font = list(size = 12)),
        plot_bgcolor = "white", paper_bgcolor = "white",
        bargap = 0.35
      ) |>
      plotly::config(displayModeBar = FALSE)
  })


  output$claims_coverage_plot <- renderPlotly({
    d <- filtered_data(); req(d, nrow(d) > 0)

    claims_data <- d |>
      dplyr::filter(!is.na(claims_summary), claims_summary != "") |>
      dplyr::mutate(
        claim_list = strsplit(claims_summary, ";")
      ) |>
      tidyr::unnest(claim_list) |>
      dplyr::mutate(claim_list = trimws(claim_list)) |>
      dplyr::filter(claim_list != "") |>
      dplyr::group_by(claim_list) |>
      dplyr::summarise(
        mean_sources = mean(n_sources, na.rm = TRUE),
        n = dplyr::n(),
        .groups = "drop"
      ) |>
      dplyr::filter(n >= 100) |>
      dplyr::arrange(desc(mean_sources)) |>
      head(20) |>
      dplyr::mutate(claim_clean = tools::toTitleCase(claim_list))

    req(nrow(claims_data) > 0)

    p <- ggplot(claims_data, aes(x = reorder(claim_clean, mean_sources), y = mean_sources,
                                  text = paste0(claim_clean,
                                                "\nMean sources: ", round(mean_sources, 2),
                                                "\nEvents: ", scales::comma(n)))) +
      geom_col(fill = COL$blue) +
      coord_flip() +
      labs(x = NULL, y = "Average Media Sources per Event") +
      plot_theme()
    to_plotly(p)
  })


  output$geo_urban_rural_plot <- renderPlotly({
    d <- filtered_data(); req(d, nrow(d) > 0)

    geo_ur <- d |>
      dplyr::mutate(location = ifelse(urban, "Urban", "Rural")) |>
      dplyr::group_by(main_issue, location) |>
      dplyr::summarise(mean_sources = mean(n_sources, na.rm = TRUE),
                       n = n(), .groups = "drop")

    p <- ggplot(geo_ur, aes(x = reorder(main_issue, mean_sources), y = mean_sources,
                            fill = location,
                            text = paste0(main_issue, " (", location, ")",
                                          "\nMean sources: ", round(mean_sources, 2),
                                          "\nEvents: ", scales::comma(n)))) +
      geom_col(position = "dodge") +
      coord_flip() +
      scale_fill_manual(values = c("Urban" = COL$blue, "Rural" = COL$gray)) +
      labs(x = NULL, y = "Average Media Sources per Event", fill = NULL) +
      plot_theme() +
      theme(legend.position = "top")
    to_plotly(p)
  })

  output$geo_state_sources_plot <- renderPlotly({
    d <- filtered_data(); req(d, nrow(d) > 0)

    state_src <- d |>
      dplyr::group_by(state) |>
      dplyr::summarise(mean_sources = mean(n_sources, na.rm = TRUE),
                       n_events = n(), .groups = "drop") |>
      dplyr::arrange(desc(n_events)) |> head(20)

    p <- ggplot(state_src, aes(x = reorder(state, mean_sources), y = mean_sources,
                               text = paste0(state,
                                             "\nMean sources: ", round(mean_sources, 2),
                                             "\nEvents: ", scales::comma(n_events)))) +
      geom_col(fill = COL$blue) +
      coord_flip() +
      labs(x = NULL, y = "Average Media Sources per Event") +
      plot_theme()
    to_plotly(p)
  })

  output$geo_scatter_plot <- renderPlotly({
    d <- filtered_data(); req(d, nrow(d) > 0)

    state_df <- d |>
      dplyr::group_by(state) |>
      dplyr::summarise(n_events = n(),
                       mean_sources = mean(n_sources, na.rm = TRUE),
                       pct_urban = round(mean(urban, na.rm = TRUE) * 100, 1),
                       .groups = "drop")

    plot_ly(state_df, x = ~n_events, y = ~mean_sources, size = ~pct_urban,
            type = "scatter", mode = "markers",
            text = ~state, sizes = c(6, 30),
            marker = list(color = COL$blue, opacity = 0.8,
                          line = list(color = COL$dark, width = 1)),
            hovertemplate = paste0("<b>%{text}</b><br>",
                                   "Events: %{x:,}<br>",
                                   "Mean sources: %{y:.2f}<br>",
                                   "Urban: %{marker.size:.0f}%",
                                   "<extra></extra>")) |>
      plotly::layout(
        xaxis = list(title = "Total Protest Events"),
        yaxis = list(title = "Average Media Sources per Event"),
        font = list(family = "Helvetica Neue, Arial, sans-serif"),
        hoverlabel = list(bgcolor = "white", font = list(size = 12)),
        plot_bgcolor = "white", paper_bgcolor = "white"
      ) |>
      plotly::config(displayModeBar = FALSE)
  })


  output$time_trend_plot <- renderPlotly({
    d <- filtered_data(); req(d, nrow(d) > 0)

    monthly <- d |>
      dplyr::mutate(month = lubridate::floor_date(date, "month")) |>
      dplyr::group_by(month) |>
      dplyr::summarise(mean_sources = mean(n_sources, na.rm = TRUE),
                       n_events = n(), .groups = "drop")

    plot_ly(monthly, x = ~month) |>
      add_bars(y = ~n_events, name = "Monthly Events",
               marker = list(color = COL$ltgray),
               hovertemplate = "%{x|%b %Y}<br>Events: %{y:,}<extra></extra>") |>
      add_lines(y = ~mean_sources, name = "Average Media Sources",
                line = list(color = COL$blue, width = 2),
                yaxis = "y2",
                hovertemplate = "%{x|%b %Y}<br>Mean sources: %{y:.2f}<extra></extra>") |>
      plotly::layout(
        xaxis = list(title = ""),
        yaxis = list(title = "Events per Month", side = "left"),
        yaxis2 = list(title = "Average Media Sources", side = "right",
                      overlaying = "y",
                      range = c(0, max(monthly$mean_sources, na.rm = TRUE) * 1.15)),
        legend = list(orientation = "h", x = 0.2, y = 1.06),
        font = list(family = "Helvetica Neue, Arial, sans-serif"),
        hoverlabel = list(bgcolor = "white", font = list(size = 12)),
        plot_bgcolor = "white", paper_bgcolor = "white",
        margin = list(r = 60)
      ) |>
      plotly::config(displayModeBar = FALSE)
  })

  output$time_issue_plot <- renderPlotly({
    d <- filtered_data()
    if (is.null(d) || nrow(d) == 0) return(NULL)

    top5_issues <- d |>
      dplyr::count(main_issue, sort = TRUE) |>
      head(5) |>
      dplyr::pull(main_issue)

    monthly_issue <- d |>
      dplyr::filter(main_issue %in% top5_issues) |>
      dplyr::mutate(month = lubridate::floor_date(date, "month")) |>
      dplyr::group_by(month, main_issue) |>
      dplyr::summarise(mean_sources = mean(n_sources, na.rm = TRUE),
                       n = n(), .groups = "drop")

    issue_colors <- c(COL$blue, COL$red, COL$dark, COL$green, COL$orange)
    names(issue_colors) <- top5_issues

    plt <- plot_ly()
    for (i in seq_along(top5_issues)) {
      iss <- top5_issues[i]
      sub <- monthly_issue |> dplyr::filter(main_issue == iss)
      plt <- plt |>
        add_lines(data = sub, x = ~month, y = ~mean_sources, name = iss,
                  line = list(color = issue_colors[iss], width = 2),
                  hovertemplate = paste0(iss, "<br>%{x|%b %Y}<br>",
                                         "Mean sources: %{y:.2f}<extra></extra>"))
    }
    plt |>
      plotly::layout(
        xaxis = list(title = ""),
        yaxis = list(title = "Average Media Sources per Event"),
        legend = list(font = list(size = 11)),
        font = list(family = "Helvetica Neue, Arial, sans-serif"),
        hoverlabel = list(bgcolor = "white", font = list(size = 12)),
        plot_bgcolor = "white", paper_bgcolor = "white"
      ) |>
      plotly::config(displayModeBar = FALSE)
  })


  output$political_opportunity_plot <- renderPlotly({
    d <- filtered_data(); req(d, nrow(d) > 0)

    weekly <- d |>
      dplyr::mutate(week = lubridate::floor_date(date, "week")) |>
      dplyr::group_by(week) |>
      dplyr::summarise(n_events = dplyr::n(),
                       mean_sources = mean(n_sources, na.rm = TRUE),
                       .groups = "drop")

    peak_threshold <- quantile(weekly$n_events, 0.80)
    peaks <- weekly |>
      dplyr::mutate(prev = dplyr::lag(n_events, default = 0),
                    nxt  = dplyr::lead(n_events, default = 0)) |>
      dplyr::filter(n_events > prev, n_events > nxt, n_events >= peak_threshold)

    if (nrow(peaks) > 1) {
      peaks <- peaks |> dplyr::arrange(week)
      keep <- rep(TRUE, nrow(peaks))
      for (j in 2:nrow(peaks)) {
        if (as.numeric(difftime(peaks$week[j], peaks$week[j - 1], units = "days")) < 42) {
          if (peaks$n_events[j] <= peaks$n_events[j - 1]) {
            keep[j] <- FALSE
          } else {
            keep[j - 1] <- FALSE
          }
        }
      }
      peaks <- peaks[keep, ]
    }

    issue_lookup <- d |>
      dplyr::mutate(week = lubridate::floor_date(date, "week")) |>
      dplyr::filter(week %in% peaks$week) |>
      dplyr::group_by(week, main_issue) |>
      dplyr::summarise(n = dplyr::n(), .groups = "drop") |>
      dplyr::group_by(week) |>
      dplyr::slice_max(n, n = 1, with_ties = FALSE) |>
      dplyr::ungroup()

    peaks <- peaks |>
      dplyr::left_join(issue_lookup |> dplyr::select(week, main_issue), by = "week") |>
      dplyr::mutate(
        label = dplyr::case_when(
          week == as.Date("2021-09-26") ~ "Women's March / Reproductive Rights",
          week == as.Date("2022-01-16") ~ "Vaccine Mandate Protests",
          week == as.Date("2022-05-08") ~ "Roe v. Wade Leak Response",
          week == as.Date("2022-06-19") ~ "Post-Dobbs Mobilization",
          week == as.Date("2022-10-02") ~ "National Life Chain / Midterm Push",
          week == as.Date("2023-10-08") ~ "October 7 / Gaza Solidarity",
          week == as.Date("2024-02-25") ~ "Gaza Ceasefire Protests",
          week == as.Date("2024-04-28") ~ "Columbia Encampment / Gaza",
          week == as.Date("2024-10-06") ~ "Gaza Anniversary / Election",
          main_issue == "Other" ~ "Mixed-Issue Mobilization",
          TRUE ~ paste0(main_issue, " Protests")
        )
      )

    n_peaks <- nrow(peaks)
    ax_vals <- rep(0, n_peaks)
    ay_vals <- rep(-40, n_peaks)
    if (n_peaks > 1) {
      for (j in 2:n_peaks) {
        gap_days <- as.numeric(difftime(peaks$week[j], peaks$week[j - 1], units = "days"))
        if (gap_days < 160) {
          ax_vals[j - 1] <- -60
          ax_vals[j]     <-  60
          ay_vals[j - 1] <- -30
          ay_vals[j]     <- -60
        }
      }
      for (j in 3:n_peaks) {
        gap_days_2 <- as.numeric(difftime(peaks$week[j], peaks$week[j - 2], units = "days"))
        if (gap_days_2 < 200) {
          ay_vals[j] <- -85
          ax_vals[j] <- 0
        }
      }
    }

    annotations <- lapply(seq_len(n_peaks), function(i) {
      list(x = as.numeric(peaks$week[i]) * 86400000,
           y = peaks$n_events[i],
           yref = "y",
           text = peaks$label[i],
           showarrow = TRUE, arrowhead = 2, arrowsize = 0.7,
           ax = ax_vals[i],
           ay = ay_vals[i],
           font = list(size = 9, color = COL$dark),
           bgcolor = "rgba(255,255,255,0.9)",
           borderpad = 3)
    })

    vlines <- lapply(seq_len(nrow(peaks)), function(i) {
      list(type = "line",
           x0 = as.numeric(peaks$week[i]) * 86400000,
           x1 = as.numeric(peaks$week[i]) * 86400000,
           y0 = 0, y1 = peaks$n_events[i],
           line = list(color = COL$red, width = 1, dash = "dot"))
    })

    plot_ly(weekly, x = ~week) |>
      add_bars(y = ~n_events, name = "Weekly Events",
               marker = list(color = COL$ltgray),
               hovertemplate = paste0("%{x|%b %d, %Y}<br>",
                                      "Events: %{y:,}<extra></extra>")) |>
      add_lines(y = ~mean_sources,
                name = "Average Media Sources",
                line = list(color = COL$blue, width = 2),
                yaxis = "y2",
                hovertemplate = paste0("%{x|%b %d, %Y}<br>",
                                       "Mean sources: %{y:.2f}<extra></extra>")) |>
      plotly::layout(
        xaxis = list(title = ""),
        yaxis = list(title = "Protest Events per Week", side = "left",
                     range = c(0, max(weekly$n_events, na.rm = TRUE) * 1.25)),
        yaxis2 = list(title = "Average Media Sources", side = "right",
                      overlaying = "y",
                      range = c(0, max(weekly$mean_sources, na.rm = TRUE) * 1.25)),
        shapes = vlines,
        annotations = annotations,
        legend = list(orientation = "h", x = 0.2, y = 1.04),
        font = list(family = "Helvetica Neue, Arial, sans-serif"),
        hoverlabel = list(bgcolor = "white", font = list(size = 12)),
        plot_bgcolor = "white", paper_bgcolor = "white",
        margin = list(t = 30, b = 50, r = 60)
      ) |>
      plotly::config(displayModeBar = FALSE)
  })


  output$vb_total_events <- renderValueBox({
    n <- if (!is.null(CCC_DATA)) scales::comma(nrow(CCC_DATA)) else "N/A"
    valueBox(n, "Protest Events Analyzed", icon = icon("database"), color = "blue")
  })

  output$vb_single_source <- renderValueBox({
    pct <- if (!is.null(CCC_DATA)) paste0(round(mean(CCC_DATA$n_sources == 1, na.rm = TRUE) * 100, 1), "%") else "N/A"
    valueBox(pct, "Covered by Just 1 Source", icon = icon("exclamation-triangle"), color = "red")
  })

  output$vb_five_plus <- renderValueBox({
    pct <- if (!is.null(CCC_DATA)) paste0(round(mean(CCC_DATA$n_sources >= 5, na.rm = TRUE) * 100, 1), "%") else "N/A"
    valueBox(pct, "Receive 5+ Media Sources", icon = icon("eye"), color = "orange")
  })

  output$vb_median_sources <- renderValueBox({
    med <- if (!is.null(CCC_DATA)) median(CCC_DATA$n_sources, na.rm = TRUE) else "N/A"
    valueBox(med, "Median Sources per Protest", icon = icon("chart-bar"), color = "navy")
  })

  output$vb_arrests_effect <- renderValueBox({
    if (!is.null(CCC_DATA)) {
      arr_yes <- mean(CCC_DATA$n_sources[CCC_DATA$arrests == 1], na.rm = TRUE)
      arr_no <- mean(CCC_DATA$n_sources[CCC_DATA$arrests == 0], na.rm = TRUE)
      valueBox(paste0(round(arr_yes / arr_no, 1), "x"), "Coverage Multiplier: Arrests",
               icon = icon("gavel"), color = "red")
    } else valueBox("N/A", "Coverage Multiplier: Arrests", icon = icon("gavel"), color = "red")
  })

  output$vb_org_effect <- renderValueBox({
    if (!is.null(CCC_DATA)) {
      has_org <- CCC_DATA$organizations != "" & !is.na(CCC_DATA$organizations)
      org_yes <- mean(CCC_DATA$n_sources[has_org], na.rm = TRUE)
      org_no <- mean(CCC_DATA$n_sources[!has_org], na.rm = TRUE)
      valueBox(paste0(round(org_yes / org_no, 1), "x"), "Coverage Multiplier: Organizations",
               icon = icon("users"), color = "green")
    } else valueBox("N/A", "Coverage Multiplier: Organizations", icon = icon("users"), color = "green")
  })

  output$vb_size_effect <- renderValueBox({
    if (!is.null(CCC_DATA) && "size_cat" %in% names(CCC_DATA)) {
      small_avg <- mean(CCC_DATA$n_sources[CCC_DATA$size_cat == 1 & !is.na(CCC_DATA$size_cat)], na.rm = TRUE)
      large_avg <- mean(CCC_DATA$n_sources[CCC_DATA$size_cat == 4 & !is.na(CCC_DATA$size_cat)], na.rm = TRUE)
      if (!is.na(small_avg) && small_avg > 0 && !is.na(large_avg)) {
        valueBox(paste0(round(large_avg / small_avg, 1), "x"), "Coverage: Very Large vs Small",
                 icon = icon("signal"), color = "purple")
      } else valueBox("N/A", "Coverage: Very Large vs Small", icon = icon("signal"), color = "purple")
    } else valueBox("N/A", "Coverage: Very Large vs Small", icon = icon("signal"), color = "purple")
  })

  output$vb_urban_effect <- renderValueBox({
    if (!is.null(CCC_DATA)) {
      urban_avg <- mean(CCC_DATA$n_sources[CCC_DATA$urban == TRUE], na.rm = TRUE)
      rural_avg <- mean(CCC_DATA$n_sources[CCC_DATA$urban == FALSE], na.rm = TRUE)
      if (!is.na(rural_avg) && rural_avg > 0 && !is.na(urban_avg)) {
        valueBox(paste0(round(urban_avg / rural_avg, 1), "x"), "Coverage: Urban vs Rural",
                 icon = icon("building"), color = "teal")
      } else valueBox("N/A", "Coverage: Urban vs Rural", icon = icon("building"), color = "teal")
    } else valueBox("N/A", "Coverage: Urban vs Rural", icon = icon("building"), color = "teal")
  })

  output$findings_legibility <- renderUI({
    if (is.null(gap_data) || nrow(gap_data) == 0) return(p("Comparison data not loaded."))
    total_ccc <- sum(gap_data$ccc_events, na.rm = TRUE)
    total_acled <- sum(gap_data$acled_protests, na.rm = TRUE)
    pct_more <- round((total_ccc - total_acled) / total_acled * 100, 1)
    weeks_more <- sum(gap_data$diff > 0, na.rm = TRUE)
    total_weeks <- nrow(gap_data)

    tags$ul(style = "line-height: 2; font-size: 0.93em; padding-left: 18px;",
      tags$li(HTML(paste0("The CCC records <strong>", abs(pct_more), "%</strong> more protest events than ACLED's expert-curated dataset during their overlapping coverage period."))),
      tags$li(HTML(paste0("CCC captures more events than ACLED in <strong>", weeks_more, " of ", total_weeks, "</strong> overlapping weeks, demonstrating a persistent and systematic gap."))),
      tags$li("This gap represents protests that remain politically invisible to the institutions that rely on curated data to understand civil society."),
      tags$li("Visibility is the prerequisite for institutional response, because what is not recorded cannot be acted upon.")
    )
  })

  output$findings_resources <- renderUI({
    if (is.null(CCC_DATA)) return(p("Data not loaded."))

    arr_yes <- round(mean(CCC_DATA$n_sources[CCC_DATA$arrests == 1], na.rm = TRUE), 2)
    arr_no <- round(mean(CCC_DATA$n_sources[CCC_DATA$arrests == 0], na.rm = TRUE), 2)
    dmg_yes <- round(mean(CCC_DATA$n_sources[CCC_DATA$property_damage == 1], na.rm = TRUE), 2)
    dmg_no <- round(mean(CCC_DATA$n_sources[CCC_DATA$property_damage == 0], na.rm = TRUE), 2)

    has_org <- CCC_DATA$organizations != "" & !is.na(CCC_DATA$organizations)
    org_yes <- round(mean(CCC_DATA$n_sources[has_org], na.rm = TRUE), 2)
    org_no <- round(mean(CCC_DATA$n_sources[!has_org], na.rm = TRUE), 2)

    tags$ul(style = "line-height: 2; font-size: 0.93em; padding-left: 18px;",
      tags$li(HTML(paste0("Events where arrests were reported average <strong>", arr_yes, "</strong> media sources, compared to <strong>", arr_no, "</strong> for events without arrests."))),
      tags$li(HTML(paste0("Events with property damage average <strong>", dmg_yes, "</strong> sources, compared to <strong>", dmg_no, "</strong> for events without damage."))),
      tags$li(HTML(paste0("Events with at least one named organization average <strong>", org_yes, "</strong> sources, compared to <strong>", org_no, "</strong> for unorganized events."))),
      tags$li("Larger protests receive dramatically more media coverage, confirming that mobilization capacity directly shapes visibility.")
    )
  })

  output$findings_framing <- renderUI({
    if (is.null(CCC_DATA)) return(p("Data not loaded."))

    issue_avg <- CCC_DATA |>
      dplyr::group_by(main_issue) |>
      dplyr::summarise(mean_src = mean(n_sources, na.rm = TRUE), .groups = "drop") |>
      dplyr::arrange(desc(mean_src))

    top_issue <- issue_avg$main_issue[1]
    top_val <- round(issue_avg$mean_src[1], 2)
    bot_issue <- issue_avg$main_issue[nrow(issue_avg)]
    bot_val <- round(issue_avg$mean_src[nrow(issue_avg)], 2)

    val_left <- round(mean(CCC_DATA$n_sources[CCC_DATA$valence == 0], na.rm = TRUE), 2)
    val_right <- round(mean(CCC_DATA$n_sources[CCC_DATA$valence == 2], na.rm = TRUE), 2)

    tags$ul(style = "line-height: 2; font-size: 0.93em; padding-left: 18px;",
      tags$li(HTML(paste0("The highest-covered issue category is <strong>", top_issue, "</strong> with <strong>", top_val, "</strong> average media sources per event."))),
      tags$li(HTML(paste0("The lowest-covered issue category is <strong>", bot_issue, "</strong> with <strong>", bot_val, "</strong> average media sources per event."))),
      tags$li(HTML(paste0("Left-leaning protests average <strong>", val_left, "</strong> sources per event, compared to <strong>", val_right, "</strong> for right-leaning protests."))),
      tags$li("Protest volume spikes around key political moments, reflecting how political opportunity structures open windows of increased visibility.")
    )
  })


  output$download_data <- downloadHandler(
    filename = function() paste0("protest_data_filtered_", Sys.Date(), ".csv"),
    content = function(file) readr::write_csv(filtered_data(), file)
  )


  output$dataset_summary <- renderUI({
    m <- META
    if (!is.null(m)) {
      tags$ul(
        tags$li(strong("Total events:"), " ", scales::comma(m$total_events)),
        tags$li(strong("Time period:"), " ", m$date_range),
        tags$li(strong("States covered:"), " ", m$states_covered),
        tags$li(strong("Organizations:"), " ", scales::comma(m$organizations))
      )
    }
  })
}

shinyApp(ui, server)
