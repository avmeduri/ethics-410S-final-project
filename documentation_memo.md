# Documentation Memo: U.S. Protest Media Coverage Dashboard

## Purpose

This dashboard examines how media coverage is distributed across U.S. protests. The central variable is the number of distinct media sources covering each event (n_sources), as recorded by the Crowd Counting Consortium. Users can explore whether event characteristics, geography, issue category, and political timing predict which protests become visible.

## Datasets

The **Crowd Counting Consortium (CCC)**, maintained by researchers at Harvard Kennedy School and the University of Connecticut, records every U.S. protest event regardless of size or media attention: over 138,000 events from January 2021 through December 2024. Fields include date, location, issue category, event type, organizations, arrests, property damage, protest size, claims, valence, and n_sources.

**ACLED** (Armed Conflict Location and Event Data Project) is an expert-curated global political event dataset, filtered here to U.S. protests and compared against CCC weekly to measure how many protests fall outside curated institutional records.

## Project Structure

```
ethics-410S-final-project/
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

Eight tabs in the left sidebar. Tabs 3 through 6 share a filter panel (date range, issue, event type, geography) and a CSV export button.

- **Key Findings:** Summary statistics, value boxes, three dynamically computed findings panels, and course framework connections. Uses the full unfiltered dataset.
- **CCC vs. ACLED Comparison:** Weekly event counts from both datasets showing the coverage gap between comprehensive and curated records.
- **Spatial Coverage:** Interactive Leaflet map with protests sized by media source count and colored by event type. Samples up to 10,000 points for performance.
- **What Gets Covered?:** Thirteen visualizations via dropdown covering visibility distribution, coverage by issue, event type, arrests, property damage, organizations, interaction effects, repression, valence, protest size, and claims.
- **Geography of Visibility:** Urban/rural coverage by issue, top 20 states by average coverage, and event volume vs. coverage by state.
- **Coverage Over Time:** Monthly coverage trends, top five issue trends, and a political opportunity chart with detected peaks.
- **Extended Analysis:** Computed lazily on first visit. A negative binomial regression predicting n_sources displayed as incidence rate ratios (IRRs) with confidence intervals and diagnostics. A keyword analysis of protest claims identifying terms associated with higher or lower coverage.
- **About the Data:** Dataset descriptions, variable definitions, and data considerations.

## Technical Details

Built in R using Shiny/shinydashboard, Plotly, ggplot2, Leaflet, MASS, DT, lubridate, and tidyr. The Extended Analysis tab uses lazy computation via reactiveVal to defer model fitting and keyword tokenization until first visit. The Spatial Coverage map samples coordinates for browser performance. Deployed on shinyapps.io.

## Key Findings

The median protest receives coverage from 1 media source. Most protests are covered by a single outlet and only a small percentage receive five or more sources. This concentration is the dominant pattern.

CCC records 126% more protest events than ACLED in 311 of 323 overlapping weeks, a persistent gap consistent with what Scott describes as the narrowing of vision produced by legibility schemes.

Events with at least one named organization average 2.03 media sources compared to 1.60 without, though both share a median of 1. Arrests, property damage, and larger size each correlate with modestly higher averages. These patterns are consistent with Almeida’s argument that preexisting organizations provide communication channels and bloc recruitment capacity, and with his framing framework where movements convey claims through “mass media presentations.” Snow and Soule identify media as an active framing actor alongside “adversaries, institutional elites, [and] countermovements,” suggesting media organizations reshape rather than simply transmit movement messages.

Protest volume spikes around specific political moments (the Dobbs decision, midterm elections, Gaza solidarity protests) rather than following gradual trends, consistent with Meyer’s political opportunity framework. Meyer and Staggenborg add that media coverage itself shapes movement dynamics through the balancing norm, where journalism “emphasizes conflict, rather than content.”

A negative binomial regression controlling for all factors confirms the strongest predictors of coverage are protest size (very large: IRR = 5.47), arrests (IRR = 2.57), and property damage (IRR = 1.37). Organizational presence is also significant (IRR = 1.25). Right-leaning protests receive slightly less coverage than left-leaning ones (IRR = 0.96). The keyword analysis shows terms tied to labor disputes (“industrial,” “manufacturing,” “layoffs”) and political figures (“biden,” “trump”) associate with above-average coverage, consistent with Meyer and Staggenborg’s argument that media attention gravitates toward conflict.

## Data Limitations

Protest size is missing for approximately 66% of events. About 28% have no organization listed, which may reflect missing data rather than absence of organizational involvement. The variable n_sources counts distinct outlets, not reach or audience size. Full limitations are in the About the Data tab.
