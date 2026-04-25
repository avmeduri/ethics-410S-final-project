# Documentation Memo: U.S. Protest Media Coverage Dashboard

## Purpose

This dashboard examines how media coverage is distributed across U.S. protests. The central variable is the number of distinct media sources covering each event (n_sources), as recorded by the Crowd Counting Consortium (CCC). The dashboard asks whether certain types of protests consistently receive more or less media attention, and what patterns emerge.

## Datasets

The **Crowd Counting Consortium (CCC)**, maintained by researchers at Harvard Kennedy School and the University of Connecticut, records every U.S. protest event regardless of size or media attention: over 138,000 events from January 2021 through December 2024, with fields for date, location, issue category, event type, organizations, arrests, property damage, protest size, claims, and political valence.

**ACLED** (Armed Conflict Location and Event Data Project) is an expert-curated global political event dataset, filtered here to U.S. protests and compared against CCC weekly to measure how many protests fall outside curated institutional records.

## Project Structure

```
ethics-410S-final-project/
├── app.R                            # Shiny dashboard (all UI + server logic)
├── documentation_memo.md
├── data/
│   ├── raw/
│   │   ├── ccc/                     # CCC source CSVs (2017–2024)
│   │   └── acled/                   # ACLED weekly aggregates
│   └── prepared/                    # Preprocessed .rds files for the dashboard
├── R/                               # Data preparation scripts
├── scripts/                         # Dependency installation + preprocessing
├── course-materials/extracted/      # Project brief, rubric, resources
└── www/                             # Static web assets
```

## Dashboard Navigation

The dashboard has six tabs in the left sidebar. Tabs 3 through 6 share a filter panel (date range, issue category, event type, geography) and a CSV export button.

**Key Findings** — Summary statistics (total events, median sources, unique issues), three themed findings boxes (Coverage Patterns, Organizations & Visibility, Issues/Valence/Timing), and course framework connections. Always uses the full unfiltered dataset.

**CCC vs. ACLED Comparison** — Weekly event counts from both datasets plotted side by side with aggregate statistics showing the coverage gap. Always uses the full unfiltered dataset.

**Spatial Coverage** — Interactive Leaflet map with protest locations sized by media source count and colored by event type. A deterministic random sample of up to 10,000 points is displayed for performance. Click any point for event details.

**What Gets Covered?** — Twelve visualizations via dropdown: visibility distribution (histogram); coverage level breakdown by issue (stacked bar by source ranges); average and spread of coverage by issue (bar and boxplot); coverage by event type; coverage by detailed issue/event type combination; arrests and property damage comparisons; organized vs. unorganized events; top 15 organizations by media coverage; repression interactions; political valence; protest size vs. coverage; and claims analysis.

**Geography of Visibility** — Three views: urban/rural coverage by issue, top 20 states by average media coverage, and event volume vs. coverage by state (scatter plot).

**Coverage Over Time** — Monthly average media sources overlaid on event volume, monthly trends for the top five issue categories, and a political opportunity chart showing weekly protest volume with automatically detected peaks that recalculate when filters are applied.

**About the Data** — Dataset descriptions, CCC summary table, variable definitions for CCC and ACLED, and nine documented data considerations and limitations.

## Course Framework Connections

Three course frameworks have direct connections to patterns visible in the data.

**Legibility (Scott):** In *Seeing Like a State* (Ch. 1), Scott uses scientific forestry to show how institutions reduce complex realities to simplified, measurable categories. The CCC vs. ACLED comparison shows a parallel: CCC records over 126% more protest events than ACLED during their overlapping period, suggesting that institutional coding criteria create systematic blind spots.

**Organizational Resources (Almeida, Lune):** Almeida argues movements emerge more readily from preexisting organizations that provide recognized leaders, communication channels, and bloc recruitment capacity. He distinguishes activist organizations (SMOs) from everyday organizations (schools, churches, unions) mobilized under special circumstances. Lune extends this through organizational fields — multiple group types supporting each other across different short-term goals. In this data, events with a named organization average 2.03 media sources vs. 1.60 without, though both share a median of 1, and about 28% of events have no organization listed.

**Political Opportunity (Meyer, Tilly):** Meyer argues external political conditions shape when movements gain traction; Tilly shows social movement activity tracks political context. The political opportunity chart shows protest volume spiking around specific moments — the Roe v. Wade leak, the Dobbs decision, midterm mobilization, and Gaza solidarity protests — consistent with Meyer's argument that political conditions create windows movements respond to.

## Tensions and Surprises

The median number of media sources across all events is 1, meaning the typical protest receives minimal coverage regardless of its characteristics. Average differences between categories are real but modest. Protest size is missing for approximately 66% of events, about 28% have no organization listed, and n_sources counts distinct outlets rather than reach or audience size. Full limitations are documented in the About the Data tab.

## Technical Details

Built in R using Shiny/shinydashboard, Plotly for interactive charts, ggplot2 for chart construction, and Leaflet for the spatial map. Deployed on shinyapps.io.
