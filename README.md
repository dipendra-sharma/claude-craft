# claude-craft

A Claude Code plugin marketplace with two plugins, `craft` and `craft-proof`. Install one of them, not both: they carry the same skills.

`craft` carries Dipendra's authored skills and the answering-style rules from `~/.claude/CLAUDE.md`.
Its hooks make Claude keep a todo list, plan and run a check before it calls work done, and keep a few rules that suit
any developer. See the plugin's own README for the list.

`craft-proof` carries the same skills with proof hooks instead: Claude writes a contract of claims before it
changes code, hooks record the real result of each check against the current code, and Claude cannot
finish until every claim is proven or named as unverified. See its own README.

## Layout

```
.claude-plugin/marketplace.json   the catalog
plugins/craft/                    the craft plugin — see its own README
plugins/craft-proof/              the craft-proof plugin — see its own README
```

## Try it without installing

```bash
git clone https://github.com/dipendra-sharma/claude-craft.git
claude --plugin-dir claude-craft/plugins/craft
claude --plugin-dir claude-craft/plugins/craft-proof
```

## Install it

```bash
claude plugin marketplace add dipendra-sharma/claude-craft
claude plugin install craft@dipendra          # or craft-proof@dipendra
```

Or from inside a session:

```bash
/plugin marketplace add dipendra-sharma/claude-craft
/plugin install craft@dipendra
```

The hooks need `jq` (a command-line JSON tool). Without it they stay off and say so.

## Heads up on duplicates

The 15 skills in `plugins/craft/skills/` are copies. The originals still live in
`~/.claude/skills/` and are untouched. Loading this plugin while those originals are in place means
each skill loads twice — once as `/<name>` and once as `/craft:<name>` — which doubles their context
cost and gives the model two near-identical descriptions to choose between.

Use `--plugin-dir` for testing. Before installing it for daily use, move the 15 originals out of
`~/.claude/skills/`.

Because they are copies, editing a skill in `~/.claude/skills/` does not update this repository.
Re-sync before you push:

```bash
bash plugins/craft/scripts/sync-skills.sh
```

## Tests

```bash
bash plugins/craft/tests/run.sh
bash plugins/craft-proof/tests/run.sh
```

