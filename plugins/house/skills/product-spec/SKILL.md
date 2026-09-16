---
name: product-spec
description: >-
  Interview-driven product spec builder — a PRD by any other name. Use WHENEVER the user wants to
  write, draft, create, update, scope, or structure a product spec, PRD, requirements doc, feature
  spec, or "one-pager" — even if they only describe an idea and say "help me spec this out", "I want
  to build X", or "turn this into a PRD". It does NOT dump a blank template: it interviews first
  (problem, existing system, users, scope, edge cases, rollout, acceptance), then writes a complete,
  agent-ready spec markdown file at the what/why level — no code, file paths, or architecture. Any
  software work, greenfield or brownfield, any stack, internal or consumer. Trigger on product spec,
  PRD, requirements doc, feature spec, "scope this feature", "write a spec", "product brief". SKIP for
  implementation/architecture plans (the how), pure code, and non-product documents.
---

# Product Spec Builder

You help a product person turn a rough idea into a complete, unambiguous product spec — a PRD with
SRS-level requirements and acceptance criteria. Your value is the
**interview**: a vague idea becomes a precise spec because you asked the right questions and refused
to guess on things that matter. A spec nobody can act on — because scope is fuzzy, acceptance is
prose, or non-goals are missing — is worse than no spec. The output is a single markdown file that a
new developer or an AI agent can read, plan from, and execute phase by phase.

## The two hard rules

1. **Interview before you write.** Never emit a spec from a one-line prompt. Ask questions, fill gaps,
   confirm understanding, *then* write. The user came to you because the idea isn't fully formed —
   surfacing what they haven't thought about is the job.
2. **Stay at what/why.** A spec describes behavior and outcomes, never code, file paths, libraries,
   schemas, or architecture. Those belong to the downstream implementation plan. If the user gives
   you implementation detail ("use Postgres", "build a React modal"), capture the *intent* behind it
   (durable storage, an in-context confirmation step) and leave the *how* out.

## Workflow

```
Classify → Interview (adaptive, batched) → Draft → Self-check → Confirm → Write file
```

### Step 1 — Classify

Before asking anything, infer what you can from the user's message and read what's available
(attached docs, links, the repo). Then settle four dimensions — ask only the ones you can't infer:

- **Type:** `greenfield` (new) · `brownfield` (change to existing) · `config-change` (flag, rollout,
  or infra toggle). Exactly one applies. Spanning several stacks is *not* a type — that's Surfaces.
- **Surfaces:** which are touched — mobile, backend, frontend, infra, web, desktop, CLI, data/ML.
  List all that apply; more than one is normal and doesn't change the Type.
- **Audience:** internal · consumer.
- **Size:** tiny change vs. full feature/product. Tiny → the **minimum-viable subset** (see cheatsheet),
  don't force every section.

Use `AskUserQuestion` to confirm these in one batch if unclear. This framing controls everything
downstream, so get it right before interviewing on content.

**If this is an update to an existing spec**, skip to *Updating an existing spec* near the end — the
rules differ.

**For brownfield or config-change, ground yourself in the real system before interviewing.** Read the
repo (search the code, use the `Explore` agent for a broad sweep) to learn what the current behavior
actually is. PMs routinely don't know the current edge-case behavior, and "must not break" is far
more accurate when you confirmed it than when you asked. What you learn shapes your questions and the
Existing System section — but it never leaks into the spec as code, paths, or class names.

### Step 2 — Interview (the core)

Drive the interview with `AskUserQuestion`. Batch related questions (up to 4 per call) instead of
dribbling one at a time — product people are busy and each round costs them attention. Always offer a
sensible recommended option first where one exists, and let them free-type via "Other".

Cover the section areas below **in order**, skipping conditional ones that don't apply to the type.
For each area, the bullet is *what you must walk away knowing* — not a script to read verbatim. Ask
follow-ups when an answer is vague, conflicting, or unmeasurable. Stop interviewing an area only when
you could write that section without guessing.

**Always:**
- **Problem & why now** — the real pain, who feels it, the trigger/evidence that makes it worth doing
  *now*. If the user leads with a solution, dig back to the problem it solves.
- **Goals & success metrics** — the measurable outcome(s). Push every goal to a metric with a target:
  "increase retention" → "D7 retention X% → Y% by Q3". If they can't measure it, ask how they'd know
  it worked. No-baseline is fine; "no metric" is not. Then ask the question that gets skipped: **where
  will this number actually come from?** An existing event or dashboard, or a new event this spec has to
  add. A metric with no source is a wish — see the analytics area below.
- **Users & scenarios** — who uses it, their job-to-be-done, the primary journey in plain words.
- **Scope boundary / non-goals** — what this explicitly does *not* do. Phrase positively ("Do not
  touch billing"), never by omission. This is where unspoken assumptions surface — probe for them.
- **Functional requirements** — what the product does on the happy path, grouped by capability. For
  each, get behavior and a MoSCoW priority (Must/Should/Could/Won't). One requirement per line.
- **Edge cases & error behavior** — the unhappy paths, and the area users most often skip. Walk the
  Must requirements and ask what happens when: a dependency fails or times out · there's no data yet
  (first run, empty list) · the user lacks permission or entitlement · the device is offline or the
  connection drops mid-action · a limit or quota is hit · input is invalid · the action is repeated,
  duplicated, or raced · the data on screen is stale. Ask only the ones that plausibly apply, and get
  a required *observable behavior* for each — "we'll show an error" is not yet a requirement. These
  become `EC-n` and get acceptance criteria like anything else.
- **Acceptance criteria** — how each requirement is verified. Convert vague "it should work" into
  observable Given/When/Then or EARS rules. (You draft these; confirm the tricky ones.)
- **Visual context — offer every interview.** Ask the user to share any screenshots or images that
  ground the feature: the current UI state (for brownfield), design mockups, an annotated wireframe,
  a competitor/inspiration shot, or the confusing screen/error state that prompted the work. These are
  optional — the user can decline — but they earn their place twice. First, read each image you're
  given (you're multimodal) and let what you actually see drive sharper questions: a screenshot of the
  current screen surfaces constraints and edge cases the user forgets to mention. Second, the images
  travel with the spec, so the downstream developer or agent sees exactly what you saw instead of
  reconstructing it from prose. For each image, note **whether it came as a file path or as a paste** —
  that decides how it lands in the file (see Step 6).
- **Design link — ask whenever the work changes any UI.** Ask if there's a Figma (or Sketch, Pencil,
  Zeplin, etc.) link for the new design. A live design link is the canonical source of truth for the
  proposed visuals — it stays current as designers iterate, where a pasted screenshot goes stale — so
  the downstream developer pulls exact spacing, states, and specs from it. This is a *link*, not an
  embedded image: record it in References as a `Design` entry, distinct from the static screenshots in
  Visual References. If a frame/node deep-link is given, keep it verbatim so it opens the exact screen.

**Conditional — ask only when triggered:**
- **Permissions & roles** *(more than one role, or an entitlement/plan/permission gates the behavior)* —
  who may do what, and — the part that gets forgotten — exactly what an ungated user sees instead.
- **Existing system & constraints** *(brownfield / config-change / anything touching an existing
  system)* — current behavior, what must NOT break, dependencies, integrations, data already in place.
  This is the highest-leverage area for brownfield work; underspecified constraints cause the most
  rework. Probe hard here, and check what you learned from the repo in Step 1 against their answers.
- **Non-functional requirements** *(when quality targets matter)* — performance, security/privacy,
  reliability, scalability, accessibility, observability, compliance, i18n. Each needs a concrete
  target, never "fast" or "secure". Ask only about categories that plausibly apply.
- **Analytics & tracking events** *(whenever any success metric isn't already instrumented — which is
  most new work)* — which events to add so the metrics can actually be read. Metrics are the score;
  events are the raw signal. Work backwards from each metric in Goals: name the event, its trigger, the
  properties needed to slice it (cohort, entry point, variant), and the question it answers. Then close
  the loop both ways — **every metric traces to a source, and every event you add earns its place by
  feeding a metric or a named question.** Ask where the number gets read (existing dashboard, a new
  one, a query someone runs) and who reads it; an event nobody looks at is dead weight. Two more the
  PM usually wants once you raise it: instrument the **failure and drop-off** paths too, not just
  success — the edge cases in §Edge Cases are where the interesting numbers live — and, if the work is
  flagged or A/B tested, make sure the events carry the variant so the two arms can be compared.
- **Rollout & migration** *(brownfield / config-change / behind a flag / existing users or data
  affected)* — is it flagged and what's the default, who gets it first, what signal gates each step,
  what a user observes if it's switched back off mid-session, and what happens to users and data
  already in place (migrated, backfilled, untouched, re-onboarded). Say whether the old path stays,
  is deprecated by a date, or is removed later. Behavior and sequence only — no infrastructure.
- **Delivery phases** *(non-trivial work)* — how to slice into sequential, independently-verifiable
  increments. Often you propose a slicing and the user reacts.
- **Risks / assumptions / dependencies / open questions** — surface these as you go; confirm owners
  and "needed by" for open questions at the end. See the Open-Questions discipline below — a PM
  authoring their own spec is expected to *decide*, so this list should be short and earned.
- **References** *(when links exist)* — designs, tickets, related specs, research.

Interview discipline:
- **One open question per turn is a failure mode.** Group them.
- **The PM is the author — push for decisions, don't collect questions.** The person you're
  interviewing usually *owns* the product call. When something is undecided, your first move is to
  help them decide it now (offer the trade-off, give a recommendation), not to park it. A spec that
  ends with fifteen Open Questions the author could have answered in the room is a failure of the
  interview, not a thorough spec.
- **Open Questions are a narrow, earned list — not a dumping ground.** Reserve them for things that
  are *genuinely* unresolved after you pushed: a decision blocked on data the PM doesn't have, or one
  that belongs to another team. Each one names the **owner who should resolve it** — and that owner is
  often *not* the PM (Eng, Data, Payments, Platform, Legal). Never default every open question's owner
  to the PM; assigning a product person to resolve an engineering call is a tell that the question is
  miscategorized.
- **Don't smuggle the "how" in as an open question.** "Fail-open or fail-closed?", "which datastore?",
  "capture payment at placement or settlement?" feel like open questions but several are
  *implementation* choices that don't belong in a what/why spec at all — they live in the downstream
  plan. Before listing a tech-flavored open question, do one of: (a) **reframe it as the
  user-observable behavior decision it implies** and keep that ("Decide what a caller experiences when
  the limiter can't answer — allowed or rejected" is a behavior/product call; "fail-open vs
  fail-closed" is its implementation), assigning the right owner; or (b) if it is purely mechanism with
  no behavioral consequence, **drop it** — it's the plan's job, not the spec's. When in doubt during a
  live interview, ask the PM which it is.
- **Don't invent facts.** If something is genuinely unknown and unresolvable in the room, record it as
  an Open Question per the discipline above — never paper over it with a plausible guess.
- **Reflect back when stakes are high.** For scope, metrics, and constraints, restate your
  understanding in one line and let the user correct it before you commit it to the doc.
- **Know when to stop.** Once every *always* area and every triggered *conditional* area is answered
  well enough to write without guessing, move on. Don't over-interrogate a tiny config change.

### Step 3 — Draft

**Read `references/template.md` before you draft, every time** — it defines the exact section order,
headings, and front-matter, and the headings are fixed. Never draft from memory.

Fill it using everything gathered, following the quality rules below. Delete conditional sections that
don't apply — **omit, never write "N/A"** — and leave the remaining section numbers as they are; a gap
in the numbering is correct, renumbering breaks every cross-reference. Delete the how-to blockquote and every italic hint line as
you fill each section. Assign stable IDs (`FR-n`, `EC-n`, `NFR-n`, `AE-n`) and give every acceptance
criterion its own `AC-<req-id>.<n>` ID so phases and QA can cite a single criterion.

### Step 4 — Self-check

Most bad specs fail here, not in the interview. Write the draft to a file — the path you'll deliver at
(Step 6 covers where that is) or a scratch copy — then run the bundled validator. It checks the
mechanical rules deterministically, which beats re-reading an 18-section document hunting for one
missing acceptance criterion:

```
python3 scripts/validate_spec.py <path-to-spec.md>          # add --minimal for a tiny change
```

It exits non-zero and names what failed: front-matter fields and enums, filename vs `id`, section
titles and order, reused or missing IDs, MoSCoW on every FR, acceptance coverage for every Must FR /
EC / NFR, acceptance IDs pointing at requirements that exist, phase partitioning and done-when
references, metrics missing a target or source, leftover `N/A` / `<placeholder>` / template hints,
unbalanced fences, and absolute image paths. Warnings are advisory; errors mean fix and re-run.

Then read for the things a parser can't judge. The full bar, with the automated half marked:

- [ ] *(validator)* Every **Must** FR, every `EC-n`, and every `NFR-n` has at least one acceptance criterion.
- [ ] *(validator)* Every requirement appears in **exactly one** delivery phase, and each phase's
      done-when cites `AC-` IDs that exist.
- [ ] *(validator)* Every metric has a target and a named source — an existing event or dashboard, or
      an `AE-n` in this spec.
- [ ] *(validator)* IDs unique and never reused · MoSCoW on every FR · section titles and order intact ·
      filename matches `id` · no `N/A`, `<placeholder>`, or leftover hints · fences closed · images relative.
- [ ] Every criterion is observable or numeric — no "should be fast", no "works correctly".
- [ ] Non-goals are stated positively ("Do not …"), not by omission.
- [ ] Every open question is a behavior/outcome decision, not pure mechanism, with an owner who is the
      right person to resolve it and a needed-by.
- [ ] Zero code, paths, class names, libraries, schemas, or architecture. The validator flags the
      obvious shapes; prose can still smuggle in the *how*.
- [ ] Every `AE-n` feeds a metric or a named question, and ships in the same phase as the behavior it
      measures — never deferred to a "polish" phase.

### Step 5 — Confirm

Show the draft (or a tight summary of the contentious parts: scope, FRs, edge cases, metrics, phases).
Invite correction with `AskUserQuestion` — offer "looks right, write it" against the most likely
revision, and let them free-type anything else. Iterate until the user is satisfied. This is cheaper
than shipping a wrong spec.

### Step 6 — Write the file

Write the final spec as `SPEC-<id>.md` (the kebab `id` from the front-matter, e.g.
`SPEC-offline-reading-mode.md`). Put it where the repo already keeps specs if there's an obvious
convention (`docs/`, `prd/`), otherwise the user's working directory — or wherever they ask. Confirm
the path. The deliverable is the file, not chat text.

**Images.** If the user shared screenshots, make the spec self-contained:

- **Given as a file path** — create `spec-assets/` beside the spec and copy each image in with a clear
  kebab-case name (`cp <source> spec-assets/current-cart.png`, not `IMG_4821.png`). Embed each in
  Visual References by *relative* path (`spec-assets/current-cart.png`) with a one-line caption of what
  it shows, so the spec survives being moved or shared. Never hard-wire the absolute path you were given.
- **Pasted into the conversation** — you cannot write the image file, so don't fabricate a path or emit
  a link that will 404. Either ask the user to save it and give you a path (preferred — then treat it as
  above), or, if they'd rather not, write the visual evidence as prose: describe what the image shows
  in the relevant section and note in Visual References that the screenshot was reviewed but not
  attached. A missing image is recoverable; a broken image link that looks filled-in is not.
- If no images were shared, omit the Visual References section entirely (don't write "N/A").

## Updating an existing spec

When the ask is "add X to the spec" or "update the spec", read the existing file first and treat its IDs
as immutable:

- **Never renumber or reuse IDs.** New requirements continue from the highest existing number, even if
  there are gaps.
- **Mark, don't delete.** A requirement that no longer applies becomes `~~FR-4~~ — superseded by FR-9`
  (or *Won't* with a reason). Deleting it silently breaks every plan, ticket, and test that cites it.
- **Keep acceptance criteria in step.** A changed requirement needs its `AC-` criteria updated in the
  same pass, and any phase that covered it re-checked.
- **Bump `date`, set `status` honestly**, and add a line to Revision History saying what changed.
- Run the Step 4 self-check on the whole file, not just your edit.

## Quality rules (the bar the spec must clear)

1. **What & why only.** Behavior and outcomes. Zero code, file paths, libraries, schemas, architecture.
2. **Non-goals stated positively.** "Do not add X." An agent fills unstated gaps with wrong guesses;
   omission is not a boundary.
3. **Omit, don't "N/A".** Delete conditional sections that don't apply rather than leaving placeholders.
4. **One requirement per line.** Never pack several into a paragraph — they get blended or dropped.
5. **Unhappy paths are requirements, not caveats.** Failure, empty, offline, denied, limit-reached, and
   duplicate-action behavior belongs in Edge Cases with an ID and acceptance criteria. "We'll handle
   errors" is not a requirement.
6. **Acceptance criteria are testable, ID'd, and complete.** An observable result or a numeric target,
   never "should be fast". Behavior → `Given <context>, When <action>, Then <observable result>`.
   System rule → EARS: `When <trigger>, the system shall <response>` / `While <state>, the system shall
   <response>` / `If <unwanted condition>, then the system shall <response>`. Each criterion carries
   its own `AC-<req-id>.<n>` ID, and **every Must FR, every EC, and every NFR has at least one**.
7. **Stable IDs and fixed headings.** `FR-n`/`EC-n`/`NFR-n`/`AE-n` so humans and agents can trace and
   target requirements. IDs are never renumbered or reused, including across revisions.
8. **MoSCoW on every functional requirement.** Must (ship is meaningless without it) · Should
   (important, can survive short delay) · Could (nice to have) · Won't (explicitly not now — doubles
   as a non-goal).
9. **Metrics have targets and a source.** Each goal → a metric with baseline (if known) → target by
   when → where the number comes from. A target nobody can read isn't a metric.
10. **Analytics closes the loop on the metrics.** Every metric traces to an existing event/dashboard or
    to an `AE-n` in this spec; every `AE-n` feeds a metric or a named question, carries the properties
    needed to slice it (and the variant, if the work is flagged or A/B tested), and covers the failure
    and drop-off paths, not just success. Instrument in the same phase as the behavior being measured —
    analytics parked in a final "polish" phase means the launch it was meant to measure ships blind.
11. **Phases partition the requirements.** Every requirement lands in exactly one phase, and a phase is
    "done" only when the `AC-` IDs of everything it covers pass.
12. **Open Questions are product decisions with the right owner, kept short.** A PM-authored spec should
    resolve product calls, not park them — list only what's genuinely unresolved after you pushed for a
    decision. Phrase each as a behavior/outcome decision (never a pure implementation choice), and name
    the owner who should resolve it (Eng/Data/Payments/Platform when it isn't the PM). Implementation
    mechanism with no user-observable consequence belongs in the downstream plan, not here.
13. **Emit clean markdown.** The file is the deliverable. YAML front-matter first, exactly as the
    template shows. Don't wrap body sections in stray code fences and don't leave a dangling ` ``` `
    at the end — every fence you open must close, and the document ends on content.
14. **Screenshots travel with the spec, by relative path.** Copy shared images into `spec-assets/` beside
    the file and embed them with a relative path and a caption — never an absolute path that breaks on
    move, and never a link to a file you couldn't actually write. Images are visual evidence that
    sharpens understanding, not a substitute for written requirements: every FR/EC/NFR/AC still stands
    on its own in text so the spec reads correctly even where images don't render.

## Resources

Read `references/template.md` and `references/cheatsheet.md` before drafting — always, not only for
large work. The headings and IDs are fixed, so a from-memory draft drifts.

- `scripts/validate_spec.py` — run it on the finished file (Step 4). Checks the mechanical rules and
  exits non-zero with a named failure for each. `--minimal` relaxes the section warnings for a tiny
  change. It enforces the template's structure, so if you change the template, update its
  `CANONICAL_SECTIONS` map too or every spec will fail on section titles.
- `references/template.md` — the full blank spec template with inline hints and conditional markers.
  Defines the exact section order, headings, and front-matter.
- `references/cheatsheet.md` — one-page reference: section inclusion table, the minimum-viable subset
  for tiny changes, GWT/EARS snippets, MoSCoW legend, ID conventions, the self-check list. Consult it
  to decide which sections apply and how to phrase acceptance criteria.
- `references/example-mobile-brownfield.md` — a filled reference spec (a feature added to an existing
  mobile app) showing the target quality and tone for a full-size, brownfield spec.
- `references/example-config-change.md` — a filled minimum-viable spec for a tiny config change, showing
  how little is appropriate when the work is small.
