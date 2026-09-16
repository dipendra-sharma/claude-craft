# claude-craft

A Claude Code plugin marketplace with one plugin, `craft`.

`craft` carries Dipendra's authored skills and turns the advisory rules in `~/.claude/CLAUDE.md`
into hooks that block a tool call rather than ask nicely.

## Layout

```
.claude-plugin/marketplace.json   the catalog
plugins/craft/                    the plugin — see its own README
```

## Try it without installing

```bash
claude --plugin-dir ./plugins/craft
```

## Install it

```bash
claude plugin marketplace add ~/Workspace/claude-craft
claude plugin install craft@dipendra
```

Once this is pushed to a repository, anyone can install it with:

```bash
/plugin marketplace add <owner>/<repo>
/plugin install craft@dipendra
```

## Heads up on duplicates

The 13 skills in `plugins/craft/skills/` are copies. The originals still live in
`~/.claude/skills/` and are untouched. Loading this plugin while those originals are in place means
each skill loads twice — once as `/<name>` and once as `/craft:<name>` — which doubles their context
cost and gives the model two near-identical descriptions to choose between.

Use `--plugin-dir` for testing. Before installing it for daily use, move the 13 originals out of
`~/.claude/skills/`.

## Tests

```bash
bash plugins/craft/tests/run.sh
```
