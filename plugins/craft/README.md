# Craft

A Claude Code plugin holding Dipendra's authored skills and turning the advisory rules in
`~/.claude/CLAUDE.md` into hooks that block rather than ask.

## What is in here

| Part | What it does |
| :--- | :--- |
| `skills/` | The skills in this repository, namespaced as `/craft:<name>` |
| `hooks/hooks.json` | Wires the guards to tool events |
| `scripts/guard-bash.sh` | Refuses shell commands that break one of the rules |
| `scripts/guard-write.sh` | Refuses hand-edits to manifests and lockfiles |
| `scripts/check-comments.sh` | Flags comments added to tracked source files |
| `scripts/sync-skills.sh` | Re-copies the skills from `~/.claude/skills` and reports what changed |
| `output-styles/plain-english.md` | The answering-style rules, applied while the plugin is on |
| `tests/run.sh` | 31 cases covering every guard, both blocked and allowed |

## Keeping the skills current

The skills here are copies. Editing one in `~/.claude/skills` does not update this repository, so the
published version goes stale silently. Re-sync before you push:

```bash
bash plugins/craft/scripts/sync-skills.sh
```

It copies only the skills this plugin already contains, skips the ones that have not changed, and
names the ones it replaced. It refuses to run outside a git repository, so a replaced file is always
recoverable. Pass a different source directory as the first argument if your skills live elsewhere.

## What the hooks block

| Rule | Blocked |
| :--- | :--- |
| Deleting | `rm` on anything outside a build or cache folder; `shutil.rmtree`, `os.remove`, `fs.rm` |
| Attribution | `Co-Authored-By: Claude`, `Generated with`, generator lines in a commit, tag, or pull request |
| Git | `git push --force` without a lease; `git@` SSH remotes; `git rm` without `--cached` |
| Command line first | Any edit to `package.json`, `pubspec.yaml`, `Cargo.toml`, `go.mod`, `build.gradle`, and every lockfile |
| Waiting | `sleep` |
| Throttling | More than one Gradle task per invocation; tuning flags; a second build while one runs |
| Worktrees | `git worktree add` outside a git repository |
| Slack | `slack_send_message`, pointing at `slack_send_message_draft` |

Each refusal names the rule and the command to run instead.

## What the hooks cannot do

Nothing catches Claude's prose. The `MessageDisplay` hook fires as text streams but cannot block,
so the answering-style rules are carried by the output style and stay advisory. The same is true of
"read, never recall", "map the blast radius", and "one line of proof per claim" — they describe how
to think, and no tool event corresponds to them. Those stay in `CLAUDE.md`.

## Use it

```bash
claude --plugin-dir ~/Workspace/claude-craft
```

To load it in every session, install it from a local marketplace or move it under
`~/.claude/skills/`. To publish it, add a `marketplace.json` and push to a repository.

## Escape hatch

Every guard honours one environment variable. Prefix the single command and say why:

```bash
CLAUDE_CRAFT_RULES=off <command>
```

This exists because the rules themselves carve out exceptions — a missing binary, an offline
machine, nothing observable to poll. The bypass makes the exception visible instead of silent.

## Tests

```bash
bash tests/run.sh
```
