---
name: dashboard-best-practices
description: "Tool-agnostic playbook for designing, building, reviewing and fixing dashboards — business analytics and observability alike. Owns dashboard purpose and audience, metric definitions, layout, chart choice per tile, filters and their wiring, default time ranges and granularity, period comparisons, the incomplete-period trap, drill-down paths, and attributing BOTH success and failure to a cause (which version, platform, channel, segment or deploy drove the win or the error). Also covers trust (freshness, ownership, single metric definition), query cost, and dashboard sprawl. Load whenever someone wants to create, plan, restructure, critique or clean up a dashboard, KPI board, health or monitoring board, service overview, funnel or conversion board, executive or ops report, or asks 'what should go on this dashboard', 'which chart for this', 'how should the filters work', 'what time range', 'why don't these two dashboards agree', 'why did this number drop', 'show what caused the errors / what drove the growth' — in Metabase, Datadog, Grafana, Looker, Tableau, Power BI, Superset or hand-built. Trigger even if the word dashboard is not used but the user is laying out metrics for people to monitor. SKIP for writing chart-rendering code or picking a palette in code (dataviz owns that), for tuning the SQL behind a tile (database-best-practices), and for setting up alerts or monitors with no dashboard involved."
---

# Dashboard best practices

**The governing law: a dashboard exists to change a decision.** If nobody would act differently after looking at it, it is decoration — and decoration still costs queries, attention and trust. Every tile, filter and default below is judged by one question: *does it help this audience see what is happening, why, and what to do next?*

"Why" is the part most dashboards skip. A tile that says *errors went up* is half an answer. The other half is *which version, which platform, which endpoint, which customers* — and the same is true for good news. A conversion spike nobody can explain cannot be repeated. So this skill treats **attribution of success and of failure** as a first-class design goal, not a drill-down afterthought.

**This skill is about judgment, not a tool.** Guidance is written for any dashboard tool. Where a specific tool has a trap that silently breaks a rule, it is noted in `references/tool-notes.md` — a reference to verify, not a rule to follow.

## Skill chaining

| Invoke | When | It owns |
|---|---|---|
| `dataviz` | you are writing code that renders a chart (HTML, React, plotting libraries) or picking colours in code | palette values, mark specs, chart code. This skill owns *what* to show and *why*; that one owns *drawing it* |
| `database-best-practices` | the SQL behind a tile is slow, expensive, or you are deciding what table/model a metric should come from | query shape, indexes, pre-aggregation tables, cost |
| `coding-best-practices` | you write dashboard-as-code (JSON, Terraform, API scripts) | code quality of that code |

`references/*.md` are files to **read**, not skills to invoke. Open the one the current decision depends on:

| File | Open when |
|---|---|
| `references/visualization.md` | picking a chart, axes, colours, number format, titles; checking a tile is statistically honest |
| `references/filters-and-time.md` | choosing filters, wiring them, default range and grain, comparisons, partial periods, time zones, drill-down |
| `references/attribution.md` | the dashboard must explain *why* a success or error metric moved; funnels; error taxonomy; deploy/cohort/channel breakdowns |
| `references/tool-notes.md` | you are working in a specific tool and need to know where it deviates from the generic rule |

**One reply, one budget.** When reviewing, cap at the 5–7 highest-impact issues across everything loaded, unless the user asks for an exhaustive pass.

## How to operate

**Establish the context first — it changes every answer.** Ask for (or infer and state) the ones that matter:
- **Who** looks at it, and **how often** — on-call engineer every few minutes, product manager daily, executive monthly.
- **What decision** it supports — "roll back or not", "which market to invest in", "is the launch healthy".
- **Where the data comes from** and how fresh it is — live metrics, hourly warehouse loads, daily batch.
- **Which tool** — only to look up traps in `tool-notes.md`.

**When designing a new dashboard**, walk the recipe below and produce the spec in "Output: dashboard spec". Don't place a single tile before you can say the dashboard's purpose in one sentence.

**When reviewing an existing one**, first state its purpose and audience as you understand them (if you can't, that is finding #1). Then lead with what produces **wrong or misleading readings** — unwired filters, missing denominators, averaged percentiles, partial periods, mismatched definitions — before layout and style. Use the checklist at the end.

**When asked "why did X move"** on a dashboard, answer with the attribution method in `references/attribution.md`, and say which tiles or breakdowns are missing if the dashboard cannot answer it.

## The recipe

### 1. Purpose, audience, type

Write one sentence: *"<Audience> uses this <how often> to decide <decision>."* Then pick the type — it sets density, range, refresh and layout:

| Type | Question it answers | Typical shape |
|---|---|---|
| **Operational / monitoring** | Is something broken right now? Where? | Few big signals, short range, fast refresh, red/amber state, links to logs and traces |
| **Analytical / diagnostic** | Why did this change? Which segment? | Breakdowns, comparisons, filters, drill-down |
| **Strategic / executive** | Are we on track? | Few KPIs vs target and last period, weekly/monthly grain, links down |

A dashboard that tries to be all three becomes none. If an audience needs two types, build two linked dashboards.

**One dashboard, one story.** If the purpose sentence needs an "and", consider a split.

### 2. Questions → metrics → definitions

List the 3–7 questions the audience asks, then the metric that answers each. For every metric, write the definition before building the tile:

- **Numerator and denominator** — "paid orders ÷ checkout sessions", never just "conversion".
- **Unit and grain** — per request, per user, per order, per day.
- **Inclusions and exclusions** — test accounts, internal traffic, bots, refunds, retries.
- **Direction of good** — up or down. Latency and cost improve downward; the colour and arrows must follow.
- **Target or threshold** — SLO, goal, budget, or "last period" as the baseline.
- **Owner** — who answers when the number looks wrong.

Define each metric **once**, in a shared model, metric or saved query, and reuse it everywhere. Two dashboards computing "active users" two ways will disagree, and people will stop trusting both.

Prefer **outcome metrics** (success rate, revenue, activation, latency users feel) over **activity metrics** (page views, raw event counts) and vanity totals that only go up. For services, start from a method — RED (rate, errors, duration) for request-driven services, USE (utilisation, saturation, errors) for resources, or the four golden signals (latency, traffic, errors, saturation) — and show **symptoms users feel before internal causes**.

### 3. Layout

- **Inverted pyramid**: the most important signal top-left; importance falls off down and to the right; general → specific.
- **Headline row first**: 3–6 KPIs, each as *value + comparison + trend + target*. A bare number is not information.
- **Then sections**, one per question or per subsystem, each with a short text header. Inside a section, left-to-right follows cause → effect or funnel order.
- **The key story fits on one screen** without scrolling. Aim for roughly 6–12 tiles above the fold, and treat 20–25 tiles as a hard ceiling for the whole dashboard; beyond that, split into linked dashboards.
- **Consistent shapes**: same metric, same chart type, same colour for the same series everywhere on the dashboard.
- **A text card at the top**: purpose, audience, owner, data freshness, time zone, how to use the filters, links to related dashboards and runbooks.

### 4. Each tile

Every tile must be readable in isolation — it will be screenshotted into a chat without its neighbours.

- **Chart by question** — see the table in `references/visualization.md` §1. Defaults: bars to compare, lines for time, single number + comparison for status, tables for exact lookups. Avoid pies beyond five slices, gauges, 3D and dual axes.
- **Title says what is measured; subtitle gives the precision** — definition, unit, grain, filter scope. On static reports, the title may state the takeaway.
- **Context on the tile**: comparison period, target/threshold line, and the denominator (volume) near every rate.
- **Honest statistics**: percentiles not averages for skewed metrics, never averaged percentiles, bars from zero, units everywhere, sample size visible for small segments. Details in `references/visualization.md` §5.
- **Description** on every tile: definition, source, owner, what "bad" looks like.

### 5. Filters and time

Full detail in `references/filters-and-time.md`. The rules that cause the most damage when broken:

- **Few filters, on the dimensions people actually slice by** (time, environment, platform/service, region, segment) — and on the dimensions you will use to attribute change.
- **Every filter is wired to every tile it applies to.** An unwired tile looks exactly like a filtered one. Label tiles that deliberately ignore a filter.
- **Defaults are the dashboard** — most viewers never change them. Default to the most useful view, and state what "All" includes.
- **One global time range for all tiles**; relative ranges for living dashboards, absolute ranges for reports and incident reviews.
- **Default range and grain match the type**: operational ≈ last 1–4 hours at minute grain; daily health ≈ last 14–30 days daily; executive ≈ quarter or trailing 12 months weekly/monthly.
- **Comparisons align weekdays** (7 or 364 days back, not the same calendar date) and are labelled.
- **The current period is partial** — exclude it, mark it, or compare like-with-like elapsed time. A half-day bar looks like an outage.
- **State the time zone and week start.** Daily numbers shift with both.
- **Overlay changes** (deploys, flags, campaigns, incidents, data outages) on time-series tiles.
- **Drill-down carries context**: overview → segment → detail → raw rows/logs/traces, with the clicked value, time range and filters passed along.

### 6. Attribution — success and failure, both

Full method in `references/attribution.md`. The design rules:

- **Pair every outcome with its denominator.** Show success rate *and* volume; error rate *and* error count *and* total traffic. A rate without volume hides scale; a count without traffic hides whether anything is actually worse.
- **Show both sides of the same event.** A checkout board shows successful payments *and* failed payments on the same scale and breakdowns, so a drop in success can be matched to a rise in a specific failure — or to a drop in attempts.
- **Break down success and failure by the same dimensions** — version/release, platform, region, endpoint or feature, customer tier, channel/campaign, cohort. If errors are split by version, successes must be too, or you cannot tell whether the new version is worse or merely bigger.
- **Count all three kinds of failure**: explicit (5xx, crash, decline), implicit (reported success but wrong result), and by policy (correct but slower than the target). Success means the user got what they came for, not that nothing threw.
- **Split latency by outcome** — fast failures drag a mixed average down and make things look better as they get worse.
- **Classify failures.** Expected (validation, user cancel, declined card, 4xx) vs unexpected (timeouts, 5xx, crashes); by error type or code. Keep an "unknown/other" bucket visible — its growth is itself a finding about instrumentation.
- **Attribute the delta, not just the level.** When a total moves, show which segments contributed how much of the change, and whether it came from **rate** changes (the segment got worse/better) or **mix** changes (the segment got bigger/smaller).
- **Put changes on the timeline.** Deploys, flags, experiments, campaigns and incidents as overlays — for wins as much as for regressions.
- **Guard every win.** Pair each success metric with guardrails (latency, errors, refunds, churn) and prefer controlled comparisons — experiment arms, flag on vs off, canary vs baseline — when crediting a change.
- **Quantify impact** in terms the audience cares about: users affected, orders lost, revenue at risk, error budget burned.
- **Link to evidence.** Every error tile links to the failing requests, logs, traces or rows; every success tile links to the underlying orders, users or sessions.
- **State what attribution cannot prove.** Breakdowns show association; a segment moving with a deploy is a lead, not a verdict. Say so in the tile description where decisions ride on it.

### 7. Trust

A dashboard people don't trust is worse than none — they act on gut *and* waste time arguing about numbers.

- **Freshness is visible**: "data as of" timestamp or pipeline lag on the dashboard. Stale cached numbers look exactly like live ones.
- **Data-quality signals on the board** for important sources: row/event counts, share in "unknown", ingestion lag. A metric drop caused by missing data must be distinguishable from a real drop.
- **Owner and last-reviewed date** in the header text card.
- **Reconcile against a known number** (finance totals, billing, a source-of-truth count) when a dashboard is first built and after definition changes.

### 8. Performance

- **Fewer queries per load**: every tile is a query; one query feeding several tiles beats many near-duplicates.
- **Filter early, aggregate before the dashboard**: pre-aggregated tables or rollups for heavy metrics; don't scan raw events on every load.
- **Cheap defaults, required filters on expensive data**; turn off auto-apply of filters on heavy boards so users set several, then run once.
- **Cache to match the data's load schedule**; don't refresh faster than the data changes.
- **Split** a slow dashboard into an overview and linked detail pages that only load when opened.

### 9. Lifecycle

- **Parameterise instead of copying** — one dashboard with a filter, not one per team/service/market.
- **Name clearly and mark drafts** (`TMP:`, `DRAFT:`), keep production dashboards in a curated collection or folder.
- **Version it** — dashboards as code where the tool allows, or at least a change note in the header.
- **Review usage every quarter**; archive dashboards nobody opened or changed in ~3 months. Ad-hoc investigation belongs in notebooks or saved questions, not new dashboards.

## Anti-patterns — fix on sight

- Filters not wired to every tile, with nothing saying so.
- Rates with no volume; counts with no traffic.
- Averages of latency; averaged percentiles.
- A partial current period plotted like a full one.
- Only errors instrumented, never successes (or vice versa) — nothing to attribute against.
- Error breakdowns with no matching success breakdown.
- The same metric defined differently on two dashboards.
- Pies with many slices, gauges, 3D, dual axes, rainbow palettes, red/green as the only signal.
- Green arrow on a rising bad metric (latency, cost, churn).
- Dozens of tiles "just in case"; one dashboard per team, copied.
- No owner, no description, no freshness, no time zone.
- Default range that scans all history.

## Review checklist

Run in this order — correctness first, then usefulness, then polish.

**Correctness**
- [ ] Every filter changes every tile it should (set each filter to an unusual value and watch).
- [ ] Every rate shows its numerator/denominator or volume; both halves see the same filters.
- [ ] Latency and skewed metrics use percentiles; no averaged percentiles; bars start at zero.
- [ ] The current partial period is excluded, marked, or compared like-for-like.
- [ ] Time zone and week start are stated; comparisons align weekdays.
- [ ] Metric definitions match the shared/official definition; totals reconcile to a known source.

**Usefulness**
- [ ] Purpose sentence and audience are written on the dashboard.
- [ ] Headline row: value + comparison + trend + target.
- [ ] Success and failure are both shown, with the same breakdowns, and the delta can be attributed to a segment.
- [ ] Changes (deploys, flags, campaigns, incidents) are overlaid on time series.
- [ ] Every error/success tile drills to evidence with context carried.

**Trust and upkeep**
- [ ] Freshness, owner, last-reviewed date visible.
- [ ] Load time acceptable with defaults; no default scans of all history.
- [ ] No duplicate copy of this dashboard exists for another slice.

## Output: dashboard spec

When designing, produce this (adapt headings to the request; keep it tight):

```markdown
# <Dashboard name>
**Purpose:** <Audience> uses this <cadence> to decide <decision>.
**Type:** operational | analytical | strategic   **Owner:** <team/person>
**Data:** <sources> · freshness <lag> · time zone <tz> · week starts <day>

## Global controls
| Control | Values | Default | Applies to | Notes |
|---|---|---|---|---|
| Time range | ... | last 30 days (excl. today) | all tiles | compare: previous period, weekday-aligned |
| <filter> | ... | ... | all / list | "All" includes/excludes ... |

## Metric definitions
| Metric | Numerator / denominator | Grain | Exclusions | Good direction | Target |
|---|---|---|---|---|---|

## Layout
### Row 1 — Headline
| Tile | Chart | Comparison / target | Drill-down |
|---|---|---|---|
### Row 2 — <section: e.g. Where is it failing?>
...
### Row N — Attribution: what drove the change
...

## Overlays and links
- Events overlaid: ...
- Drill paths: tile → dashboard/view → raw evidence

## Open questions / assumptions
- ...
```

When reviewing, report findings as: **issue → why it misleads or costs → the fix**, ranked most-harmful first, capped at 5–7 unless asked for more.
