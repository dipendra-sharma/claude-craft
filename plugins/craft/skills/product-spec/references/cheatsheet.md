# Product Spec Cheatsheet — One Page

## Golden rules

1. **What & why only** — behavior and outcomes. No code, file paths, libraries, or architecture.
2. **Non-goals are positive** — write "Do not add X", never rely on omission. An agent fills gaps with wrong guesses.
3. **Omit, don't "N/A"** — delete conditional sections that don't apply. No leftover `<placeholders>`.
4. **One requirement per line** — never pack several into a paragraph.
5. **Unhappy paths are requirements** — failure, empty, offline, denied, limit-reached, duplicate action. Give them `EC-n` IDs, not a shrug.
6. **Acceptance criteria are testable, ID'd, complete** — observable or numeric, never "should be fast". Every Must FR, every EC, every NFR has ≥1.
7. **MoSCoW on every FR** · **metrics have a target *and* a source** · **every AE feeds a metric or a named question**.
8. **Phases partition the requirements** — each requirement in exactly one phase; done-when cites `AC-` IDs.
9. **Open questions are behavior decisions with the right owner** — short, earned list; mechanism belongs in the plan.
10. **Fixed headings + stable IDs** — never renumbered or reused, including across revisions. An omitted section leaves a gap in the section numbering; the rest keep their numbers so `§13` always means the same thing.

## Sections at a glance

| # | Section | Include | In minimum-viable? |
|---|---|---|---|
| — | Front-matter (YAML: title, id, status, owner, date, type, surfaces, audience) | always | yes |
| 1 | TL;DR | always | yes |
| 2 | Problem & Why Now | always | yes |
| 3 | Goals & Success Metrics (target + source) | always | yes |
| 4 | Non-Goals | always | yes |
| 5 | Users & Scenarios | always | — |
| 6 | Permissions & Roles | multiple roles, or an entitlement gates behavior | — |
| 7 | Existing System & Constraints | brownfield / config-change / touches existing system | if brownfield |
| 8 | Functional Requirements (`FR-n`, MoSCoW) | always | yes |
| 9 | Edge Cases & Error Behavior (`EC-n`) | always | yes |
| 10 | Non-Functional Requirements (`NFR-n`, with targets) | as applicable | — |
| 11 | Analytics & Tracking Events (`AE-n`) | whenever a §3 metric isn't already instrumented | if a new metric |
| 12 | Acceptance Criteria (`AC-<req-id>.<n>`, GWT + EARS) | always | yes |
| 13 | Rollout & Migration | brownfield / config-change / flagged / existing data affected | if flagged |
| 14 | Delivery Phases | non-trivial work | — |
| 15 | Risks / Assumptions / Dependencies / Open Questions | always | — |
| 16 | References (incl. Figma/design link as canonical source for new visuals) | when links exist | — |
| 17 | Visual References (screenshots → `spec-assets/`, relative path) | when images provided | — |
| 18 | Revision History | once changed after first shared/approved | — |

## Minimum-viable spec (tiny change)

Front-matter · **1** TL;DR · **2** Problem · **3** Goals & Metrics · **4** Non-Goals · **8** Functional Requirements · **9** Edge Cases · **12** Acceptance Criteria — plus **7** if brownfield, **11** if it needs a new metric, **13** if it ships behind a flag.

A tiny change still needs its unhappy path and its acceptance criteria. Those are the two that make it actionable.

## Acceptance-criteria formats

- **Behavior → Given/When/Then:**
  `**AC-FR-1.1** — Given <context>, When <action>, Then <observable result>.`
- **System rule → EARS:**
  `**AC-NFR-1.1** — When <trigger>, the system shall <response>.`
  `**AC-NFR-1.2** — While <state>, the system shall <response>.`
  `**AC-EC-1.1** — If <unwanted condition>, then the system shall <response>.`

## MoSCoW priority

- **Must** — ship is meaningless without it.
- **Should** — important, but launch can survive a short delay.
- **Could** — nice to have if time allows.
- **Won't** — explicitly not this time (record it; it doubles as a non-goal).

## ID conventions

`FR-n` functional · `EC-n` edge case / error behavior · `NFR-n` non-functional · `AE-n` analytics event · `AC-<req-id>.<n>` acceptance criterion (e.g. `AC-FR-3.2`, `AC-EC-1.1`).

Phases cite `AC-` IDs. IDs are never renumbered or reused — a dropped requirement is marked superseded, not deleted.

## Visual References (§17) — worked format

Layout on disk, and what the section looks like filled in:

```
docs/
  SPEC-offline-reading-mode.md
  spec-assets/
    current-network-error.png
    proposed-offline-library.png
```

```markdown
## 17. Visual References

- ![Current network error screen](spec-assets/current-network-error.png) — what a reader sees today when the connection drops mid-article; the state EC-1 replaces.
- ![Proposed Offline library](spec-assets/proposed-offline-library.png) — design mock for FR-4, showing newest-save-first ordering.
```

Rules: kebab-case filenames that say what the image is · relative paths only, never the absolute path
the user gave you · a caption per image saying what it shows and which requirement it grounds · a live
Figma link belongs in §16, not here. If the image was pasted into chat rather than saved to disk, you
cannot write the file — ask for a path, or describe it in prose and say the screenshot wasn't attached.

## Metric → source → event

Every goal must survive this chain, or it can't be verified after launch:

`Goal` → `Metric (baseline → target, by when)` → `Source: existing dashboard/event, or AE-n` → `AE-n instrumented in the same phase as the behavior`

If the chain breaks at "source", the spec is asking for a launch nobody can score.

## Pre-write self-check

Run `python3 scripts/validate_spec.py <spec.md>` (add `--minimal` for a tiny change) — it covers the
mechanical half below. Read for the rest.

Every Must FR / EC / NFR has ≥1 AC · criteria observable or numeric · each requirement in exactly one phase, done-when cites its `AC-` IDs · every metric has target + by-when + source · every AE feeds a metric or question and ships with its behavior · non-goals positive · open questions are behavior calls with the right owner and a needed-by · zero code/paths/libraries · no "N/A", `<placeholder>`, hint lines, or how-to blockquote · all fences closed · filename matches front-matter `id` · images by relative path.
