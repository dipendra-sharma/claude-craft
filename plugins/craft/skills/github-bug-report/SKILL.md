---
name: github-bug-report
description: >-
  Turn a bug report into a clear, complete, developer-ready GitHub issue. Use
  this whenever someone wants to file, create, write, draft, or open a bug — for
  a backend service, frontend/web app, mobile app, or a multiplatform /
  multi-flavour project — even if they just paste a stack trace, a screenshot
  description, a Slack complaint, or say "this is broken, log a bug." It
  interviews for any missing reproduction steps, version, and environment
  details, auto-detects the platform, produces a well-structured markdown issue
  (title + body + labels), and offers to file it directly with the `gh` CLI.
  Trigger on: "file a bug", "create a github issue", "log this bug", "report
  this", "write up this bug", "open an issue for", QA/Product handoffs, or a raw
  error/crash pasted with intent to track it. Works for QA, Product, developers,
  or anyone who needs a bug tracked properly.
---

# GitHub Bug Report

A bug issue succeeds when a developer can reproduce and fix it **without a single
follow-up question.** That is the whole goal. Everything below exists to close
the gap between "something is broken" and a report that stands on its own.

The person filing the bug is often *not* the person who will fix it — a QA
tester, a PM, a support agent, sometimes a user. They may not know what a
developer needs (exact version, environment, logs). Your job is to bridge that
gap: pull what you can from context, ask for the rest, and shape it into
something clean.

## Workflow

1. **Gather what's already there.** Read the user's message, any pasted logs /
   stack traces / screenshots, and the surrounding conversation. If you're in a
   repo, glance at it for clues (framework, app name, current version).
2. **Detect the platform** (see below). Confirm only if genuinely ambiguous.
3. **Interview to fill gaps.** Identify which required fields are missing and ask
   for them — concisely, batched into one message, not one question at a time.
4. **Write the issue** using the template, pulling in the platform-specific
   environment block.
5. **Show it to the user**, then **offer to file it** with `gh`.

## Detecting the platform

Infer from context before asking. Signals:

- **Backend** — API, endpoint, server, service name, HTTP status codes, database,
  cron/worker, `500`, stack trace from a server framework (Express, Spring, FastAPI, Rails).
- **Frontend** — web page, browser, button/UI, console error, CSS/layout, a URL/route,
  React/Vue/Angular, "on Chrome", "on desktop".
- **Mobile** — iOS/Android, app crash, device model, App Store/Play Store, Crashlytics,
  a build flavour, "on my phone".
- **Multiplatform / multi-flavour** — one codebase across targets (Flutter, React
  Native, KMP), or the bug spans web + mobile, or the user mentions build
  variants / flavours (dev/staging/prod, free/paid).

When it's genuinely unclear (e.g. a full-stack repo and the bug could be either
side), ask which surface(s) are affected — don't guess. A wrong platform means
the wrong environment fields, which defeats the point.

Read the matching reference for the exact environment/version fields to collect:

- `references/backend.md`
- `references/frontend.md`
- `references/mobile.md`
- `references/multiplatform.md` — for multiplatform **and** multi-flavour projects

## Interviewing for missing details

Required fields — a good bug report needs all of these. If any are missing from
context, **ask before writing**:

- **What happened** — the symptom, concretely.
- **Steps to reproduce** — exact, numbered, from a known starting state.
- **Expected vs. actual** — the single most important contrast.
- **Environment & version** — platform-specific; see the reference file.
- **Frequency** — always / intermittent / happened once.
- **Impact** — who/what is blocked, how bad.

Ask for missing items in **one batched message**, grouped and easy to answer.
Keep it light for the reporter — offer sensible defaults ("I'll assume
production unless you say otherwise"). Don't interrogate: if the user clearly
can't provide something (e.g. "I don't have the logs"), note it as *Not
available* and move on rather than blocking.

Evidence is worth more than prose — always ask for a screenshot/recording (UI
bugs), stack trace or crash ID (crashes), or request/response (API bugs) if not
already provided.

## Issue template

Use this structure. Keep the language plain — anyone should understand it at a
glance. Omit a section only if it truly doesn't apply (and say why); prefer
*Not available* over silent deletion so the reader knows it was considered.

**Title:** `[<Platform/Area>] <short symptom> when <key condition>`
Specific and searchable. E.g. `[Checkout] App crashes when applying an expired coupon`.
Avoid vague titles like "App broken" or "Bug in login".

**Body:**

```markdown
## Description
<One or two sentences: what's broken and why it matters.>

## Steps to Reproduce
1.
2.
3.

## Expected Behavior
<What should happen.>

## Actual Behavior
<What actually happens. Include exact error text.>

## Environment
<Platform-specific block — see the reference file. Include version/build.>

## Evidence
<Screenshots, recording, logs, stack trace, crash ID, request/response.
Put long logs in a collapsible block:>
<details><summary>Logs / stack trace</summary>

​```
paste here
​```
</details>

## Frequency & Impact
- **Reproducibility:** always / intermittent / once
- **Severity:** blocker / high / medium / low
- **Affected:** <who or what — e.g. "all users on checkout", "cosmetic only">

## Notes / Suspected Cause (optional)
<Any regression info ("worked in v3.3"), suspected root cause, or a
`file.ext:line` pointer. Clearly mark guesses as guesses.>
```

**Principles that separate a great issue from a filler one:**

- **One bug per issue.** If the report bundles several problems, split them —
  they get triaged, fixed, and closed independently.
- **Minimal reproduction.** Strip steps to the smallest set that still triggers
  the bug. "Sometimes it fails" → find the actual trigger.
- **Regression signal is gold.** "Worked in v3.3, broke in v3.4" instantly
  narrows the search — always capture it if known.
- **Show, don't tell.** A recording or stack trace beats a paragraph.

## Labels & severity

Suggest labels so the issue triages itself: always `bug`, plus a severity
(`severity:blocker|high|medium|low`) and an area label (`area:backend`,
`area:mobile`, etc.) matching the platform. Map severity from impact:
blocker = data loss / nothing works / all users; high = core flow broken;
medium = workaround exists; low = cosmetic/edge case.

## Filing the issue

After showing the drafted issue, offer to file it. Don't file without
confirmation — creating an issue is outward-facing and hard to undo cleanly.

Detect the repo and file with the `gh` CLI:

```bash
gh issue create \
  --title "<title>" \
  --body-file <path-to-body.md> \
  --label "bug" --label "severity:high"
```

Write the body to a temp file and pass `--body-file` (avoids shell-escaping
issues with backticks, code blocks, and newlines). Notes:

- Confirm the target repo first. In a git repo, `gh` uses the current one; if the
  bug is for a *different* repo, pass `--repo owner/name`.
- If a label doesn't exist, `gh` errors — retry without the missing label (or
  offer to create it) rather than failing the whole command.
- If `gh` isn't authenticated (`gh auth status` fails), don't guess — tell the
  user to run `gh auth login` (suggest they type `! gh auth login`), and in the
  meantime hand them the finished markdown to paste manually.
- After filing, report the issue URL that `gh` prints.

## Reusable issue template file (optional)

If the user wants their whole team to file consistent bugs, offer to generate a
GitHub issue form at `.github/ISSUE_TEMPLATE/bug_report.yml` — GitHub's Forms
format makes fields like Steps and Environment required so reporters can't skip
them. See `references/issue_form_template.md` for a ready-to-commit example.
