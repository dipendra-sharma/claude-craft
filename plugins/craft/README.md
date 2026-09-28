# Craft

A Claude Code plugin holding Dipendra's authored skills and the answering-style rules from
`~/.claude/CLAUDE.md`, plus hooks that make Claude prove its work and keep a few rules that suit any
developer.

## What is in here

| Part | What it does |
| :--- | :--- |
| `skills/` | The 15 skills in this repository, namespaced as `/craft:<name>` |
| `output-styles/plain-english.md` | The answering-style rules, applied while the plugin is on |
| `hooks/hooks.json` | Wires the hooks below to their events |
| `scripts/*.sh` | One script per hook, plus `lib.sh` for the shared helpers |
| `bin/craft-allow` | Grants a visible, 30-minute exception to the manifest guard |
| `scripts/sync-skills.sh` | Re-copies the skills from `~/.claude/skills` and reports what changed |
| `tests/run.sh` | 61 cases covering every hook, both blocked and allowed |

## The skills

`backend-best-practices`, `calculator`, `coding-best-practices`, `dashboard-best-practices`, `database-best-practices`,
`decision-partner`, `design-patterns-best-practices`, `explain-anything`, `firebase-crash-fix`,
`github-bug-report`, `minimize-diff`, `product-spec`, `render-performance-best-practices`,
`testing-best-practices`, `ui-state-best-practices`.

## Keeping the skills current

The skills here are copies. Editing one in `~/.claude/skills` does not update this repository, so the
published version goes stale silently. Re-sync before you push:

```bash
bash plugins/craft/scripts/sync-skills.sh
```

It copies only the skills this plugin already contains, skips the ones that have not changed, and
names the ones it replaced. It refuses to run outside a git repository, so a replaced file is always
recoverable. Pass a different source directory as the first argument if your skills live elsewhere.

## The hooks

| Hook | When | What it does |
| :--- | :--- | :--- |
| `plan-proof.sh` | Before the first edit of each prompt | Asks Claude to write `Done when: <result> — checked by: <check>` first. Asks once per prompt, and skips subagents and files outside the project |
| `verify-before-done.sh` | When Claude stops | If a project file changed after the last check ran, sends Claude back once to run the check it planned, or to say plainly that the change is unverified. Documentation files are exempt |
| `lint-edited-file.sh` | After each edit | Runs the project's own linter on just that file and shows Claude any problems: ruff, eslint or biome, shellcheck, go vet, dart analyze, ktlint, swiftlint, rubocop, and a JSON syntax check. A missing linter is skipped |
| `project-facts.sh` | At session start | Tells Claude the branch, the package managers named by the lockfiles, the scripts and make targets, pinned runtime versions, and installed versions |
| `guard-manifest.sh` | Before edits and shell commands | Blocks hand edits to lockfiles, creating a manifest by hand instead of with the init command, dependency changes in a manifest, and shell writes (`>`, `tee`, `sed -i`) to either. Scripts, settings and the package's own version stay editable |
| `git-format.sh` | Before `git` and `gh` commands | Branch names `<type>/<scope>-<description>`, lowercase, hyphenated, 50 characters at most; commit subjects and pull request titles `<type>(<scope>): <description>`. The scope is optional. Merge, revert and fixup subjects pass. Attribution lines are left alone |

Types are `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`.

## Use it

```bash
claude plugin marketplace add dipendra-sharma/claude-craft
claude plugin install craft@dipendra
```

The hooks need `jq`. Without it they stay off and print a one-line warning.

## Escape hatches

Shell commands: put the setting first in the command itself, after saying why.

```bash
CLAUDE_CRAFT_RULES=off <command>
```

Edits to a manifest or lockfile (no package manager, offline): run the plugin's `craft-allow`, which
is on the shell path while the plugin is enabled.

```bash
craft-allow /abs/path/to/package.json     # that file, for 30 minutes
```

Starting Claude Code with `CLAUDE_CRAFT_RULES=off` in its environment turns every hook off.

## Tests

```bash
bash tests/run.sh
```
