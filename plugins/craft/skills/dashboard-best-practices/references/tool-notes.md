# Tool notes — reference only

The skill's guidance is tool-agnostic. This file maps a few generic practices to how specific tools behave, because each tool has traps that break a generic rule silently. **Treat everything here as a hint to verify against the tool's current documentation and the installed version** — tools change behaviour between releases, and these notes were gathered in September 2026.

Open only the section for the tool in use.

## Contents
- Business analytics tools (Metabase and similar)
- Observability tools (Datadog and similar)
- Others (Grafana, Looker)

---

## Business analytics tools — Metabase

| Generic practice | How it shows up |
|---|---|
| Wire every filter to every tile (`filters-and-time.md` §2) | Filters auto-connect to matching fields, but **changing a filter's widget type disconnects every tile**. Re-check wiring after any filter edit. |
| Filters on SQL tiles | Native SQL questions need *field filters* (not plain text variables) for filter wiring, linked filters and drill-through to work. |
| Cascading filters | Linked filters only follow relationships declared in the data model, not joins written inside a question or model. |
| Time grain control | A "time grouping" parameter changes the bucket size, not which rows are returned — pair it with a date filter. |
| Tabs | A filter appears only on tabs where at least one tile is wired to it. |
| Heavy dashboards | Auto-apply of filters can be turned off so users set several filters, then run once. |
| Caching (`SKILL.md` performance) | Policies: duration, schedule, or adaptive. Precedence: question > dashboard > database > default. Cache refresh ahead of expiry doesn't work with row/column security; without it, the first viewer after expiry waits for the full query. |
| Time zone | Report time zone affects display and ignores `timestamp without time zone` columns. First-day-of-week setting does not affect native SQL questions — handle it in SQL. |
| "Is not" and empty values | "Is not X" filters have historically excluded empty values too (SQL `NULL` semantics). Verify on your version; label empties upstream. |
| Drill-through | Click behaviour can send a clicked value into another dashboard's filter or a URL — use it for overview → detail. |
| Single source of truth | Use models and shared metrics / segments so a definition lives in one place. |
| Segmented funnels (`attribution.md` §8) | The funnel chart shows each step vs the first step (previous step in the tooltip) but does not break down by another dimension. For segmented funnels, use grouped bar/row charts or combine saved questions in SQL. |
| Event overlays (`filters-and-time.md` §8) | Events and timelines mark launches or outages on individual time-series questions, but not on dashboard cards. For change context on a dashboard, add a separate "recent changes" table card. |
| Segment vs baseline | X-rays "compare to the rest" gives a quick one-segment-vs-everyone view. |

## Observability tools — Datadog

| Generic practice | How it shows up |
|---|---|
| One parameterised dashboard, not copies | Template variables (default `*`). Saved views store filter sets. Link form: `&tpl_var_<NAME>=<VALUE>`. |
| Show active filter in titles | `$var.value` works in tile titles and text cards. |
| Audit filter wiring | Tiles whose query doesn't reference a variable ignore it. Hovering a variable highlights the tiles it affects. |
| Period comparison with aligned weekdays | Use `calendar_shift()` (time-zone aware). `day_before`, `week_before`, `month_before` are older functions — check whether they are deprecated in your version. |
| Rollup changes values on zoom | Automatic rollup re-buckets as the range changes; set `.rollup(max|sum|avg, interval)` explicitly where it matters. Unique counts are not additive across rollup buckets. |
| Event overlays | Change overlays show deploys and other changes; they follow the `env` variable and default to production when none is set. |
| Layout | Timeseries at least 4 grid columns wide, log streams at least 6. Groups with coloured headers act as sections; high-density mode shows groups side by side. |
| Service health method | Service-level pages follow RED (requests, errors, latency) — build custom dashboards to match so people don't relearn the layout. |
| SLO tiles | SLOs can be metric-based (good ÷ total), monitor-based or time-slice, and grouped by tag. SLO widgets show status, error budget remaining and burn — prefer them over hand-built "uptime %" numbers. |
| What counts as an error (`attribution.md` §2) | Tracers by default mark server spans as errors only for 5xx and client spans for 4xx. Changing the setting *replaces* the default list, so include 5xx explicitly. Check what your services mark as errors before trusting error-rate tiles. |
| Version comparison (`attribution.md` §7) | Deployment tracking needs consistent `env`/`service`/`version` tags; it then compares versions — new, resolved and persisting error types, latency and error rate per endpoint. |
| "Which tag drove this" | Automated explainers and outlier detection (Watchdog features) rank correlated tags on some widgets and explorers — treat output as hypotheses. |
| Cardinality | Keep user/request IDs out of metric tags; tag-cardinality tools help drop unqueried tags and cut cost. |
| Drill to evidence | Tiles can link to related logs, traces and monitors with the current time range and tags carried over — configure custom links for business context. |
| Governance | Dashboards list shows popularity and last-modified; retire unused ones. Dashboards can be managed as code (API / infrastructure-as-code providers). |

## Others

**Grafana**: `now/d`-style rounding for "today so far" ranges; a dashboard-wide time zone setting; an "Auto" refresh interval; dashboard variables for parameterising; dashboards as code (JSON provisioning).

**Looker**: content guardrails can cap tiles per dashboard (around 25) and per tab (around 20); keep merged-results tiles few; avoid "run on load" for heavily filtered dashboards; cache policies tied to data load schedules.
