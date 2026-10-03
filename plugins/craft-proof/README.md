# Craft Proof

A Claude Code plugin that makes Claude prove its work, plus Dipendra's 15 authored skills from `craft`.

Before Claude changes code, it writes a contract: what the user will see when the work is done, and one
command that proves each claim. Hooks record the real pass or fail of every check against a fingerprint
of the current code. Claude cannot finish until every claim is proven on the final code; anything it
cannot prove is named as unverified and shown to you.

Use it instead of `craft`, not alongside it: both carry the same skills.

## What is in here

| Part | What it does |
| :--- | :--- |
| `skills/` | The 15 `craft` skills plus `contract`, namespaced as `/craft-proof:<name>` |
| `hooks/hooks.json` | Wires the hooks below to their events |
| `scripts/proof-*.sh` | One script per proof hook, plus `proof-lib.sh` and `lib.sh` for the shared helpers |
| `scripts/lint-edited-file.sh` | The fast check after each edit |
| `scripts/sync-skills.sh` | Re-copies the skills from `~/.claude/skills` and reports what changed |
| `tests/run.sh` | 88 checks covering every hook and every known cheat, blocked and allowed |
| `evals/` | Four quick cases, each run with the plugin and without it |
| `evals-complex/` | A three.js game built from a 12-rule spec |
| `acceptance/` | 21 hidden tests for that game, run on each finished workspace |

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

The records live in `.git/craft-proof/` inside the repository, out of the work tree, so `git clean` does
not touch them. Only the contract sits in the work tree, at `.proof/contract.json`, hidden from git through
`.git/info/exclude`. The proof hooks act only inside git repositories.

## The hooks

| Hook | When | What it does |
| :--- | :--- | :--- |
| `proof-session-start.sh` | At session start, after `/clear`, and after a context summary | Records the baseline fingerprint and gives Claude the contract rules. On a new session or `/clear`, archives the last task's contract; if that task was not proven, its changes still count. After a summary, gives back the active contract and each claim's status |
| `proof-user-prompt.sh` | On each prompt | After a proven task, archives its contract and takes a new baseline, so the next task starts fresh |
| `proof-guard-edit.sh` | Before each edit | Blocks code edits until a valid contract exists (documentation is exempt), any change to a read-only file, skip markers in tests, writes to other files under `.proof/`, and contract changes after the lock other than added claims |
| `proof-guard-bash.sh` | Before each shell command | Blocks shell writes into `.proof/`, into read-only files, or anywhere near the plugin's scripts and records, and `--no-verify`. Locks the contract when a check's program is about to run |
| `lint-edited-file.sh` | After each edit | Runs the project's own linter on just that file and shows Claude any problems: ruff, eslint or biome, shellcheck, go vet, dart analyze, ktlint, swiftlint, rubocop, and a JSON syntax check. A missing linter is skipped |
| `proof-after-edit.sh` | After the contract is saved | Checks the contract and rejects claims with no check, weak checks, unknown kinds, and bug fixes with no `fail_first` claim |
| `proof-record-evidence.sh` | After each shell command | When the command matches a claim's check, records pass or fail with the code and test fingerprints. Files the check itself wrote are left out of the fingerprint. After two failures in a row it tells Claude to stop guessing |
| `proof-stop-gate.sh` | When Claude stops | Blocks until every claim is proven on the current code, the contract is intact, and read-only files are unchanged. Fails closed if the records are missing. After three identical blocks with no progress it lets the turn end and tells you what stayed unproven |

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

The hooks also read `CLAUDE_PROJECT_DIR`, which Claude Code sets, to fix the project root for the session.

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
- Proof covers code changes in git repositories. Writing, research and other tasks outside a repository
  are not gated yet.
