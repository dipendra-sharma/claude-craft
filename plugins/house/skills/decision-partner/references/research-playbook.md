# Research playbook

For decisions big enough to earn a real research pass — real money, real risk, hard to reverse, or a year of work riding on it. Everyday calls do not need this.

## Contents

- [Turn the crux into searchable questions](#turn-the-crux-into-searchable-questions)
- [Routing by domain](#routing-by-domain)
- [Running subagents in parallel](#running-subagents-in-parallel)
- [Judging a source](#judging-a-source)
- [When sources contradict each other](#when-sources-contradict-each-other)
- [Numbers](#numbers)
- [Knowing when to stop](#knowing-when-to-stop)

## Turn the crux into searchable questions

The crux is usually not searchable as written. "Will this team cope with running its own database?" has no web page. Break it into things that do have answers:

- What does running this actually involve week to week? (docs, postmortems, operator guides)
- What goes wrong for teams this size? (incident writeups, forum threads, issue trackers)
- What does the managed alternative cost at their real numbers? (pricing page, then arithmetic)
- Who moved back the other way, and why? (the disconfirming search)

Three or four questions like that, each with a findable answer, beat one big vague one. Write them down before you start — it stops the drift where twenty minutes of reading produces no answer to the thing that mattered.

## Routing by domain

**Technology and vendor choices.** Official documentation and pricing pages first, changelog and release notes for what actually shipped, the issue tracker for what is broken now. Then the honest layer: postmortems, migration writeups, and threads from people who ran it in production. Marketing pages tell you intent; issue trackers tell you reality.

**Versions and releases.** Always from the registry or the official command, never memory and never a blog post: `npm view <pkg> version`, `pip index versions <pkg>`, `cargo search <crate>`, `gh release list --repo <owner>/<repo>`. For what a project already uses, read its lockfile rather than recalling it.

**Their own systems.** When the decision is about something they own, their data outranks anything you can read on the internet. Their repository for how it is actually built, their error tracker and monitoring for what actually breaks, their analytics for what users actually do, their database for real volumes. A recommendation built on real numbers from their system lands differently from one built on general advice — and it is usually a different recommendation.

**Business and market questions.** Company filings and official announcements over press coverage. Pricing from the vendor's own page, dated, because it moves. Be explicit about the gap between list price and what people actually pay.

**Health, drugs, and clinical questions.** Use the medical literature, trial registries and chemistry databases available rather than a general web search. Prefer systematic reviews and meta-analyses over single studies; note sample size and whether a trial was registered before it ran. Say plainly where the evidence is thin, and say plainly that this is research and not a diagnosis — then still give them the direction they asked for, which is usually "here is what the evidence supports and here is the question worth taking to a doctor."

**Legal, tax and regulatory.** Jurisdiction first — an answer that is right in one country is often wrong next door. Primary sources: the statute, the regulator's own guidance, the official form. Date everything, because rules change and stale guidance outranks nothing. Same rule as health: give the direction, name where a professional is genuinely needed.

**Personal and career decisions.** Research still applies — salary data, market conditions, what the role actually involves day to day, what people who took the same step say a year later. What it cannot supply is their risk tolerance and what they want, so ask for those if they are the crux rather than assuming a generic ambitious person.

## Running subagents in parallel

Send independent questions out at once, in a single batch. Three agents covering three angles beat one agent covering three angles in sequence, and the raw reading stays out of the main thread.

A good split is by angle, not by keyword:

- one on the official case: docs, pricing, stated limits
- one on the lived case: postmortems, migration stories, complaints, what broke
- one on the alternative, researched just as seriously so the comparison is fair
- one on their own system, when the decision touches something they own

Give each agent the crux, not just a topic, so it knows what counts as an answer. Ask each to come back with findings and sources, not a recommendation — the weighing is yours to do, with all of it in view.

Read-only research fans out freely. Anything that builds, installs or tests runs one at a time.

## Judging a source

Not all agreement is evidence. Ten posts repeating one benchmark is one benchmark.

Ranked roughly, best first: primary documents (docs, filings, statutes, source code, the changelog) → data you can inspect (benchmarks with method published, their own telemetry) → practitioner accounts with specifics (postmortems, migration writeups naming versions and numbers) → expert commentary → aggregated opinion → a listicle.

Ask of anything load-bearing: when was it written, does the version still exist, does the author have something to sell, and is there a number in it or only adjectives? A 2021 comparison of two fast-moving tools is a historical document, not a recommendation.

Weight lived experience properly, though. One detailed account from someone who ran the thing for two years at similar scale is worth more than a stack of overview articles — it is where the failure modes live, and failure modes are usually the crux.

## When sources contradict each other

Do not average them and do not quietly drop the inconvenient one. The disagreement is usually the most useful thing you found.

Work out which kind it is:

- **Different context.** Both right, at different scale, version, or jurisdiction. Say which context applies to this person — this resolves most contradictions.
- **Stale versus current.** Check dates and versions; the newer one usually wins, but confirm the change actually happened rather than assuming.
- **Interest.** One party benefits from the claim. Discount, don't discard, and say why.
- **Genuinely unsettled.** Nobody knows yet. Say so, say which side you find more convincing and why, and treat it as a risk in the recommendation rather than pretending it away.

Then carry the resolution into the answer in one line. "Older comparisons say X; that changed in version 14, which is what you'd be installing."

## Numbers

Any number that affects the decision gets computed, with the calculator, not estimated in your head — including the easy-looking ones. Show the arithmetic in one line so they can check it.

Compare like with like: monthly versus monthly, with the same usage assumptions, including the costs people forget (transfer, support tier, the engineer-hours of running it). State the assumptions next to the result, because a cost comparison is only as good as its assumed volume.

When a number is a guess, label it a guess and give the range. A confident wrong number does more damage than an honest range.

## Knowing when to stop

Stop when new sources stop changing the answer. That is the real signal, and it usually arrives sooner than it feels like it should.

Also stop when the remaining uncertainty is something research cannot settle — their appetite for risk, what they actually want, how the market moves next year. That uncertainty belongs in "what would make this wrong", not in another hour of searching.

And stop when the cost of more research exceeds the cost of being wrong. For a reversible choice, a fast decision plus a plan to revisit beats a perfect decision made three days late. Say that out loud when it applies: "this is cheap to undo — pick A, revisit in a month if X happens."
