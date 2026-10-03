# Craft Proof

A Claude Code plugin that makes Claude prove its work, for code and for any other deliverable, plus
Dipendra's 15 authored skills from `craft`.

Before Claude changes code or writes a deliverable (a document, plan, report, analysis or data file), it
writes a contract: what you will see when the work is done, and evidence for each claim. For code, hooks
record the real pass or fail of every check against a fingerprint of the current code. For everything
else, hooks re-open quoted sources, recompute numbers, check file contents, and ask a judge about what
only judgement can check. Claude cannot finish until every claim is proven on the final content; anything
it cannot prove is named as unverified and shown to you.

Use it instead of `craft`, not alongside it: both carry the same skills.

## What is in here

| Part | What it does |
| :--- | :--- |
| `skills/` | The 15 `craft` skills plus `contract`, namespaced as `/craft-proof:<name>` |
| `hooks/hooks.json` | Wires the hooks below to their events |
| `scripts/proof-*.sh` | One script per proof hook, plus `proof-lib.sh` and `lib.sh` for the shared helpers |
| `scripts/lint-edited-file.sh` | The fast check after each edit |
| `scripts/sync-skills.sh` | Re-copies the skills from `~/.claude/skills` and reports what changed |
| `tests/run.sh` | 115 checks covering every hook, every evidence type, the todo rules and every known cheat, blocked and allowed |
| `evals/` | Four quick cases, each run with the plugin and without it |
| `evals-complex/` | A three.js game built from a 12-rule spec |
| `acceptance/` | 21 hidden tests for that game, run on each finished workspace |
| `docs/design.md` | The design this plugin was built from, how the build differs, and the evidence so far |

## The skills

`backend-best-practices`, `calculator`, `coding-best-practices`, `contract`, `dashboard-best-practices`,
`database-best-practices`, `decision-partner`, `design-patterns-best-practices`, `explain-anything`,
`firebase-crash-fix`, `github-bug-report`, `minimize-diff`, `product-spec`,
`render-performance-best-practices`, `testing-best-practices`, `ui-state-best-practices`.

The hooks point Claude at the skill that fits the moment: `contract` before the first code edit,
`testing-best-practices` when it writes the test behind a claim or a check must be seen failing first,
and `coding-best-practices` when it writes the code.

## How proof works

1. Claude writes `.proof/contract.json` before its first code edit:

   ```json
   {
     "goal": "Checkout total never goes below zero",
     "kind": "bugfix",
     "claims": [
       {"id": "C1", "claim": "A coupon larger than the cart gives 0", "check": "./run-tests.sh", "fail_first": true}
     ],
     "unverified": ["Delivery to the production webhook: no access here"]
   }
   ```

2. It runs each check from the project root, in the foreground, with exactly the text in `check`. The
   hooks record pass or fail with fingerprints of the code and of the test files at that moment.
3. The contract locks as soon as any check's program runs. After that, claims can only be added.
4. Before Claude can finish, every claim must pass on the current code. A `fail_first` claim must have
   been seen failing with the same test files and different code before it passed.
5. When Claude finishes, you see how many claims were proven and every unverified item.

Rules that close the usual shortcuts:

- Existing test files, test settings and the scripts a check runs are read-only. New tests go in new files.
  A test file can only change if the contract says why before any check runs.
- Skip, focus and expected-failure markers are blocked in tests.
- Checks cannot use `|`, `||` or `;`, and a check that cannot fail is rejected. A "command not found"
  failure does not count as a red run.
- Background runs, runs from another folder, and anything that is not a real tool result are not proof.
- Shell commands cannot touch the plugin's scripts or its records.

### Deliverables

Documents, plans, reports, analyses and data files are deliverables: `.md`, `.txt`, `.rst`, `.adoc`, `.csv`
and `.tsv` files inside a git repository, and any file Claude writes outside one. Writing a deliverable
needs a contract, every deliverable written must be named by a claim, and the contract locks the first time
Claude tries to finish. Each claim carries one kind of evidence, re-checked on the final content:

| Evidence | Example | How it is checked |
| :--- | :--- | :--- |
| `check` | `"./run-tests.sh"` | The hooks record the command's real result (code only) |
| `source` | a link or file, plus an exact quote | The hooks re-open it and look for the quote, ignoring HTML tags, spacing and case |
| `calc` | `"4200 * 12"` equals `"50400"` | The hooks recompute it with `qalc`, or `bc` for plain arithmetic |
| `file` | `docs/plan.md` contains `^## Risks` | The hooks match each pattern against the final file |
| `rubric` | PASS and FAIL conditions for a file or the final reply | A judge model reads it, only after everything else passes, and only once per version of the content |

Files under `.claude/` are never gated, so memory and settings writes are not affected.

### Where the records live

In a git repository, the records live in `.git/craft-proof/`, out of the work tree, so `git clean` does not
touch them. The contract sits in the work tree at `.proof/contract.json`, hidden from git through
`.git/info/exclude`. Outside a repository, both live in `.proof/` in the session's folder, and only the
files Claude's tools write are tracked. The hooks stay off when a session starts in the home folder or `/`.

## The hooks

| Hook | When | What it does |
| :--- | :--- | :--- |
| `proof-session-start.sh` | At session start, after `/clear`, and after a context summary | Records the baseline fingerprint and gives Claude the contract rules. On a new session or `/clear`, archives the last task's contract; if that task was not proven, its changes still count. After a summary, gives back the active contract and each claim's status |
| `proof-user-prompt.sh` | On each prompt | After a proven task, archives its contract and takes a new baseline, so the next task starts fresh |
| `proof-guard-edit.sh` | Before each edit | Blocks code edits and deliverable writes until a valid contract exists, and, when the contract has 3 or more claims, until a todo list exists. Also blocks any change to a read-only file, skip markers in tests, writes to other files under `.proof/`, and contract changes after the lock other than added claims |
| `proof-guard-bash.sh` | Before each shell command | Blocks shell writes into `.proof/`, into read-only files, or anywhere near the plugin's scripts and records, and `--no-verify`. Locks the contract when a check's program is about to run |
| `lint-edited-file.sh` | After each edit | Runs the project's own linter on just that file and shows Claude any problems: ruff, eslint or biome, shellcheck, go vet, dart analyze, ktlint, swiftlint, rubocop, and a JSON syntax check. A missing linter is skipped |
| `proof-after-edit.sh` | After each edit | Notes each deliverable written. When the contract is saved, checks it and rejects claims without exactly one kind of evidence, weak checks, quotes too short to prove anything, unknown kinds, and bug fixes with no `fail_first` claim |
| `proof-record-evidence.sh` | After each shell command | When the command matches a claim's check, records pass or fail with the code and test fingerprints. Files the check itself wrote are left out of the fingerprint. After two failures in a row it tells Claude to stop guessing |
| `proof-task-gate.sh` | When a todo item is marked completed | Refuses it while any claim the item names (by id, such as `C2`) is not proven, and says which claim and why |
| `proof-stop-gate.sh` | When Claude stops | Locks the contract, then blocks until every claim is named by a todo item (at 3 or more claims), no todo item is left open without a `Blocked:` reason, every check claim is proven on the current code, every source, calc and file claim holds on the final content, every deliverable is covered, rubric claims pass the judge, the contract is intact, and read-only files are unchanged. Fails closed if the records are missing. After three identical blocks with no progress it lets the turn end and tells you what stayed unproven |

Matching a command to a check ignores extra spaces, a leading `cd <project> &&`, and the project's full
path, so `./run-tests.sh` and `/abs/project/run-tests.sh` count as the same check.

## Use it

```bash
claude plugin marketplace add dipendra-sharma/claude-craft
claude plugin install craft-proof@dipendra
```

Disable `craft` first if it is installed, so the skills do not load twice. The hooks need `jq` and git
2.31 or later. Without `jq` they stay off and print a one-line warning.

## Settings

There is one: `CLAUDE_CRAFT_RULES=off`.

- In front of a shell command, it lets that one command through the shell guard, after Claude says why:
  `CLAUDE_CRAFT_RULES=off <command>`.
- In Claude Code's environment at startup, it turns every hook off.

The hooks also read two variables Claude Code itself defines: `CLAUDE_PROJECT_DIR`, to fix the project root
for the session, and `CLAUDE_CONFIG_DIR` (when you have set it), to find the session's todo list.

## Tests

```bash
bash tests/run.sh
```

## Evals

Each case runs with the plugin and without it, and reports the difference.

```bash
claude plugin eval . --scaffold --trust-plugin --allow-tools Bash Write Edit --no-publish
claude plugin eval . --eval-dir evals-complex --scaffold --trust-plugin --allow-tools Bash Write Edit --no-publish --keep-temp
bash acceptance/threejs-game/analyze.sh evals-complex/results/<run>/aggregate-result.json
```

The complex case fetches three.js once with `npm pack` into `evals-complex/threejs-game/vendor/`, which
git ignores. The hidden tests need Node at `/usr/local/bin/node`.

What the first runs showed (2026-10-03):

- Small tasks (24 runs): every case scored 1.00 with the plugin; without it, three cases scored 1.00 and
  the bug fix scored 0.83–0.92, where a reply did not say what was tested. About 15–40% more cost.
- three.js game (4 runs): every run passed all 21 hidden tests with and without the plugin. With it,
  Claude wrote 20–40% more tests and both runs added an automated check of the rendering file, which
  neither run without it did. About 60% more cost and twice the turns.

## Keeping the skills current

The 15 `craft` skills here are copies. Re-sync before you push:

```bash
bash scripts/sync-skills.sh
```

It reports `contract` as missing from `~/.claude/skills`, which is expected: that skill lives only here.

## Limits

- Hooks are guardrails against shortcuts, not a wall: a shell command can always do something no pattern
  foresaw. The only hard check is the one your CI runs on every push.
- Nothing yet checks that the claims cover the whole request, or that a check really tests its claim.
- Plain chat answers are not gated; only code and deliverables are.
- Rubric claims need the `claude` command on the PATH and cost one small model call per new version of the
  judged content. Without it, a rubric claim cannot pass; name it as unverified instead.
- Source checks use a plain fetch, so pages that need a login or render with JavaScript cannot be quoted.
- Outside a git repository, only files written with the Write and Edit tools are tracked.
