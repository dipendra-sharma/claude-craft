# Craft Proof

A Claude Code plugin that makes Claude prove its work, plus Dipendra's 15 authored skills from `craft`.

Before Claude changes code, it writes a contract: what the user will see when the work is done, and one
command that proves each claim. Hooks record the real pass or fail of every check against a fingerprint
of the current code. Claude cannot finish until every claim is proven on the final code, or plainly named
as unverified.

Use it instead of `craft`, not alongside it: both carry the same skills.

## What is in here

| Part | What it does |
| :--- | :--- |
| `skills/` | The 15 `craft` skills plus `contract`, namespaced as `/craft-proof:<name>` |
| `hooks/hooks.json` | Wires the proof hooks below to their events |
| `scripts/proof-*.sh` | One script per hook, plus `proof-lib.sh` and `lib.sh` for the shared helpers |
| `scripts/sync-skills.sh` | Re-copies the skills from `~/.claude/skills` and reports what changed |
| `tests/run.sh` | 51 cases covering every hook and every cheat path, blocked and allowed |
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

2. It runs each check with exactly the text in `check`. The hooks record pass or fail, and a fingerprint
   of the code at that moment.
3. The contract locks the first time any check runs, so claims cannot change after the results are seen.
4. Before Claude can finish, every claim must be passing on the current code. A `fail_first` claim must
   have been seen failing before it passed. Unverified items must be named in the final reply.

State lives in `.proof/` in the project, hidden from git through `.git/info/exclude`. The hooks only act
inside git repositories.

## The hooks

| Hook | When | What it does |
| :--- | :--- | :--- |
| `proof-session-start.sh` | At session start and after a context summary | Records a fingerprint of every file and a copy of each existing test, and gives Claude the contract rules. After a summary, it gives back the active contract and each claim's status |
| `proof-guard-edit.sh` | Before each edit | Blocks code edits until a valid contract exists (documentation is exempt), changes or removals of an existing test's original lines (adding new tests is fine), skip markers in tests, edits to proof records, and contract changes after it locks |
| `proof-guard-bash.sh` | Before each shell command | Blocks shell writes into `.proof/` or into existing tests, and `--no-verify` |
| `lint-edited-file.sh` | After each edit | Runs the project's own linter on just that file and shows Claude any problems: ruff, eslint or biome, shellcheck, go vet, dart analyze, ktlint, swiftlint, rubocop, and a JSON syntax check. A missing linter is skipped |
| `proof-after-edit.sh` | After the contract is saved | Checks the contract and rejects claims with no check, checks that cannot fail (`true`, `echo`, `\|\| true`), and bug fixes with no `fail_first` claim |
| `proof-record-evidence.sh` | After each shell command | When the command matches a claim's check, records pass or fail with the code fingerprint. After two failures in a row it tells Claude to stop guessing |
| `proof-stop-gate.sh` | When Claude stops | Blocks until every claim is proven on the current code, the contract is unchanged, existing tests are intact, and unverified items are named. If the same problems repeat with no progress, it lets the turn end and tells you what stayed unproven |

Matching a command to a check ignores extra spaces, a leading `cd <project> &&`, and the project's full
path, so `./run-tests.sh` and `/abs/project/run-tests.sh` count as the same check.

## Use it

```bash
claude plugin marketplace add dipendra-sharma/claude-craft
claude plugin install craft-proof@dipendra
```

Disable `craft` first if it is installed, so the skills do not load twice. The hooks need `jq`. Without
it they stay off and print a one-line warning.

## Escape hatches

Shell commands: put the setting first in the command itself, after saying why.

```bash
CLAUDE_CRAFT_RULES=off <command>
```

Starting Claude Code with `CLAUDE_CRAFT_RULES=off` in its environment turns every hook off.

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

- Small tasks (24 runs): every case scored 1.00 with the plugin; without it, 1.00 on three cases and
  0.92 on the bug fix, where one reply did not say what was tested. About 15–40% more cost.
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

- Hooks are guardrails against shortcuts, not a wall. The only hard check is the one your CI runs on
  every push.
- The "unverified items are named" check looks for words such as "unverified" or "not tested", so a
  reply can be honest and still be sent back once.
