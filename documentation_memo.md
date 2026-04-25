# Documentation Memo: U.S. Protest Media Coverage Dashboard

## Purpose

This dashboard examines how media coverage is distributed across U.S. protests. The central variable is the number of distinct media sources covering each event (n_sources), as recorded by the Crowd Counting Consortium (CCC). The dashboard asks whether certain types of protests consistently receive more or less media attention, and what patterns emerge.

## Datasets

The **Crowd Counting Consortium (CCC)**, maintained by researchers at Harvard Kennedy School and the University of Connecticut, records every U.S. protest event regardless of size or media attention: over 138,000 events from January 2021 through December 2024, with fields for date, location, issue category, event type, organizations, arrests, property damage, protest size, claims, and political valence.

**ACLED** (Armed Conflict Location and Event Data Project) is an expert-curated global political event dataset, filtered here to U.S. protests and compared against CCC weekly to measure how many protests fall outside curated institutional records.

## Project Structure

```
ethics-410S-final-project/
├── .gitignore
├── LICENSE
├── app.R                                    # Shiny dashboard (all UI + server logic)
├── documentation_memo.md
├── run_dashboard.sh                         # Launch script
├── R/
│   ├── prep_dashboard_data.R                # Core data preparation
│   └── prep_geographic_media_data.R         # Geographic enrichment
└── scripts/
    ├── install_dashboard_deps.R             # Dependency installation
    └── prep_geographic_media_dashboard.R    # Preprocessing pipeline
```

## Dashboard Navigation

The dashboard has eight tabs in the left sidebar. Tabs 3 through 6 share a filter panel (date range constrained to the data period, issue category, event type, geography) and a CSV export button.

**Key Findings:** Summary statistics (total events, median sources, unique issues), three themed findings boxes (Coverage Patterns, Organizations & Visibility, Issues/Valence/Timing), and course framework connections. Always uses the full unfiltered dataset.

**CCC vs. ACLED Comparison:** Weekly event counts from both datasets plotted side by side with aggregate statistics showing the coverage gap. Always uses the full unfiltered dataset.

**Spatial Coverage:** Interactive Leaflet map with protest locations sized by media source count and colored by event type. A deterministic random sample of up to 10,000 points is displayed for performance. Click any point for event details.

**What Gets Covered?:** Thirteen visualizations via dropdown: visibility distribution (histogram); coverage level breakdown by issue; average and spread of coverage by issue (bar and boxplot); issue/event type combinations; coverage by event type; arrests and property damage; organized vs. unorganized events; organization × issue interaction effects; repression interactions; political valence; protest size vs. coverage; and claims analysis.

**Geography of Visibility:** Three views: urban/rural coverage by issue, top 20 states by average media coverage, and event volume vs. coverage by state (scatter plot).

**Coverage Over Time:** Monthly average media sources overlaid on event volume, monthly trends for the top five issue categories, and a political opportunity chart showing weekly protest volume with automatically detected peaks that recalculate when filters are applied.

**Extended Analysis:** Two views, both using the full unfiltered dataset and computed lazily on first visit. A negative binomial regression predicting media source count from issue, organizational presence, arrests, property damage, protest size, valence, and urban/rural setting, displayed as incidence rate ratios (IRRs) with Wald confidence intervals, model fit statistics, and a deviance residuals diagnostic plot. A keyword analysis extracts individual words from protest claims to identify which terms are associated with higher or lower media coverage.

**About the Data:** Dataset descriptions, CCC summary table, variable definitions for CCC and ACLED, and nine documented data considerations and limitations.

## Course Framework Connections

Three course frameworks have direct connections to patterns visible in the data.

**Legibility (Scott):** Scott argues that institutions make complex realities governable by imposing legibility schemes — simplified, standardized categories that render a phenomenon measurable. This process requires what he calls a narrowing of vision: the scheme brings certain features into focus while everything outside its frame becomes invisible. The CCC vs. ACLED comparison shows a pattern consistent with this framework: CCC records over 126% more protest events than ACLED in 311 of 323 overlapping weeks. ACLED's coding criteria function as a legibility scheme — they determine which protests enter institutional records and which do not. The persistent gap suggests that the methodological choices that make ACLED reliable for its purposes also produce systematic blind spots, excluding protests that do not meet its threshold criteria.

**Organizational Resources (Almeida, Lune):** Almeida argues movements emerge more readily from preexisting organizations that provide leaders, communication channels, and bloc recruitment capacity, distinguishing activist organizations (SMOs) from everyday organizations mobilized under special circumstances. Lune extends this through organizational fields — multiple group types supporting each other across different short-term goals. In this data, events with a named organization average 2.03 media sources vs. 1.60 without, though both share a median of 1, and about 28% of events have no organization listed.

**Political Opportunity (Meyer, Tilly):** Meyer argues external political conditions shape when movements gain traction; Tilly shows social movement activity tracks political context. The political opportunity chart shows protest volume spiking around specific moments — the Roe v. Wade leak, the Dobbs decision, midterm mobilization, and Gaza solidarity protests — consistent with the argument that political conditions create windows movements respond to.

## Tensions and Surprises

The median number of media sources across all events is 1, meaning the typical protest receives minimal coverage regardless of its characteristics. Average differences between categories are real but modest. Protest size is missing for approximately 66% of events, about 28% have no organization listed, and n_sources counts distinct outlets rather than reach or audience size. Full limitations are in the About the Data tab.

## Technical Details

Built in R using Shiny/shinydashboard, Plotly for interactive charts, ggplot2 for chart construction, Leaflet for the spatial map, and MASS for negative binomial regression. The Extended Analysis tab uses lazy evaluation to avoid blocking the app at startup. Deployed on shinyapps.io.
