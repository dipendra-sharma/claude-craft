# Splitting and extracting: the commands

Read this when you reach Step 6, or when you need to park drive-by work.

Everything below assumes you are on the feature branch with the shrunken change,
and that `BASE` is the merge base (`git merge-base main HEAD`). Work on a copy
first — `git branch backup/<name>` — so a bad rebase costs nothing.

## Park drive-by work without losing it

The unrelated bug fix or rename you found in Step 3 goes somewhere it can be
merged on its own.

```bash
git stash push -- <paths>                 # if it is whole files
git checkout -b fix/<scope>-<description> BASE
git stash pop
git commit -am "fix(<scope>): <description>"
git checkout -                            # back to the feature branch
```

For a fix tangled inside a file you are otherwise keeping, split by hunk:

```bash
git checkout -b fix/<scope>-<description> BASE
git checkout <feature-branch> -- <file>
git reset <file>                          # unstage, keep the working copy
git add -p <file>                         # stage only the drive-by hunks
git checkout -- <file>                    # discard the rest
git commit -m "fix(<scope>): <description>"
```

Then remove those same hunks from the feature branch (`git checkout -p BASE -- <file>`)
so the work exists in exactly one place.

## Carve one branch into a stack

Best when the final state is right and only the history needs shaping.

```bash
git checkout -b stack/1-<name> BASE
git checkout <feature-branch> -- .        # bring the whole final state in
git reset                                 # unstage everything, working tree intact
git add -p                                # stage only what belongs in commit 1
git stash push --keep-index               # park the rest
<run the checks>                          # commit 1 must stand alone
git commit -m "<type>(<scope>): <subject>"
git stash pop
```

Repeat `git add -p` → check → commit for each layer. Verify at every step, not
at the end: a commit that does not build on its own defeats the whole point of
stacking, and you only find that out by actually running the build there.

`git add -p` splits with `s`, edits a hunk with `e`. When a single hunk contains
both layers and `s` will not split it further, `e` and delete the lines that
belong to the later commit — they come back when you `git stash pop`.

## Reorder or split existing commits

When the branch already has sensible commits in the wrong order or granularity:

```bash
git rebase -i BASE
```

- reorder lines to change commit order
- `edit` a commit, then `git reset HEAD^` and re-stage in pieces to split it
- `fixup` to fold a "fix typo from earlier commit" into where it belongs

## Check the stack before you open PRs

Each commit must build and pass on its own — assert it rather than assume it:

```bash
git rebase BASE --exec "<test-command>"
```

That runs the command at every commit and stops at the first failure.

Confirm the stack is behavior-identical to where you started:

```bash
git diff <original-branch> HEAD           # should be empty, or only your cuts
```

## Opening the PRs

Each PR targets the one below it, so reviewers see only that layer's diff:

```bash
gh pr create --base main            --head stack/1-<name> --title "<type>(<scope>): <subject>"
gh pr create --base stack/1-<name>  --head stack/2-<name> --title "<type>(<scope>): <subject>"
```

Say in each description which PR it depends on and that it merges in order.
Retarget the later ones to `main` as the earlier ones land (`gh pr edit <n> --base main`).
