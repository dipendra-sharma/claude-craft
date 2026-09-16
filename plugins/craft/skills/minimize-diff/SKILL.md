---
name: minimize-diff
description: Shrink a code diff to the smallest change that still delivers identical behavior, feature set, UI and UX — then split what remains into a stack of small, independently reviewable commits or PRs. Takes any source→target pair - a branch vs its base, a commit or commit range, staged/unstaged work, or two raw files. Invoke manually when a branch or PR is too big to review, when a small feature somehow touched 40 files, or before opening a PR. Optional mode argument - `default`, `no-comments`, `no-tests`, `no-logs`, `full` - controls how aggressive the cuts are. Size and reviewability only - it does not hunt for bugs (use `/code-review`) and it does not improve the code it keeps (use `/simplify`).
argument-hint: '[default|no-comments|no-tests|no-logs|full] [source] [target] — e.g. minimize-diff feature/x | minimize-diff full main...HEAD | minimize-diff no-comments no-logs | minimize-diff no-tests abc123'
user-invocable: true
---

# Minimize diff

A big diff is usually a small change wearing a costume. The feature itself is
50 lines; the other 900 are a formatter that ran on save, a rename someone did
while they were in there, an abstraction built for a second caller that never
arrived, and a file that got moved so git gave up on rename detection.

Your job is to take the costume off without touching the change underneath.
Reviewers approve what they can hold in their head, so every line you remove
buys real review attention for the lines that matter.

**The one rule that outranks everything: the product must behave identically.**
Same features, same UI, same UX, same edge cases, same error handling, same
performance shape. A smaller diff that changed behavior is not a win, it is an
undetected bug plus a smaller diff. When you cannot tell whether a cut is
behavior-neutral, keep the code and say so in the report.

## What this is not

Three skills operate on a diff and they are not interchangeable. Reaching for
the wrong one wastes a pass and, worse, hands back changes the user did not ask
for.

`coding-best-practices` is the quality bar for whatever survives the cut — it
owns naming, structure, error handling and scope discipline, while this skill
only decides how much of the change belongs in this PR. Load it when you edit
the code you are keeping; don't re-argue its rules here.

- **`/code-review`** hunts for correctness bugs. This skill assumes the code is
  right and only argues about how much of it needs to be in this PR. If you spot
  a real bug while cutting, report it — do not fix it here, that is a drive-by.
- **`/simplify`** improves the code you are keeping: reuse, simplification,
  efficiency, altitude. It makes the code better and often makes the diff
  *bigger*. This skill makes the diff smaller and the shipped behavior
  identical.
- **This skill** deletes lines that should never have been in the diff and
  splits what survives. It rewrites the essential change only when the rewrite
  is behavior-identical *and* lands in fewer lines.

The overlap is real — a hunk that reimplements an existing helper is `Redundant`
here and `Reuse` there — but the question differs. `/simplify` asks "is this the
best version of this code?"; you ask "does this line need to be in this PR?"

## Modes

The skill takes an optional mode argument. Default is what you want almost
always; the others are the user explicitly telling you their taste is more
aggressive than the safe baseline.

| Mode | What it cuts on top of the default |
|---|---|
| `default` (or no argument) | Nothing extra. Comments, docstrings, tests and logging that the diff added all stay. |
| `no-comments` | Comments and docstrings added by this diff |
| `no-tests` | Test cases added by this diff |
| `no-logs` | Log and print statements added by this diff |
| `full` | All three |

Modes combine: `no-comments no-logs` is valid.

Two things hold no matter which mode is on.

**They apply only to lines this diff added.** Deleting a comment, test, or log
line that already existed on the base *grows* the diff and quietly removes
someone else's work. If it is not in the diff, it is not yours to touch.

**Say what a mode cost.** `no-tests` overrides the "never cut" list below —
honor it, the user owns that call, but list exactly which test cases went so
they can see the coverage they traded away. Same for `no-logs`: keep logging
the feature exists to emit (audit trails, error paths, anything an alert or
dashboard reads) and cut the debug narration; if you cannot tell which a line
is, ask rather than guess — you cannot see what reads that log downstream.

## Ask instead of assuming

A diff tells you what changed. It never tells you why. That gap is where this
work goes wrong: an interface with one implementation looks speculative, but it
may exist because the second implementation lands in next week's PR — and
nothing in the diff can tell you that. Guessing confidently there deletes work
someone was counting on.

So when a cut turns on intent rather than on code, ask. Use `AskUserQuestion`,
not a line buried in the report and not a "say the word and I'll put it back"
after you have already cut it. Asking afterwards is not asking, it is
reporting.

**Do everything unambiguous first.** Most of a diff is not a judgment call.
Revert the formatting churn, drop the dead imports, restore the reordered
blocks — none of that needs permission. Never open with a wall of questions
before you have done any work.

**Batch them into one call.** By the end of Step 3 you know every open
question. Ask them together, before you start cutting, so the user answers once
instead of being interrupted five times.

**Recommend first.** Lead each option with the one you would take and why. The
user is picking between real alternatives, not doing your analysis for you.

**Never ask what the repo can answer.** Grep for callers, read `git log`, check
the CI config, look at the tests. A question you could have resolved in ten
seconds of searching costs more trust than it saves.

Ask when you hit these, because none of them are answerable from code alone:

- **An ambiguous base.** More than one plausible base branch, or the branch has
  merges from main in it. Every number downstream depends on getting this right.
- **Anything observable leaving the diff.** A removed log or print, a changed
  error message, an altered status code or exit code, different timing. What
  looks like obvious debug output may be what a log scraper, alert, or support
  runbook keys on.
- **A speculative abstraction that might be load-bearing.** One implementation
  today is only evidence if there is no second one coming. Ask before cutting
  an interface, hook, flag, or extension point.
- **Drive-by work: extract, revert, or keep?** Extracting is usually right, but
  an urgent fix may need to ride along to ship today, and the person who wrote
  it knows which it is.
- **A "duplicate" helper that is not quite identical.** Present the difference
  and let them decide. Reconciling it yourself is a behavior change.
- **Any cut that touches the never-cut list below.**
- **Split granularity**, when the natural split is more than about three PRs,
  or when the team squash-merges and a stack buys them nothing.

If you genuinely cannot ask — non-interactive run, no one there — take the
conservative branch every time, keep the code, and put each unanswered question
in the report as an explicit open item rather than silently resolving it.

## Step 1 — Resolve the diff

The user gives you a source and a target in whatever form is convenient. Turn
it into one concrete diff before doing anything else, and echo back what you
resolved so a wrong base gets caught immediately rather than after an hour.

| What they gave you | What to run |
|---|---|
| A branch (`feature/x`, or "my branch") | `git diff --stat <base>...<branch>` — three dots, so you compare against the merge base and not against whatever landed on main since |
| A commit | `git show --stat <sha>` |
| A range | `git diff --stat <a>..<b>` |
| "my current work" | `git diff` plus `git diff --staged`, and `git status` for untracked files |
| Two raw files or trees | `git diff --no-index a b` |

If they did not name a base, work it out (`git symbolic-ref refs/remotes/origin/HEAD`,
or whatever `main`/`master`/`develop` exists). When exactly one candidate is
plausible, use it and say which one you picked. When more than one is — a repo
with both `main` and `develop`, or a branch cut from another feature branch —
ask, because getting this wrong makes every number and every cut downstream
meaningless.

Then measure, so you have a real before-number to beat:

```bash
python3 <skill-dir>/scripts/diff_report.py <base>...<head>
```

It prints per-file added/removed, how much of the diff is whitespace-only, and
which files git is showing as full rewrites when they are really moves. Those
three numbers usually explain most of the bloat before you have read any code.

## Step 2 — Pin down the contract, and get a baseline that runs

Write down, in one short list, what must be true after your cuts that was true
before: the user-visible behavior, the public API or exported surface, the UI
states, the data written. This is what you are protecting. Everything else is
negotiable.

Then find the project's own checks and **run them before you change anything**.
This matters more than it sounds: repos routinely have failing or flaky tests
already, and if you skip the baseline you will spend the session blaming
yourself for a test that was red when you arrived.

Look for what the repo actually uses — `package.json` scripts, `Makefile`,
`pyproject.toml`, `build.gradle`, `pubspec.yaml`, CI workflow files — and run
the cheapest useful subset: typecheck/compile, unit tests, lint. Run e2e or
integration suites too when they exist and finish in reasonable time; if they
are slow, run the ones covering the touched area. Record the exact commands and
the exact results.

If there is no test at all for the behavior being changed, say so plainly. It
does not block the work, but it changes how conservative you should be — with
no safety net, cut only what is provably inert (whitespace, unreachable code,
unused symbols) and leave judgment calls alone.

## Step 3 — Classify every hunk

Every hunk lands in exactly one of five buckets. Four are things you might cut.
The fifth, **Essential** — remove it and the feature stops working or the bug
comes back — is the residue: any hunk no angle below claims is Essential, and
therefore untouchable. Defaulting to Essential is the safe direction to fail.

The four cut buckets are independent questions asked of the same diff, so ask
them concurrently. Launch **four read-only review agents** with the Agent tool,
all in one message so they run at once, and hand each the diff plus one brief
below. A diff big enough to need this skill is too big to classify by reading it
five times in sequence, and by the fourth pass you are skimming — which is
exactly when a load-bearing hunk gets miscalled as noise.

This is the only place the skill fans out. The agents read, grep and report;
they never edit. Steps 2, 4 and 5 stay one sequential agent because they run
builds and tests, and two of those racing each other is slower than one.

Each agent returns findings in this shape and nothing else:

| Field | Meaning |
|---|---|
| `file`, `line` | Where the hunk is |
| `bucket` | Which of the four it claims |
| `summary` | One line: what this hunk does |
| `evidence` | The grep, `git log`, or caller list backing the claim |
| `behavior_risk` | `inert` if it provably cannot change behavior, `intent` if the call depends on why someone wrote it |

Those last two fields are what make the findings usable. A bucket claim with no
evidence is a guess dressed as a verdict, and the `intent` rows are precisely
the batch of questions you owe the user at the end of this step.

If the Agent tool is unavailable, work the four briefs yourself in sequence in
this same context. The output shape does not change — Steps 4 through 6 all read
from that table, so it has to exist either way.

### Incidental

No semantic content at all. Reformatting from a formatter or
IDE, import reordering, whitespace and blank-line churn, line rewrapping, EOL
or trailing-comma changes, comment reflows, regenerated files whose inputs did
not change, lockfile churn with no dependency change.

These get reverted outright once classification is done: `git checkout <base> --
<file>` for files that are pure noise; for mixed files, revert selectively with
`git checkout -p` so you keep the essential hunks.

### Drive-by

Real, often good work that simply is not this change: an
unrelated bug fix, a rename, a refactor of code the feature never touches,
dead-code deletion, dependency bumps, TODO cleanup, log-level tweaks. These get
**extracted, never discarded**. Move them to their own branch (see
`references/splitting.md`) and mention the branch in your report. Deleting
someone's unrelated bug fix to hit a line count is the fastest way to make this
skill untrusted.

Extracted work travels exactly as it was. Do not improve it on the way out —
no added tests, no renames, no tidying. It is a different change with a
different reviewer, and growing it is the same mistake you are here to undo. If
it lands somewhere untested, say so in the report and let the user decide.

### Speculative

Added for a future that has not arrived. An interface with one
implementation, a factory for one product, a config option with one possible
value, a parameter every caller passes the same value for, a helper called once,
error handling for inputs that cannot occur, a new dependency for something the
standard library or an existing utility already does, tests that exercise the
scaffolding rather than the behavior. Cut it. The future can add it back in the
commit that actually needs it, and that commit will be clearer for it.

### Redundant

Reimplements something the repo already has. Before accepting
any new helper, type, constant, or util, grep for it. Reusing an existing
function usually deletes twenty lines and makes the change more idiomatic at
the same time.

But read both implementations before you collapse them. Two functions that
look interchangeable often are not: a different rounding mode, timezone
assumption, null or empty-string handling, or sort stability. The bug this
produces is invisible in review — the diff shows a line getting *shorter* —
and it lands in money, dates, or ordering, which is exactly where it hurts. If
they differ at all, keep the new behavior byte-for-byte and flag the
inconsistency as a follow-up. Making them agree is a behavior change, and
behavior changes do not belong in a diff-shrinking pass.

### Merge, dedup, self-check

Wait for all four to finish, then reconcile into one table. Two agents claiming
the same hunk is normal and informative — a whitespace-only hunk inside a file
that is entirely drive-by is genuinely both — so keep one row and let the more
conservative action win: revert beats extract, extract beats cut.

Then re-check each surviving finding against the diff yourself before acting on
it. An agent that only saw the diff cannot see the caller three directories
away, or the base-branch context you gathered in Step 1; you can. Drop anything
you judge a false positive and note the drop rather than arguing with it — a
wrong cut costs far more than a line you left in.

Classification is where the open questions surface. Every row marked `intent` is
one you cannot resolve from code. Ask that whole set now, in one batch, before
you touch anything — see "Ask instead of assuming" above.

## Step 4 — Shrink

Reverting the incidental and speculative buckets does most of the work. What is
left is rewriting the essential change so it lands in fewer lines. These are
the moves that reliably pay:

**Fix it once, where the callers meet.** If the change is repeated across every
call site, there is almost always a single shared function they all route
through. One guard there is both the smaller diff and the more correct fix —
patching call sites individually leaves the ones you did not think of broken.

**Never reindent to add a wrapper.** Wrapping a 200-line body in a new `if`,
`try`, or `with` re-indents every line and turns a 3-line change into a 200-line
one. Invert it instead: an early return or guard clause at the top, or pull the
body into a function you call from the new wrapper — and if you must extract,
do the pure extraction in its own commit so git shows it as a move.

**Modify in place; move separately.** A file that is moved *and* edited looks
like a delete plus a full rewrite. If the move is genuinely needed, commit the
move alone with byte-identical content — git then renders it as a one-line
rename — and edit it in the next commit.

**Do not reorder what does not need reordering.** Imports, methods, JSON and
YAML keys, CSS properties, enum members, translation strings. Appending is a
one-line diff; inserting alphabetically rewrites the block. Order only matters
when the language says it does.

**Match the file's existing style even when you would write it differently.**
A change written in the surrounding idiom disappears into the file. One written
in your preferred style shows up as a foreign body and drags the reviewer into
a style discussion instead of the logic.

**Prefer the smaller mechanism** when two produce the same behavior: an existing
dependency over a new one, a stdlib call over a hand-rolled loop, a database
constraint over application checks, a platform feature over a library, a
default parameter over an overload.

**Delete what you added and did not use.** New imports, constants, test
fixtures, and helpers left behind by an approach you abandoned mid-way.

After each meaningful cut, re-run the fast checks. Finding out which of twelve
cuts broke a test is much harder than never letting twelve stack up.

## What never gets cut

Making these smaller makes the change worse, and a reviewer will (rightly) send
it back:

- Input validation at trust boundaries, and authorization checks
- Error handling that prevents data loss or corruption
- Anything security-related: escaping, parameterized queries, secret handling
- Accessibility: labels, focus order, contrast, semantics, touch target size
- Tests covering the behavior this change actually alters
- Migration and rollback safety, feature-flag off-paths, backwards compatibility
- Null/empty/loading/error UI states — a state you drop is a blank screen in
  production, not a saved line

If shrinking something would touch this list, stop and keep the code.

## Step 5 — Verify, then say exactly what you verified

Re-run the same commands from Step 2 and compare against the baseline. Anything
that passed before must pass now. Anything that failed before is allowed to keep
failing — note it, do not fix it here, that is a drive-by.

Then close the gap the tests do not cover, honestly:

- For each cut with no test behind it, state in one line why it cannot change
  behavior ("the interface had one implementation and one caller, both in this
  diff" is a real argument; "looked safe" is not).
- For UI or UX changes, name the exact screens and interactions a human should
  click, since no suite you can run proves the pixels are unchanged.
- Flag anything you were unsure about and kept. An honest "I left this alone
  because I could not prove it was inert" is worth more than a smaller number.

If a check that passed before now fails, revert your last cut rather than
patching over it. The failure is telling you that hunk was load-bearing.

## Step 6 — Split what remains into a stack

A 200-line diff that is really four unrelated concerns still reviews like a
600-line one. Group the remaining hunks into an ordered sequence where **every
prefix of the stack is safe to merge on its own** — each commit builds, passes,
and leaves the product working, even if the later ones never land.

The ordering that usually satisfies that:

1. Pure moves and renames, no content change
2. Dependency, config, and schema/migration changes that later steps need
3. Behavior-neutral refactors that make room for the feature
4. The feature or fix itself, with its tests
5. Removals and cleanup that are only safe once nothing calls the old path

Then hand over something runnable, not a description: the branch names, the
commit subjects, and the exact commands. `references/splitting.md` has the
recipes for carving a branch into a stack (`git add -p`, interactive rebase,
cherry-pick, worktrees) and for parking extracted drive-by work.

Follow the repo's own branch and commit conventions if it has them; otherwise
`<type>/<scope>-<description>` for branches and `<type>(<scope>): <description>`
for subjects.

## Report

Keep it short and factual. The user wants to know what changed, whether it is
safe, and what to do next.

```
## Result
<before> lines changed across <n> files → <after> across <n> files

## Cut
- <what> — <bucket> — <why it cannot change behavior>

## Extracted (not deleted)
- <what> → branch <name>

## Kept deliberately
- <what> — <why shrinking it would be wrong or unprovable>

## Decided with you
- <question you asked> → <what they chose>

## Open questions          (only when you could not ask)
- <what you could not resolve, and the conservative choice you made instead>

## Verification
- <command> → <before result> / <after result>
- Needs a human: <screen or flow to click>

## Suggested stack
1. <branch> — <subject> — ~<n> lines
2. ...
```

Lead with the numbers, but never let the numbers be the argument. The claim you
are making is "this is the same product, in fewer lines" — and the verification
section is what backs it.
