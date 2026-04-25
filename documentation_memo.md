# Documentation Memo: U.S. Protest Media Coverage Dashboard

## Purpose

This dashboard examines how media coverage is distributed across U.S. protests. The central variable is the number of distinct media sources covering each event (n_sources), as recorded by the Crowd Counting Consortium (CCC).

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

Eight tabs in the left sidebar. Tabs 3 through 6 share a filter panel (date range, issue category, event type, geography) and a CSV export button.

**Key Findings:** Summary statistics, coverage multiplier value boxes, three themed findings boxes, and course framework connections. Uses the full unfiltered dataset.

**CCC vs. ACLED Comparison:** Weekly event counts from both datasets with aggregate statistics showing the coverage gap. Uses the full unfiltered dataset.

**Spatial Coverage:** Interactive Leaflet map with protest locations sized by media source count and colored by event type, sampling up to 10,000 points for performance.

**What Gets Covered?:** Thirteen visualizations via dropdown covering visibility distribution, coverage by issue, event type, arrests, property damage, organizations, organization by issue interaction effects, repression, political valence, protest size, and claims.

**Geography of Visibility:** Urban/rural coverage by issue, top 20 states by average coverage, and event volume vs. coverage by state.

**Coverage Over Time:** Monthly coverage trends, top five issue trends, and a political opportunity chart with automatically detected peaks.

**Extended Analysis:** Uses the full unfiltered dataset, computed lazily on first visit. A negative binomial regression predicting media source count, displayed as incidence rate ratios (IRRs) with Wald confidence intervals and deviance residuals diagnostics. A keyword analysis identifying which terms in protest claims are associated with higher or lower coverage.

**About the Data:** Dataset descriptions, variable definitions, and nine documented data considerations.

## Key Findings

**Coverage is highly concentrated.** The median is 1 source per event. Most protests are covered by a single outlet and only a small percentage receive five or more sources. This is the dominant pattern: most protests are barely visible regardless of their characteristics.

**Event characteristics predict modestly higher coverage.** Arrests, property damage, named organizations, larger size, and urban setting each correlate with higher average source counts. However, medians remain similar across groups, meaning these effects are driven by a tail of higher-visibility events rather than a consistent lift.

**Curated datasets systematically miss events.** CCC records 126% more protest events than ACLED in 311 of 323 overlapping weeks, a persistent gap showing expert-curated datasets exclude a large share of protest activity.

**Issue category and valence show differences.** Some issues average higher coverage than others, and left-leaning and right-leaning protests differ slightly. The regression controls for these factors simultaneously.

**Protest volume tracks political timing.** Protest counts spike around specific moments such as the Dobbs decision, midterm elections, and Gaza solidarity protests rather than following gradual trends.

## Course Framework Connections

**Legibility (Scott):** Scott argues institutions impose legibility schemes, simplified categories that render phenomena measurable, requiring a narrowing of vision that makes everything outside the frame invisible. ACLED's coding criteria function as a legibility scheme, determining which protests enter institutional records. The persistent gap suggests these choices produce systematic blind spots alongside their intended reliability.

**Organizational Resources (Almeida, Lune):** Almeida argues movements emerge more readily from preexisting organizations providing leaders, communication channels, and bloc recruitment. Lune extends this through organizational fields. Events with a named organization average 2.03 media sources vs. 1.60 without, though both share a median of 1.

**Political Opportunity (Meyer, Tilly):** Meyer argues external political conditions shape when movements gain traction; Tilly shows movement activity tracks political context. Protest volume spikes around moments such as the Roe v. Wade leak, the Dobbs decision, and Gaza solidarity protests, consistent with this framework.

## Data Limitations

Protest size is missing for approximately 66% of events, about 28% have no organization listed, and n_sources counts distinct outlets rather than reach or audience size. Full limitations are in the About the Data tab.

## Technical Details

Built in R using Shiny/shinydashboard, Plotly, ggplot2, Leaflet, and MASS. Deployed on shinyapps.io.
