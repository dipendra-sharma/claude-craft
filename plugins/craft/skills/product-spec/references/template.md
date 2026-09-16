---
title: <short, human name>
id: <kebab-slug, e.g. offline-reading-mode>
status: Draft | In Review | Approved | In Progress | Done
owner: <name>
reviewers: <names, or delete this line>
date: <YYYY-MM-DD>
type: greenfield | brownfield | config-change
surfaces: <the surfaces touched — e.g. mobile, backend, frontend, infra, web, desktop, CLI, data/ML>
audience: internal | consumer
---

# <Feature / Project Name> — Product Spec

A PRD with SRS-level requirements and acceptance criteria.

> **Delete this blockquote and every italic hint line before you ship the file.** The YAML front-matter above stays, and stays first in the file, and the one-line subtitle under the title stays verbatim — it tells a reader expecting a thin PRD why §8–§12 go deeper. Fill every unmarked section. Include a `[conditional]` section only when its trigger applies — otherwise delete the whole section (never leave "N/A" or a `<placeholder>`). **Section numbers are fixed: deleting a section leaves a gap in the numbering, and you never renumber the rest** — so "§13" means Rollout & Migration in every spec, and a link to it keeps working. Stay at the *what* and *why*: describe behavior and outcomes, never code, file paths, libraries, or architecture. Keep one requirement per line.

## 1. TL;DR

*Two to four plain sentences: what is being built and why. The one paragraph a new developer or an AI reads first.*

<...>

## 2. Problem & Why Now

*The pain, who feels it, and the trigger or evidence that makes it worth doing now.*

<...>

## 3. Goals & Success Metrics

*Measurable outcomes — business and user. Each metric: baseline (if known) → target, by when, and the source the number is read from. If the source doesn't exist yet, it must appear as an `AE-n` in §11 — a metric with no source can't tell you whether this shipped successfully.*

- **Goal:** <outcome>
  - **Metric:** <what is measured> — baseline `<x>` → target `<y>` by `<when>` — **source:** <existing event / dashboard, or `AE-n`>

## 4. Non-Goals

*Out of scope, stated positively so an agent or developer cannot wrongly infer it. "Do not add X in this work."*

- <e.g. Do not change the existing payment flow.>
- <e.g. Do not support tablet layout in this phase.>

## 5. Users & Scenarios

*Who uses it, their job-to-be-done, and the primary journey in plain words.*

- **User / role:** <who> — **wants to** <job-to-be-done>
- **Primary journey:** <step-by-step in plain language, no UI/code detail>

## 6. Permissions & Roles
*[conditional: more than one role, or an entitlement/permission/plan gates the behavior]*

*Who is allowed to do what. State the gate as behavior, not as a check in code.*

- **<role / entitlement>** — can <what they may do> — cannot <what they may not>
- **Ungated / unentitled user sees:** <what happens instead — the exact fallback behavior>

## 7. Existing System & Constraints
*[conditional: brownfield, config-change, or anything touching an existing system]*

*Current behavior, what must NOT break, dependencies, integrations, and data already in place — described as behavior, not code. For brownfield this is the highest-leverage section; underspecified constraints cause the most rework.*

- **Current behavior:** <...>
- **Must not break:** <...>
- **Dependencies / integrations:** <...>
- **Data already in place:** <...>

## 8. Functional Requirements

*What the product or system does — the happy path. Group by capability. Each item has an ID, a behavior description, and a MoSCoW priority (Must / Should / Could / Won't). Unhappy paths go in §9.*

**<Capability group A>**
- **FR-1** — <name> — *Must* — <behavior: what the user or system does>
- **FR-2** — <name> — *Should* — <behavior>

**<Capability group B>**
- **FR-3** — <name> — *Could* — <behavior>

## 9. Edge Cases & Error Behavior

*The unhappy paths, stated as required behavior — not as a list of worries. Cover each that applies: failure of a dependency, timeout, empty state, first run / no data, permission denied, offline or connection lost, limit or quota reached, invalid input, concurrent or duplicate action, stale data. Each line says what the user or system observably does. These are requirements: give them IDs and acceptance criteria like any other.*

- **EC-1** — <situation> — <required observable behavior>
- **EC-2** — <situation> — <required observable behavior>

## 10. Non-Functional Requirements
*[conditional: include only the categories that apply, each with a concrete target]*

*Quality attributes. Each needs a measurable target — never "fast" or "secure" alone.*

- **NFR-1** — Performance — <e.g. screen loads in < 1s p95 on 4G>
- **NFR-2** — Security / Privacy — <e.g. tokens stored in OS keystore; no PII in logs>
- **NFR-3** — Reliability / Availability — <e.g. 99.9% monthly>
- **NFR-4** — Scalability — <e.g. sustain 5k req/s>
- **NFR-5** — Accessibility — <e.g. WCAG 2.2 AA; full screen-reader support>
- **NFR-6** — Observability — <e.g. error rate + latency dashboards, alert at threshold>
- **NFR-7** — Compliance / i18n — <e.g. GDPR delete-on-request; supports en, hi, es>

## 11. Analytics & Tracking Events
*[conditional: whenever a metric in §3 isn't already instrumented — i.e. most new work]*

*Events to instrument so the §3 metrics can actually be read. Metrics are the score; events are the raw signal. Each: name, trigger, the properties needed to slice it, and the metric or question it feeds. Instrument failure and drop-off, not only success. If the work is flagged or A/B tested, every event carries the variant so the arms can be compared. Each event is instrumented in the same phase as the behavior it measures — never deferred to a final polish phase.*

- **AE-1** — `<event_name>` — fires when <trigger> — props: `<key props>` — feeds: <metric in §3, or the question it answers>
- **AE-2** — `<event_name>` — fires when <failure / drop-off trigger> — props: `<key props, incl. reason>` — feeds: <metric or question>

**Where the numbers are read:** <existing dashboard, a new one to build, or a query someone runs> — **read by:** <who, and how often>

## 12. Acceptance Criteria

*Definition of done. Every **Must** requirement, every NFR, and every edge case gets at least one criterion. Given/When/Then for user-observable behavior, EARS ("when X, the system shall Y" / "while X, the system shall Y" / "if X, then the system shall Y") for system rules. Each criterion carries its own ID, `AC-<req-id>.<n>`, so a single criterion can be cited. Every criterion must be observable and testable.*

**FR-1 — <name>**
- **AC-FR-1.1** — Given <context>, When <action>, Then <observable result>.
- **AC-FR-1.2** — Given <context>, When <action>, Then <observable result>.

**FR-2 — <name>**
- **AC-FR-2.1** — Given <context>, When <action>, Then <observable result>.

**EC-1 — <situation>**
- **AC-EC-1.1** — If <unwanted condition>, then the system shall <observable behavior>.

**NFR-1 — Performance**
- **AC-NFR-1.1** — When <condition>, the system shall <measurable behavior>.

## 13. Rollout & Migration
*[conditional: brownfield, config-change, behind a flag, or existing users/data are affected]*

*How this reaches users and what happens to what is already there. Behavior and sequence only — no infrastructure detail.*

- **Flag / toggle:** <name in plain words> — **default:** on | off — **who gets it first:** <cohort>
- **Rollout sequence:** <e.g. internal → 5% → 50% → 100%, with the signal that gates each step>
- **Kill switch:** <what a user observes when the work is switched back off mid-session>
- **Existing users / data:** <what happens to them — migrated, backfilled, untouched, or re-onboarded>
- **Old path:** <kept, deprecated by when, or removed in a later phase>

## 14. Delivery Phases

*Sequential, bounded increments. Every requirement appears in exactly one phase. Each phase lists what it covers, the acceptance criteria that must pass, and its dependencies. Ordered "what" only — no code.*

- **Phase 1 — <name>:** covers FR-1, FR-2 · done when AC-FR-1.*, AC-FR-2.* pass · depends on: none
- **Phase 2 — <name>:** covers FR-3, EC-1, NFR-1 · done when AC-FR-3.*, AC-EC-1.*, AC-NFR-1.* pass · depends on: Phase 1

## 15. Risks, Assumptions, Dependencies, Open Questions

*RAID-lite. Make assumptions explicit. Open questions are a short, earned list — only what is genuinely unresolved after pushing for a decision, phrased as a behavior/outcome call, each with the owner who should resolve it (often Eng, Data, Legal, or another team — not the PM by default).*

- **Risk:** <what could go wrong> → **Mitigation:** <...>
- **Assumption:** <what we're taking as true>
- **Dependency:** <external team / service / decision>
- **Open question:** <unresolved behavior decision> — **Owner:** <who> — **Needed by:** <when>

## 16. References
*[conditional: when links exist]*

*Designs, tickets, related specs, research. No code references. Use the live design-tool link (Figma/Sketch/etc.) as the canonical source for the new visuals — keep frame/node deep-links verbatim. Static screenshots go in §17, not here.*

- Design (Figma/Sketch): <link to the new design — exact frame if available>
- Ticket: <link>
- Related spec: <link>

## 17. Visual References
*[conditional: when the user provides screenshots or images]*

*Screenshots and images that ground the feature — current UI state, mockups, annotated wireframes, error states, competitor/inspiration shots. Copy each into a `spec-assets/` folder beside this file and embed by relative path with a caption. Visual evidence only — requirements still stand on their own in the text above.*

- ![<short alt>](spec-assets/<file>.png) — <what this shows, e.g. current cart screen before the change>
- ![<short alt>](spec-assets/<file>.png) — <what this shows, e.g. proposed layout from design>

## 18. Revision History
*[conditional: once the spec is changed after it was first shared or approved]*

*One line per revision. Requirement IDs are never reused or renumbered — superseded requirements are marked, not deleted.*

| Date | Author | Change |
|---|---|---|
| <YYYY-MM-DD> | <name> | <what changed, e.g. added FR-7..FR-9 for guest checkout; FR-4 superseded> |
