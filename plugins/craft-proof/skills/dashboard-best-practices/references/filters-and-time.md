# Filters, time ranges and drill-down

Read this when adding or reviewing filters, choosing default time ranges, building period comparisons, or wiring navigation between dashboards. Tool-agnostic; tool quirks live in `tool-notes.md`.

## Contents
1. Choosing which filters exist
2. Wiring filters correctly
3. Filters that silently lie
4. Default time range and grain
5. Comparisons
6. The incomplete current period
7. Time zones, week starts, rollups
8. Event overlays
9. Drill-down and navigation

---

## 1. Choosing which filters exist

A filter is a promise that every tile will answer the same question for a different slice. Every extra filter multiplies the states the dashboard can be in — and the states nobody tested.

- **Expose the 3–5 dimensions the audience actually slices by**, usually: time, environment, platform/service, region/market, customer segment. Everything else belongs in drill-down or ad-hoc exploration.
- **Filter on the attribution dimensions** — the ones you will use to explain a change (version, platform, channel, cohort). If a filter never explains anything, drop it.
- **One parameterised dashboard beats N copies.** Don't clone a dashboard per team, service, market or customer; use a filter or variable and a saved view / bookmarkable link per slice. Copies drift apart within weeks.
- **Required filters on expensive data.** If an unfiltered load scans a year of raw events, require a time range or entity filter, or set a cheap default.
- **Defaults are the dashboard.** Most viewers never touch a filter. The default state must be the most useful view, not "everything, all time".
- **"All" must mean all.** Decide explicitly whether the default includes test accounts, internal traffic, bots, staging. Put that decision in the dashboard description.

## 2. Wiring filters correctly

- **Every filter is wired to every tile it plausibly applies to.** A tile that ignores a filter looks identical to one that obeys it. This is the single most common dashboard bug.
- **If a tile deliberately ignores a filter, say so in its title** — "Total revenue (all regions)". Otherwise readers assume it is filtered.
- **Audit after every change.** Changing a filter's type, renaming a field, or swapping a tile's underlying query often silently disconnects wiring. After edits, set each filter to an unusual value and confirm every tile changes (or is labelled as not changing).
- **Cascade dependent filters** (country → city, service → endpoint) so users can't pick combinations that return nothing.
- **Clickable tiles that set a dashboard filter must not be filtered by that same filter** — otherwise clicking one bar collapses the chart to that single bar.
- **Show the active filter values on the dashboard** — in titles, a header text card, or a visible filter bar — so screenshots and shared links stay honest. A screenshot of "Error rate" that was secretly filtered to one region causes bad decisions.
- **Filters and the URL**: shareable links should carry filter and time state, so "look at this" means the same thing to the recipient.

## 3. Filters that silently lie

- **"Is not X" drops empty values too.** In SQL, `col <> 'X'` is not true for `NULL`, so rows with no value vanish. Either map empty to an explicit label ("Unknown", "Unassigned") upstream, or write `col <> 'X' OR col IS NULL`.
- **Filtering on a joined dimension drops unmatched rows.** An inner join to a "customers" table silently removes events with no matching customer. Check totals with and without the filter.
- **Filtering a numerator but not the denominator** produces rates above 100% or absurdly low. Both halves of a ratio must see the same filters.
- **Filtering after aggregation vs before** gives different answers (e.g. "users with >3 orders" vs "orders from users with >3 orders"). Name which one the tile does.
- **High-cardinality filters** (user ID, order ID, trace ID) belong in drill-down or search, not a dropdown of 2 million values.
- **Stale filter options**: dropdown values cached from last month hide new platforms/versions. Prefer values computed from the current data.

## 4. Default time range and grain

Match the default to how often people look and what decision they make.

| Dashboard type | Default range | Grain | Refresh |
|---|---|---|---|
| Operational / on-call | last 1–4 h (up to 24 h) | 1–5 min | 30 s – 5 min |
| Daily product / business health | last 14–30 days | daily | hourly or daily |
| Weekly review / analytical | last 8–13 weeks | daily or weekly | daily |
| Executive / strategic | quarter-to-date, trailing 12 months | weekly or monthly | daily |

- **Relative ranges** ("last 7 days") for living dashboards; **absolute ranges** for incident reviews, reports and anything you'll cite later — so the numbers are reproducible.
- **All tiles share one global time range.** If a tile must differ (e.g. a "year-to-date" number on a 7-day dashboard), put the range in its title.
- **Choose a grain that gives ~30–300 points** in view. Too few hides shape; too many turns into noise and slow queries.
- **Don't auto-refresh faster than the data changes.** Warehouse data loaded hourly gains nothing from a 30-second refresh except cost.

## 5. Comparisons

A number without a comparison is not information. Every headline value needs at least one of: previous period, same period last year, target, or SLO.

- **Previous period**: "last 7 days vs the 7 days before". Good default for operational and product dashboards.
- **Align weekdays.** For daily data, compare against 7 days ago or 364 days ago (52 weeks), not the same calendar date — otherwise a Saturday is compared against a Monday. Label it ("vs same weekday last year").
- **Flag holidays and known events** in comparisons; a year-over-year dip on a moved holiday is not a trend.
- **Show the comparison the same way everywhere**: absolute delta, % change, or both — pick one convention for the dashboard. For rates, use percentage points ("+1.2 pp"), not percent of a percent.
- **Overlay the comparison period as a faint line** on time-series tiles, rather than a separate tile.
- **Targets and SLOs as reference lines**, not just as numbers in a text card.

## 6. The incomplete current period

The last bucket of a chart is usually partial — today, this week, this month. A partial bucket looks like a crash and has triggered many false alarms.

Pick one, consistently:
- **Exclude** the current period from trend charts (end at "yesterday" / "last full week").
- **Mark it** visually (dashed segment, lighter bar, "partial" label).
- **Compare like with like**: month-to-date vs the same number of days last month.
- **Project** it, clearly labelled as a projection.

Headline numbers labelled "this month" must say "MTD" (month to date) and compare against the same elapsed span.

## 7. Time zones, week starts, rollups

- **State the time zone on the dashboard.** Daily buckets shift by the time zone; a UTC "day" and a local "day" disagree on every daily number. Pick the business's zone for business dashboards; UTC is usually fine for system dashboards shared across regions.
- **State the first day of the week.** Weekly totals change with it.
- **Automatic rollup changes values when you zoom.** Tools re-bucket as the range changes; a 5-minute spike averaged into a 1-hour bucket disappears. For spikes, use `max` rollup or a shorter range. For counts, use `sum`. For latency, recompute percentiles, don't average them.
- **Unique counts are not additive** across buckets or segments. Weekly unique users ≠ sum of daily unique users; the sum of per-platform uniques exceeds the total when users use two platforms.
- **Late-arriving data**: if events land hours late, the most recent buckets are undercounted. Know your data's lag and either exclude the lag window or mark it.

## 8. Event overlays

Put **what changed** on the same time axis as **what happened**:
- deploys and releases (with version),
- feature flag and experiment changes,
- config and pricing changes,
- incidents and maintenance windows,
- marketing campaigns and launches,
- data pipeline incidents (so a dip caused by missing data is not mistaken for a real one).

This is the fastest way to connect a metric change to a cause, for both regressions and wins. Keep overlays scoped to the filter (a deploy to service A should not mark service B's chart).

## 9. Drill-down and navigation

Design the path **overview → segment → detail → raw evidence**:
1. **Overview**: headline KPIs and health, across everything.
2. **Segment**: the same metric broken down by the attribution dimensions.
3. **Detail**: one segment over time, with overlays.
4. **Raw evidence**: the rows, logs, traces, sessions or orders behind the number.

- **Carry context on every hop.** Clicking a bar should open the next view with that segment *and* the current time range and filters applied.
- **Every alert links to a dashboard, and every error tile links to raw evidence.** Most visits to an operational dashboard should start from a signal, not from browsing.
- **Keep each level light.** Heavy detail on the overview slows everyone down; push it one click deeper.
- **Link sibling dashboards** (the service's dashboard ↔ its dependencies; the product funnel ↔ the marketing channel view) in a text card at the top.
