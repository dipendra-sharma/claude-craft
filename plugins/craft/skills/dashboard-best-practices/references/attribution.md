# Attribution — explaining why success and failure moved

Read this when a dashboard must answer *why* a metric changed, not just *that* it changed — for good outcomes (conversions, successful requests, revenue, activation) and bad ones (errors, latency, churn, drop-off). Tool-agnostic.

## Contents
1. The core shape: good ÷ valid
2. Defining success and failure
3. Showing both sides together
4. Error taxonomy
5. Breakdown dimensions
6. Attributing a change: contribution, mix vs rate
7. Linking outcome to cause: overlays, versions, experiments
8. Funnels and cohorts
9. Success attribution specifically
10. Impact quantification
11. Starting frameworks for service dashboards
12. Honest limits

---

## 1. The core shape: good ÷ valid

Express every success or reliability indicator as

> **good events ÷ valid events**

- Checkout success = paid orders ÷ checkout attempts.
- Request success = requests served correctly and within target ÷ all valid requests.
- Activation = users who completed the key action within 7 days ÷ users who signed up.

The same shape works for business and system metrics, which lets business and engineering dashboards speak the same language. "Valid" matters: exclude bot traffic, health checks, test accounts — and write the exclusion into the metric definition.

The error rate is the complement (1 − success rate). Show whichever the audience reasons in, but **always keep the numerator and denominator available** (see §3).

## 2. Defining success and failure

Count three kinds of failure, not just crashes:
- **Explicit** — the system said it failed: HTTP 5xx, exception, crash, declined transaction.
- **Implicit** — it said it succeeded but didn't: HTTP 200 with an empty or wrong body, an order created with a zero total, a job that "completed" with no output.
- **By policy** — correct but too slow or too late: over the latency target, delivered after the promised time.

Counting only explicit errors makes dashboards look healthier than users experience. Success must mean *the user got what they came for*, not *nothing threw*.

## 3. Showing both sides together

- **Rate + count + volume on one tile or one row.** Success rate alone hides scale; error count alone hides whether traffic grew. A rise in errors with a proportional rise in traffic is growth, not a regression.
- **Plot numerator and denominator separately** for ratio KPIs, next to the ratio. Both can rise while the ratio falls — a new low-quality channel, bot traffic, a tracking change.
- **Same scale, same breakdowns for success and failure.** A checkout board shows successful payments and failed payments by the same platform/version/region split, so a drop in success can be matched to a rise in a specific failure — or to a drop in attempts.
- **Latency split by outcome.** Chart latency for successful and failed requests separately. Fast failures pull a mixed average down and make things look better as they get worse; slow failures are the worst experience of all.

## 4. Error taxonomy

Classify failures into a small, stable set of categories stored as one field, so every tile can break down by it:

| Class | Examples | Whose problem |
|---|---|---|
| Expected / user | validation errors, wrong password, user cancel, card declined, 4xx | product and UX — high rates suggest confusing flows |
| Dependency | payment provider down, third-party timeout | vendor management, fallbacks |
| Unexpected / system | 5xx, timeouts, crashes, unhandled exceptions | engineering reliability |
| Policy | over latency target, late delivery | performance and capacity |
| Unknown / other | anything unclassified | instrumentation |

- **Don't mix expected and unexpected failures in one reliability number.** A spike in "card declined" is a business signal, not an outage; mixing them blurs both.
- **Show the unknown/other bucket as its own tile or series.** When it grows, classification is breaking and every other breakdown gets less trustworthy.
- **New vs known errors**: after a release, the most useful view is *which error types are new, which disappeared, which persisted*.

## 5. Breakdown dimensions

Most "why did it move?" questions resolve to one of a short list. Instrument success and failure with the same ones:

- **Change**: release/version, build, feature flag state, experiment arm, config version.
- **Where**: region, data centre/zone, host group, endpoint/route, screen/page, feature.
- **Who**: platform (iOS/Android/web), app version, customer tier/plan, new vs returning, market, cohort.
- **How they arrived**: channel, campaign, referrer, partner.
- **Dependency**: downstream service, payment provider, carrier.

Rules:
- **Low-cardinality dimensions on dashboards, high-cardinality ones in evidence.** Tier, platform and region are breakdowns; user ID, order ID and request ID belong in logs, traces and row-level drill-down. Every distinct tag value on a metric creates a new series, which costs money and makes charts unreadable.
- **Top-N plus "other".** Show the top 5–10 segments by contribution and fold the rest into "other" — and keep "other" visible.
- **Minimum sample size.** Hide or grey segments below a volume threshold, and say what the threshold is. A 12-user segment at 50% conversion is noise.

## 6. Attributing a change: contribution, mix vs rate

When a total or rate moves, the dashboard should answer: **which segments explain the change, and how?**

**Rank segments by contribution to the change, not by their own change.** A segment whose rate fell 40% but carries 0.5% of traffic explains almost nothing; a segment that fell 3% on 60% of traffic explains most of it.

For counts, contribution is simple: segment Δ ÷ total Δ.

For rates, split the change into **mix** and **rate** effects. With wᵢ = segment share of volume and rᵢ = segment rate, period 0 → period 1:

- **Rate effect** = Σ wᵢ₀ · Δrᵢ — segments themselves got better or worse.
- **Mix effect** = Σ Δwᵢ · rᵢ₀ — traffic shifted toward higher- or lower-rate segments.
- **Interaction** = Σ Δwᵢ · Δrᵢ — report separately rather than hiding it in either.

(Weight choices vary — some use period-1 weights for one term. Pick one convention, write it in the tile description, and keep it.)

Why this matters: conversion can fall while *every* segment holds steady, because traffic shifted to a low-intent channel. That is a marketing-mix story, not a product regression, and the fix is completely different. This is also how Simpson's paradox shows up on dashboards.

Tile patterns that make this visible:
- **Contribution bar** (waterfall): previous value → +/- per segment → current value.
- **Size vs rate scatter** per segment across two periods (sometimes called a comet chart): x = volume, y = rate, a tail from last period's position to this period's.
- **Table**: segment · volume (then/now) · rate (then/now) · contribution to Δ, sorted by absolute contribution.

## 7. Linking outcome to cause

- **Overlay changes on every time-series tile**: deploys (with version), flags, experiments, config, pricing, campaigns, incidents, and data-pipeline outages. The line-up between a change marker and a step in the metric is the fastest first hypothesis.
- **Version comparison**: for each release, success rate, error rate, latency, and new/resolved/persisting error types, against the previous version *at the same traffic share* (early adopters differ from the general population — compare during the same window).
- **Controlled comparison wherever possible**: A/B test arms, flag on vs off, canary vs baseline. This is the only kind of breakdown that supports a causal claim.
- **Business beside system**: checkout latency and payment errors next to cart abandonment and revenue per minute. When they move together, the dashboard tells engineering the business cost and tells business the technical cause.
- **Click to evidence**: every error tile opens the failing requests, logs, traces or rows; every success tile opens the underlying orders, users or sessions — with segment, time range and filters carried over.

## 8. Funnels and cohorts

**Funnels**
- Show each step's conversion **relative to the previous step** (where people are lost) and **relative to the first step** (overall yield).
- Break the funnel down by the attribution dimensions (platform, channel, version). If the tool's funnel chart cannot break down, use a grouped bar or table of step conversion per segment.
- Pair each drop-off with the failure reasons at that step (validation errors, payment declines, timeouts) — the funnel says *where*, the error taxonomy says *why*.
- State the window ("within one session", "within 7 days") and whether steps must be in order.

**Cohorts**
- Group users by when they started (signup week, first purchase month) and track each cohort's retention or activation over time.
- Cohorts expose change that running totals hide: if every new cohort retains the same, nothing you shipped mattered — regardless of how the cumulative user count looks.
- Define the cohort at its start, so churned users stay in the denominator.

## 9. Success attribution specifically

Teams instrument failure carefully and success loosely, so they can explain every drop and none of the gains.

- **Instrument wins with the same dimensions as failures** — release, flag, channel, segment — so a lift can be attributed exactly like a regression.
- **Pair every success metric with guardrails** — latency, error rate, refunds, churn, support contacts, the other side of a marketplace — each with an agreed threshold. A "win" that quietly hurts a guardrail is not a win.
- **Label marketing attribution models** on the tile: model (first-touch, last-touch, linear, time-decay, position-based, data-driven) and lookback window. Different models give credit differently; credit is not cause. Where it matters, cross-check with an experiment or holdout.
- **Celebrate with evidence**: link the success tile to the experiment result, release note or campaign that explains it.

## 10. Impact quantification

Translate failures into the audience's units so incidents can be ranked:
- **Users affected** (unique users who saw ≥1 failure), not just failure count.
- **Orders or transactions lost** = failed attempts × historical completion-after-retry gap.
- **Revenue at risk** ≈ failed attempts × average order value (label it an estimate).
- **Error budget burned** for reliability targets: remaining budget and the current burn rate (how fast the budget is being spent relative to plan).

And success into the same units: incremental orders, revenue, activated users attributable to the change — with the comparison method stated.

## 11. Starting frameworks for service dashboards

- **Four golden signals**: latency, traffic, errors, saturation.
- **RED** per service: Rate, Errors, Duration — how users experience it.
- **USE** per resource: Utilisation, Saturation, Errors — which resource is the limit.
- Lay out **one row per service in request-flow order**, rate and errors on the left, duration on the right — a failure's origin shows as the first row to turn red.
- **Service level objectives**: show the target, current attainment over the window, error budget left, and burn rate. A dashboard with no alert or objective behind it only gets looked at after users have already noticed.
- **Low-traffic flows**: one failure swings the rate wildly. Use longer windows, group related flows, or add synthetic traffic.

## 12. Honest limits

- **Breakdowns show association, not cause.** A segment that moved with a deploy is a lead. Automated "top contributor" or "root cause" features rank correlations; treat their output as hypotheses.
- **Watch for confounders**: a release rolled out first to one region at the same time as a regional campaign.
- **Early adopters are different**: new versions are first used by more engaged users, which flatters early metrics.
- **Write the caveat where the decision is made** — in the tile description of any attribution tile that people will act on.
