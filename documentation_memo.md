# Documentation Memo: U.S. Protest Media Coverage Dashboard

## Purpose

This dashboard uses event-level protest data to examine how media coverage is distributed across U.S. protests. The central variable is the number of distinct media sources covering each event, as recorded by the Crowd Counting Consortium (CCC). The dashboard asks whether certain types of protests consistently receive more or less media attention, and what patterns emerge.

Three course frameworks motivated the analysis. In Chapter 1 of Seeing Like a State, Scott uses scientific forestry to show how institutions reduce complex realities to simplified, measurable categories. The CCC vs. ACLED comparison shows a parallel pattern: CCC records over 126% more protest events than ACLED during their overlapping coverage period, suggesting that the coding criteria that make ACLED reliable also cause it to miss a large share of protest activity.

Almeida's organizational resource framework argues that movements are more likely to emerge from preexisting organizations because these provide recognized leaders, communication channels, and the capacity for bloc recruitment. He distinguishes between activist organizations (SMOs) created for collective action and everyday organizations (schools, churches, unions) that can be mobilized under special circumstances. Lune extends this by showing that organizational fields contain multiple types of groups that support each other even when pursuing different short-term goals. In this data, events with a named organization average 2.03 media sources compared to 1.60 for events without one, though both groups share a median of 1, and about 28% of events have no organization listed.

Meyer argues that external political conditions shape when movements emerge and gain traction, and Tilly's historical analysis shows that social movement activity tracks changes in political context. The political opportunity chart in this dashboard shows protest volume spiking sharply around specific political moments including the Roe v. Wade leak, the Dobbs decision, midterm mobilization, and Gaza solidarity protests, consistent with Meyer's argument that political conditions create windows that movements respond to.

## Intended Audience

The dashboard is intended for students, researchers, and civic observers interested in protest activity and media attention in the United States. All charts are interactive with hover tooltips; no technical background is required.

## Datasets

The Crowd Counting Consortium (CCC), maintained by researchers at Harvard Kennedy School and the University of Connecticut, records every U.S. protest event regardless of size or media attention. The dataset contains over 138,000 events from January 2021 through December 2024, with fields for date, location, issue category, event type, organizations, arrests, property damage, protest size, claims, and political valence. The media source count (n_sources) is the primary visibility measure.

ACLED (Armed Conflict Location and Event Data Project) is an expert-curated global political event dataset. Here it is filtered to U.S. protest events and compared against CCC at the weekly level to measure how many protests do not appear in curated institutional records.

## Tensions and Surprises in the Data

Several patterns in the data complicate straightforward conclusions. The median number of media sources across all events is 1, meaning the typical protest receives minimal coverage regardless of its characteristics. Average differences between categories are real but modest, raising the question of whether structural factors or sheer volume of low-visibility events drive the overall pattern. Protest size is missing for approximately 66% of events, about 28% of events have no organization listed, and the n_sources variable counts distinct outlets rather than their reach or audience size. These limitations are documented in the About the Data tab.

## Navigation

The dashboard has six tabs. Tabs 3 through 6 share a filter panel for date range, issue category, event type, and location; an export button downloads the filtered dataset as CSV.

**Key Findings** presents summary statistics, themed findings, and course framework connections (always uses the full dataset). **CCC vs. ACLED Comparison** plots weekly event counts side by side with aggregate statistics. **Spatial Coverage** maps protest locations sized by media source count and colored by event type (capped at 10,000 points for performance). **What Gets Covered?** offers twelve dropdown visualizations covering visibility distribution, coverage breakdowns by issue/event type, arrests, property damage, organizations, repression, political valence, protest size, and claims. **Geography of Visibility** compares urban/rural coverage, state-level averages, and event volume versus coverage by state. **Coverage Over Time** shows monthly trends overall and by issue, plus a political opportunity chart with automatically detected peaks. **About the Data** provides variable definitions for both datasets and a data limitations section.

## Technical Details

The dashboard is built in R using Shiny and shinydashboard with Plotly for interactive charts, ggplot2 for chart construction, and Leaflet for the spatial map. It is deployed on shinyapps.io.
