#!/bin/bash
set -uo pipefail

[ "${CLAUDE_CRAFT_RULES:-on}" = "off" ] && exit 0

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty')
[ -n "$cmd" ] || exit 0

deny() {
  printf '%s\n\nThis is a CLAUDE.md craft rule, enforced by the "craft" plugin.\nGenuine exception? Re-run the single command with CLAUDE_CRAFT_RULES=off prefixed, and say why.\n' "$1" >&2
  exit 2
}

has() { printf '%s' "$cmd" | grep -qE -- "$1"; }
hasi() { printf '%s' "$cmd" | grep -qiE -- "$1"; }

check_attribution() {
  has '(git[[:space:]]+commit|gh[[:space:]]+pr[[:space:]]+(create|edit)|git[[:space:]]+tag)' || return 0
  hasi 'co-authored-by:[[:space:]]*claude|generated with[[:space:]]*\[?claude|noreply@anthropic\.com|claude\.com/claude-code|🤖' || return 0
  deny 'Blocked: attribution trailer in a commit or pull request.
Strip every line mentioning Claude, Anthropic, Claude Code, or a generator.
A commit body holds the explanation and Ref: lines and nothing else.'
}

disposable='(^|/)(build|target|dist|out|node_modules|\.gradle|\.next|\.nuxt|\.venv|\.dart_tool|__pycache__|DerivedData|Pods|\.pytest_cache|coverage)(/|$)|^/tmp/|^\$\{?TMPDIR'

check_delete() {
  hasi 'shutil\.rmtree|os\.(remove|unlink)\(|fs\.(rm|unlink|rmSync|unlinkSync)\(|pathlib.*\.unlink\(' \
    && deny 'Blocked: a programmatic delete that bypasses the Trash.
Shell out to trash <path> instead of shutil.rmtree / os.remove / fs.rm.'

  local segment args arg
  while IFS= read -r segment; do
    printf '%s' "$segment" | grep -qE '^[[:space:]]*(sudo[[:space:]]+)?rm([[:space:]]|$)' || continue

    args=$(printf '%s' "$segment" \
      | sed -E 's/^[[:space:]]*(sudo[[:space:]]+)?rm[[:space:]]*//' \
      | tr ' ' '\n' | grep -vE '^-|^$')

    while IFS= read -r arg; do
      [ -n "$arg" ] || continue
      printf '%s' "$arg" | grep -qE "$disposable" && continue
      deny "Blocked: rm on $arg. Use trash instead, so the deletion stays undoable.

  trash <path>          (/usr/bin/trash, takes several paths at once)

Tracked file? git rm --cached <path> && trash <path>.
Only build and cache folders the tool owns may be removed outright, and every
path in the command has to be one of them."
    done <<< "$args"
  done <<< "$(printf '%s' "$cmd" | sed -E 's/(\&\&|\|\||;|\||`)/\'$'\n''/g')"
  return 0
}

check_git() {
  if has 'git[[:space:]]+push' && has '(--force([[:space:]]|$)|[[:space:]]-f([[:space:]]|$))' && ! has '--force-with-lease'; then
    deny 'Blocked: git push --force. Use --force-with-lease so you cannot clobber work you have not seen.'
  fi
  if has 'git[[:space:]]+(clone|remote[[:space:]]+(add|set-url)|submodule[[:space:]]+add)' && has 'git@[a-zA-Z0-9._-]+:'; then
    deny 'Blocked: an SSH git remote. Use HTTPS until you ask otherwise.

  https://github.com/owner/repo

Auth through a credential helper: gh auth git-credential.'
  fi
  if has 'git[[:space:]]+rm([[:space:]]|$)' && ! has '--cached'; then
    deny 'Blocked: plain git rm erases the working copy for good.

  git rm --cached <path> && trash <path>'
  fi
  if has 'git[[:space:]]+worktree[[:space:]]+add'; then
    git -C "${cwd:-.}" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
      || deny 'Blocked: git worktree add outside a git repository. Work in place and say so in one line.'
  fi
  return 0
}

check_sleep() {
  has '(^|[;&|`]|&&|\|\|)[[:space:]]*sleep[[:space:]]+[0-9]' \
    && deny 'Blocked: sleep. Poll for the real signal, or bound the command with a timeout.

  timeout 60 <cmd>

Nothing observable to poll? Re-run with CLAUDE_CRAFT_RULES=off and say so.'
  return 0
}

check_gradle() {
  has 'gradlew|(^|[[:space:]])gradle[[:space:]]' || return 0

  has '--no-parallel|--max-workers|--no-daemon|--parallel|-Dorg\.gradle\.' \
    && deny 'Blocked: a Gradle tuning flag. Use the project default setup; gradle.properties decides the rest.
Add a flag only when a build actually fails from resource pressure, and say which and why.'

  local tasks
  tasks=$(printf '%s' "$cmd" \
    | sed -E 's/.*gradlew//' \
    | sed -E 's/[|>&;].*$//' \
    | tr ' ' '\n' \
    | grep -vE '^-|^$' \
    | grep -cE '^[A-Za-z:]')
  if [ "${tasks:-0}" -gt 1 ]; then
    deny "Blocked: $tasks Gradle tasks in one invocation. This machine throttles when two heavy jobs overlap.
Run them back to back instead:

  ./gradlew assembleDebug
  ./gradlew testDebugUnitTest"
  fi

  if pgrep -f '[g]radlew|[x]codebuild|GradleDaemon.*--build' >/dev/null 2>&1; then
    deny 'Blocked: another build is already running on this machine. One build at a time, machine-wide.
Wait for it to finish, then start this one.'
  fi
  return 0
}

check_attribution
check_delete
check_git
check_sleep
check_gradle
exit 0
