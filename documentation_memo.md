# Documentation Memo: "Who Gets Heard?" Dashboard

## Purpose

This dashboard uses event-level protest data to examine how media coverage is distributed across U.S. protests. The central variable is the number of distinct media sources that covered each event, as recorded by the Crowd Counting Consortium (CCC). The dashboard asks whether certain types of protests consistently receive more or less media attention, and if so, what patterns emerge.

Several course frameworks motivated the analysis. James Scott's concept of legibility suggests that institutions act on what they can see and measure, and protests not picked up by media sources remain less visible to the policymakers and researchers who rely on these records. Almeida's framing process framework suggests that how a protest articulates its grievances shapes whether media treats it as newsworthy. Meyer and Tilly's work on political opportunity structures suggests that protest activity tends to cluster around moments of institutional change such as court decisions or elections. Almeida's organizational resource framework and Lune's analysis of social movement organizations suggest that movements with more infrastructure and coordination tend to generate more coverage. Ganz's strategic capacity concept adds that leadership diversity and organizational design can shape how effectively movements attract attention.

## Intended Audience

The dashboard is intended for students, researchers, civic observers, and participants interested in protest activity and media attention in the United States. All charts use plain-language labels and are fully interactive with hover tooltips, so no technical background is required.

## Datasets

The Crowd Counting Consortium (CCC), maintained by researchers at Harvard Kennedy School and the University of Connecticut, aims to record every U.S. protest event regardless of size or media attention. The dataset contains 138,637 events with fields for date, location, issue category, event type, organizations, arrests, property damage, protest size, claims, and political valence. The media source count is the primary visibility measure throughout the dashboard.

ACLED (Armed Conflict Location and Event Data Project) is an expert-curated dataset of political events worldwide. In this dashboard, ACLED is filtered to U.S. protest events and compared against CCC at the weekly level to measure how many protests do not appear in curated institutional records.

## Navigation

The dashboard has six tabs in the left sidebar. Tabs 2 through 5 share a filter panel at the top that allows users to narrow results by date range, issue category, event type, and urban or rural location. Filters must be applied by clicking the "Apply Filters" button. An export button downloads the currently filtered dataset as a CSV file. Note that the Key Findings tab and the CCC vs ACLED Comparison tab always display statistics from the full unfiltered dataset. All other charts respond to filters, which means charts like the political opportunity timeline and the visibility distribution will recalculate their peaks, annotations, and percentages based on the filtered subset. These charts are most informative with no filters applied, but filtering to a specific issue or event type can reveal patterns within that category.

**Key Findings** is the landing page. Eight value boxes summarize key statistics: total events, single-source percentage, five-plus-source percentage, median sources, and coverage multipliers for arrests, organizations, protest size, and urban location. Three themed boxes below present specific numbers grouped by dataset comparison, resource characteristics, and framing. This page provides a complete overview before exploring individual charts.

**CCC vs ACLED Comparison** plots weekly event counts from both datasets side by side, shows the weekly difference between them, and provides a text summary with aggregate statistics. This tab connects to Scott's legibility concept by showing how much protest activity is absent from the curated record that institutions rely on.

**Spatial Coverage** shows an interactive map of protest locations. Points are sized by media source count and colored blue for in-person or red for online events. Clicking any point shows the event's date, location, issue, event type, and source count. The map can be zoomed and panned to explore regional patterns.

**What Gets Covered?** offers eleven visualizations through a dropdown (only the selected chart renders at a time): visibility distribution, average coverage by issue, coverage spread by issue, detailed issue combinations with a category filter, event type breakdowns, arrests and property damage comparisons, organized versus unorganized events with top organizations, repression interactions, political valence, protest size versus coverage, and claims. This tab connects to Almeida's framing process and organizational resource frameworks.

**Geography of Visibility** offers three dropdown views: urban versus rural coverage by issue, average coverage for the top twenty states by event volume, and a scatter plot of event volume versus average coverage by state with point size reflecting urbanization.

**Coverage Over Time** offers three dropdown views: monthly average media sources overlaid on event volume, monthly trends for the five most common issue categories, and a political opportunity chart showing weekly protest volume annotated with automatically detected peaks labeled by dominant issue and political context. This tab connects to Meyer and Tilly's political opportunity structure framework.

**About the Data** provides dataset descriptions, a CCC dataset summary, and a variable definitions table.

## Technical Details

The dashboard is built in R using Shiny and shinydashboard. Charts use Plotly and ggplot2. Preprocessing scripts are included in the R and scripts directories.
