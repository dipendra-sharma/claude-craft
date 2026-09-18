# Craft

A Claude Code plugin holding Dipendra's authored skills and turning the advisory rules in
`~/.claude/CLAUDE.md` into hooks that block rather than ask.

## What is in here

| Part | What it does |
| :--- | :--- |
| `skills/` | The skills in this repository, namespaced as `/craft:<name>` |
| `hooks/hooks.json` | Wires the guards to tool events |
| `scripts/lib.sh` | Shared helpers: the shell-command parser, manifest rules, the allow list |
| `scripts/guard-bash.sh` | Refuses shell commands that break one of the rules |
| `scripts/guard-write.sh` | Refuses hand-edits to lockfiles and to the dependency sections of manifests |
| `scripts/check-comments.sh` | Refuses an edit that adds comments to source code, before it is written |
| `scripts/guard-slack.sh` | Refuses a direct Slack send, pointing at the draft tool |
| `bin/craft-allow` | Grants a visible, short-lived exception to an edit guard or the Slack guard |
| `scripts/sync-skills.sh` | Re-copies the skills from `~/.claude/skills` and reports what changed |
| `output-styles/plain-english.md` | The answering-style rules, applied while the plugin is on |
| `tests/run.sh` | 119 cases covering every guard, both blocked and allowed |

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

The shell guard parses each command, so it sees through `&&`, pipes, subshells, `$( )`, `bash -c`,
`sudo`, `xargs`, and full paths like `/bin/rm`, and it ignores words inside quotes and heredocs.

| Rule | Blocked |
| :--- | :--- |
| Deleting | `rm` and `unlink` on anything outside a build or cache folder (a path that climbs out with `..` does not count); `find -delete` and `find -exec rm` outside one; `xargs rm`; `git clean -f`; `shutil.rmtree`, `os.remove`, `fs.rm` |
| Attribution | `Co-Authored-By: Claude`, `Generated with`, generator lines in a commit, tag, pull request, issue, or release — in the command or in a `-F` / `--body-file` message file |
| Git | a forced push (`--force`, `-f`, `-uf`, `+branch`) without a lease; `git@` and `ssh://` remotes; `git rm` without `--cached` |
| Command line first | Every lockfile; dependency changes in `package.json`, `pubspec.yaml`, `Cargo.toml`, `pyproject.toml`, `go.mod`, `Gemfile`, `Podfile`, `composer.json`; creating one of those by hand; shell writes to any of them (`sed -i`, `>`, `tee`, `cp`) |
| Waiting | `sleep`, including inside a loop |
| Throttling | More than one Gradle task per invocation; tuning flags; a Gradle, Xcode, or Cargo build while another one runs |
| Worktrees | `git worktree add` outside a git repository |
| Comments | New comment lines and trailing comments in source code; comments already in the file are left alone |
| Slack | `slack_send_message`, pointing at `slack_send_message_draft` |

Allowed on purpose: scripts, assets, tool settings, and the package's own version in a manifest.
Gradle files, `pom.xml`, `Package.swift`, and `requirements.txt` have no add-dependency command, so
edits to them go through — but when an edit types a version number, Claude gets a reminder to
resolve it from the registry first.

Each refusal names the rule and the command to run instead. The messages name the package manager
the project already uses (bun, npm, pnpm, yarn, uv, poetry, pdm, pipenv).

## What the hooks cannot do

Nothing catches Claude's prose. The `MessageDisplay` hook fires as text streams but cannot block,
so the answering-style rules are carried by the output style and stay advisory. The same is true of
"read, never recall", "map the blast radius", and "one line of proof per claim" — they describe how
to think, and no tool event corresponds to them. Those stay in `CLAUDE.md`.

## Use it

```bash
claude plugin marketplace add dipendra-sharma/claude-craft
claude plugin install craft@dipendra
```

The guards need `jq`. Without it they stay off and print a one-line warning on each call.

## Escape hatches

The rules carve out their own exceptions — a missing binary, an offline machine, nothing observable
to poll, a comment the user asked for. Each hatch makes the exception visible instead of silent, and
Claude is told to say why before using one.

Shell commands: put the setting first in the command itself.

```bash
CLAUDE_CRAFT_RULES=off <command>
```

Edits and Slack: there is no command to prefix, so run the plugin's `craft-allow` command first. It
is on the shell path while the plugin is enabled.

```bash
craft-allow /abs/path/to/package.json     # that file, for 30 minutes
craft-allow slack                          # one direct Slack send
```

Starting Claude Code with `CLAUDE_CRAFT_RULES=off` in its environment turns every guard off.

## Tests

```bash
bash tests/run.sh
```

They run against fixtures in `tests/fixtures/`, including a fake process list, so the result does not
depend on what else is running on the machine.
