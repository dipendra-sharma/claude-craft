# Visualization — choosing and drawing each tile

Read this when picking a chart type, setting axes or colours, or reviewing whether a tile is honest. Everything here is tool-agnostic.

## Contents
1. Question → chart
2. Encoding: what the eye reads accurately
3. Axes, scales and number format
4. Colour
5. Statistical honesty
6. Tables
7. Titles and text
8. Accessibility

---

## 1. Question → chart

Pick the chart from the **question the tile answers**, not from the shape of the data. The same numbers answer different questions.

| Question | Use | Avoid |
|---|---|---|
| Are we on target? | Single number + comparison + sparkline; bullet graph | Gauge, speedometer |
| Compare categories | Bar from zero; dot plot when gaps are tiny | Pie, 3D, radar |
| Rank | Sorted horizontal bar, lollipop | Unsorted bars |
| Trend over time | Line; columns when there are few points; calendar heatmap for daily seasonality | Dual axis, area for several series |
| Part-to-whole | Stacked or 100% bar; pie only for ≤5 slices of one total | Stacked area when the parts matter |
| Distribution | Histogram, percentile lines (p50/p95/p99), box plot, heatmap over time | Mean alone |
| Relationship | Scatter; bubble for a third variable | Dual axis |
| Deviation from a baseline | Diverging bar, above/below line | — |
| Flow / funnel | Funnel bar with step conversion, Sankey, waterfall for a bridge | Pie per step |
| Geography | Map of rates (per user, per capita); symbols sized by totals | Map shaded by raw totals — it mostly shows population |
| Exact lookup | Table with conditional formatting or in-row sparklines | Chart |

Rules of thumb:
- **Bars for comparison, lines for time.** Position on a shared scale is the most accurately read encoding.
- **Horizontal bars when labels are long; sort them** — the order is often the answer.
- **More than ~6 lines on one chart → small multiples** (one mini chart per series, same scale) or highlight one and grey the rest.
- **Pie only when all hold**: one total, five slices or fewer, the point is "about a quarter / half". Never compare two pies.
- **Gauges waste space and show no context.** Replace with a number + target + trend, or a bullet graph.
- **Dual axes mislead.** Allowed only for the same measure in two units, or a Pareto chart. Otherwise use two stacked charts sharing the time axis, or index both series to 100.
- **No 3D, no area or bubble size for exact values.** People overestimate area.

## 2. Encoding: what the eye reads accurately

Cleveland & McGill's ranking, most to least accurate:
1. Position on a common scale
2. Position on unaligned scales
3. Length, direction, angle
4. Area
5. Volume, curvature
6. Colour saturation / shading

So: put the value you most want compared on **position**. Use colour for *category* or *highlight*, not for reading exact amounts (heatmaps are the exception — they trade precision for density, which is fine for spotting patterns).

- **Cut non-data ink, within reason**: heavy gridlines, borders, backgrounds, drop shadows, decorative icons. Keep reference lines (target, threshold, zero) — they carry meaning.
- **Aspect ratio changes perceived steepness.** Very wide flat line charts hide change; very tall ones exaggerate it. Aim for average slopes around 45°.

## 3. Axes, scales and number format

- **Bars and columns start at zero. Always.** A truncated bar exaggerates the difference, and marking the axis break does not fully fix it. If the differences are tiny, use a dot plot or chart the difference itself.
- **Lines may start above zero** — the slope is the message. Include zero if values come near it; use 0–100% for shares.
- **Tiles meant to be compared share a y-scale.** Otherwise a flat line and a steep one can mean the same change.
- **Log scale** for multiplicative growth or values spanning orders of magnitude — and say "log scale" on the axis.
- **Short numbers**: 12.4k, 1.3M, 2.1B. Two or three significant figures on headline numbers; excess precision is noise.
- **Units on every axis, tooltip and headline**: ms vs s, % vs percentage points, currency code.
- **Percentage vs percentage points**: 2% → 3% is +1 percentage point, or +50%. Say which.
- **Label lines directly** at their right end instead of a legend when there are few series.

## 4. Colour

- **Categorical palette: 5–7 hues max, fixed order.** More than that and nobody can match colour to legend.
- **The same series keeps the same colour on every tile** of the dashboard. "iOS" is blue everywhere.
- **Grey for context, one saturated colour for the focus.** Highlighting is the cheapest way to make a tile say one thing.
- **Sequential scale** (light → dark) for magnitude; **diverging scale** (two hues through a neutral midpoint) only when there is a meaningful middle — zero, target, last period.
- **Semantic colour (red bad / green good) is fine only with a second cue** — an arrow, a sign, a label. About 8% of men have red-green colour-vision deficiency. Blue/orange is a safer good/bad pair.
- **Mind the direction of "good"**: for latency, error rate and cost, *down* is good. A green up-arrow on rising latency is a lie.
- **Test in greyscale.** If lightness alone can't separate the series, the palette fails.
- **Never let colour be the only signal** (WCAG 1.4.1). Add labels, shapes, dash styles or line weight.

## 5. Statistical honesty

- **Percentiles, not averages, for skewed metrics** (latency, order value, session length). Show p50 and p95/p99; the average hides the tail where the pain is. **Never average percentiles** across hosts or time buckets — it is mathematically meaningless; recompute from raw data or histograms.
- **At low volume, p99 is noise.** Use p95, a longer bucket, or show the count alongside.
- **Rates need their denominators.** "Errors: 1,200" means nothing without "of 3M requests". Show the rate *and* the volume (see `attribution.md`).
- **Small samples**: a segment with 12 users converting at 50% is not a winning segment. Show counts in tooltips or hide segments below a minimum sample size, and say so.
- **Unique counts don't add.** 100 daily users ≠ 700 weekly users. Changing the bucket size changes the value; this is expected, not a bug.
- **Cumulative charts only go up** and hide slow-downs. Show the per-period value for decisions; use cumulative only for progress toward a total.
- **Stacked areas show the total well and the parts badly** — every layer above the first has a moving baseline.
- **Top-N with "Other"**: when showing the top 10, include an "Other" bucket so the whole is visible, and watch its size — a growing "Other" is a finding.
- **Simpson's paradox**: an overall rate can move opposite to every segment's rate when the mix shifts. When a total moves, check the mix (see `attribution.md`).
- **Survivorship**: charts of "active users' retention" silently drop the ones who left. Define the cohort at the start.
- **Smoothing and rolling averages lag and hide spikes.** Label the window ("7-day rolling average") and keep the raw series close by.

## 6. Tables

Use a table when **exact values drive action** — lookups, "which customer", "which endpoint". Use a chart when the **pattern or outlier** is the point.

- More rows than columns. A sensible default sort (usually the metric that matters, descending).
- Right-align numbers, same-width digits, consistent decimals per column.
- Conditional formatting (background shading or in-cell bars) for the one column that matters — not all of them.
- A sparkline per row adds trend without extra columns.
- Cap row count and make the cap visible ("top 20 by error volume").

## 7. Titles and text

- **Label titles on live dashboards, insight titles on reports.** A live dashboard's numbers change, so its tile title must describe what is measured ("Checkout success rate, by platform"). A static report or a screenshot in an incident review can carry the takeaway ("Android checkout success fell 4 points after v5.2").
- **Subtitle carries the precision**: definition, unit, filter, time grain, source. "Paid orders ÷ checkout starts · daily · excludes test accounts."
- **Every tile gets a description** (hover text or info icon): what the metric means, how it is computed, who owns it, what "bad" looks like.
- **Text cards** at the top explain purpose, audience and how to use the filters; text cards between sections act as headers.

## 8. Accessibility

- Chart marks need 3:1 contrast against the background (WCAG 1.4.11); text needs 4.5:1.
- Colour never the only carrier of meaning (see above).
- Provide the data behind a chart (a table view or export) for people who can't read the graphic.
- Don't rely on hover alone for critical information — touch screens and screenshots lose it.
