# claude-house-rules

A Claude Code plugin marketplace with one plugin, `house`.

`house` carries Dipendra's authored skills and turns the advisory rules in `~/.claude/CLAUDE.md`
into hooks that block a tool call rather than ask nicely.

## Layout

```
.claude-plugin/marketplace.json   the catalog
plugins/house/                    the plugin — see its own README
```

## Try it without installing

```bash
claude --plugin-dir ./plugins/house
```

## Install it

```bash
claude plugin marketplace add ~/Workspace/claude-house-rules
claude plugin install house@dipendra-tools
```

Once this is pushed to a repository, anyone can install it with:

```bash
/plugin marketplace add <owner>/<repo>
/plugin install house@dipendra-tools
```

## Heads up on duplicates

The 13 skills in `plugins/house/skills/` are copies. The originals still live in
`~/.claude/skills/` and are untouched. Loading this plugin while those originals are in place means
each skill loads twice — once as `/<name>` and once as `/house:<name>` — which doubles their context
cost and gives the model two near-identical descriptions to choose between.

Use `--plugin-dir` for testing. Before installing it for daily use, move the 13 originals out of
`~/.claude/skills/`.

## Tests

```bash
bash plugins/house/tests/run.sh
```
