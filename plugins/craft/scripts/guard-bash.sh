#!/bin/bash
set -uo pipefail
source "$(dirname "$0")/lib.sh"

craft_rules_off && exit 0
require_jq

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty')
[ -n "$cmd" ] || exit 0

[[ "$cmd" =~ ^[[:space:]]*CLAUDE_CRAFT_RULES=off[[:space:]] ]] && exit 0

deny() {
  printf '%s\n\nThis is a CLAUDE.md craft rule, enforced by the "craft" plugin.\nGenuine exception? Say why, then re-run the single command with CLAUDE_CRAFT_RULES=off as its first word.\n' "$1" >&2
  exit 2
}

disposable='(^|/)(build|target|dist|out|node_modules|\.gradle|\.next|\.nuxt|\.venv|\.dart_tool|__pycache__|DerivedData|Pods|\.pytest_cache|coverage)(/|$)|^/tmp/.|^/private/tmp/.|^/var/folders/.|^\$\{?TMPDIR\}?/.'
attribution='co-authored-by:[[:space:]]*claude|generated with[[:space:]]*\[?claude|noreply@anthropic\.com|claude\.com/claude-code|🤖'
ssh_remote='^(git@|ssh://|git\+ssh://|[A-Za-z0-9._-]+@[A-Za-z0-9._-]+:)'

is_disposable() {
  [[ "$1" =~ (^|/)\.\.(/|$) ]] && return 1
  [[ "$1" =~ $disposable ]]
}

deny_delete() {
  deny "Blocked: $1. Use trash instead, so the deletion stays undoable.

  trash <path>          (/usr/bin/trash, takes several paths at once)

Tracked file? git rm --cached <path> && trash <path>.
Only build and cache folders the tool owns may be removed outright, and every
path in the command has to be one of them."
}

resolve_path() {
  case "$1" in
    /*) printf '%s' "$1" ;;
    *) printf '%s/%s' "${cwd:-.}" "$1" ;;
  esac
}

check_programmatic_delete() {
  printf '%s' "$cmd" | grep -qiE 'shutil\.rmtree|os\.(remove|unlink|rmdir)\(|fs\.(rm|unlink|rmSync|unlinkSync)\(|pathlib.*\.unlink\(' \
    && deny 'Blocked: a programmatic delete that bypasses the Trash.
Shell out to trash <path> instead of shutil.rmtree / os.remove / fs.rm.'
  return 0
}

check_rm() {
  [ "$VIA_XARGS" = 1 ] && deny_delete "$CMD through xargs, where the paths are not visible"
  local arg options_done=0
  for arg in ${ARGS[@]+"${ARGS[@]}"}; do
    if [ "$options_done" = 0 ]; then
      [ "$arg" = "--" ] && { options_done=1; continue; }
      [[ "$arg" == -* ]] && continue
    fi
    is_disposable "$arg" || deny_delete "$CMD on $arg"
  done
  return 0
}

check_find() {
  local arg deletes=0 prev=""
  for arg in ${ARGS[@]+"${ARGS[@]}"}; do
    [ "$arg" = "-delete" ] && deletes=1
    case "$prev" in -exec|-execdir|-ok|-okdir)
      case "${arg##*/}" in rm|unlink) deletes=1 ;; esac ;;
    esac
    prev=$arg
  done
  [ "$deletes" = 1 ] || return 0

  local roots=0
  for arg in ${ARGS[@]+"${ARGS[@]}"}; do
    case "$arg" in -*|'('|'!') break ;; esac
    roots=$((roots + 1))
    is_disposable "$arg" || deny_delete "find deleting under $arg"
  done
  [ "$roots" -gt 0 ] || deny_delete "find deleting under the current folder"
  return 0
}

message_files() {
  local prev="" arg
  for arg in ${ARGS[@]+"${ARGS[@]}"}; do
    case "$prev" in -F|--file|--body-file|--notes-file) [ "$arg" != "-" ] && printf '%s\n' "$arg" ;; esac
    case "$arg" in --file=*|--body-file=*|--notes-file=*) printf '%s\n' "${arg#*=}" ;; esac
    prev=$arg
  done
}

check_attribution() {
  local deny_text='Blocked: attribution in a commit, tag, or pull request.
Strip every line mentioning Claude, Anthropic, Claude Code, or a generator.
A commit body holds the explanation and Ref: lines and nothing else.'
  printf '%s' "$cmd" | grep -qiE "$attribution" && deny "$deny_text"
  local file path
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    path=$(resolve_path "$file")
    [ -f "$path" ] && grep -qiE "$attribution" "$path" && deny "$deny_text

Found in $file."
  done <<< "$(message_files)"
  return 0
}

check_git() {
  local sub
  while [ "${#ARGS[@]}" -gt 0 ]; do
    case "${ARGS[0]}" in
      -C|-c|--git-dir|--work-tree|--namespace) drop_args 2 ;;
      -*) drop_args 1 ;;
      *) break ;;
    esac
  done
  [ "${#ARGS[@]}" -gt 0 ] || return 0
  sub=${ARGS[0]}
  drop_args 1

  local arg
  case "$sub" in
    push)
      for arg in ${ARGS[@]+"${ARGS[@]}"}; do
        if [ "$arg" = "--force" ] || [[ "$arg" =~ ^-[A-Za-z]*f[A-Za-z]*$ ]] || [[ "$arg" == +* ]]; then
          deny 'Blocked: a forced git push. Use --force-with-lease so you cannot clobber work you have not seen.'
        fi
      done ;;
    clone|remote|submodule)
      for arg in ${ARGS[@]+"${ARGS[@]}"}; do
        [[ "$arg" =~ $ssh_remote ]] && deny 'Blocked: an SSH git remote. Use HTTPS until you ask otherwise.

  https://github.com/owner/repo

Auth through a credential helper: gh auth git-credential.'
      done ;;
    rm)
      case " ${ARGS[*]-} " in *" --cached "*|*" -n "*|*" --dry-run "*) ;; *)
        deny 'Blocked: plain git rm erases the working copy for good.

  git rm --cached <path> && trash <path>' ;;
      esac ;;
    clean)
      case " ${ARGS[*]-} " in *" -n "*|*" --dry-run "*) return 0 ;; esac
      for arg in ${ARGS[@]+"${ARGS[@]}"}; do
        if [ "$arg" = "--force" ] || [[ "$arg" =~ ^-[A-Za-z]*f[A-Za-z]*$ ]]; then
          deny_delete 'git clean, which deletes untracked files for good. List them with git clean -n, then trash them'
        fi
      done ;;
    worktree)
      [ "${ARGS[0]:-}" = add ] || return 0
      git -C "${cwd:-.}" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
        || deny 'Blocked: git worktree add outside a git repository. Work in place and say so in one line.' ;;
    commit|tag)
      check_attribution ;;
  esac
  return 0
}

check_gh() {
  local group="${ARGS[0]:-}" action="${ARGS[1]:-}"
  case "$group $action" in
    "pr create"|"pr edit"|"pr comment"|"pr review"|"issue create"|"issue edit"|"issue comment"|"release create"|"release edit")
      check_attribution ;;
  esac
  return 0
}

deny_manifest_write() {
  local target="$1" base
  base=${target##*/}
  case "$(manifest_kind "$base")" in
    lock|cli)
      deny "Blocked: writing $base from the shell.

$(manifest_hint "$base" "$(dirname "$(resolve_path "$target")")")

For a change the CLI cannot make, use the Edit tool: it allows edits outside the
dependency sections. A lockfile is only ever written by its package manager." ;;
  esac
}

check_manifest_writes() {
  local target arg
  for target in ${OUTS[@]+"${OUTS[@]}"}; do
    deny_manifest_write "$target"
  done
  case "$CMD" in
    tee)
      for arg in ${ARGS[@]+"${ARGS[@]}"}; do [[ "$arg" == -* ]] || deny_manifest_write "$arg"; done ;;
    sed|gsed|perl)
      local in_place=0
      for arg in ${ARGS[@]+"${ARGS[@]}"}; do
        [[ "$arg" =~ ^-[A-Za-z]*i|^--in-place ]] && in_place=1
      done
      [ "$in_place" = 1 ] || return 0
      for arg in ${ARGS[@]+"${ARGS[@]}"}; do [[ "$arg" == -* ]] || deny_manifest_write "$arg"; done ;;
    cp|mv|install)
      [ "${#ARGS[@]}" -gt 0 ] && deny_manifest_write "${ARGS[${#ARGS[@]}-1]}" ;;
  esac
  return 0
}

gradle_value_options=' -p --project-dir -b --build-file -c --settings-file -x --exclude-task -I --init-script -g --gradle-user-home --console --warning-mode --priority --tests --include-build --project-cache-dir -M --write-verification-metadata -F --dependency-verification --configuration --dependency '

check_gradle() {
  local arg skip=0 tasks=0
  for arg in ${ARGS[@]+"${ARGS[@]}"}; do
    case "$arg" in --no-parallel|--parallel|--no-daemon|--max-workers*|-Dorg.gradle.*)
      deny 'Blocked: a Gradle tuning flag. Use the project default setup; gradle.properties decides the rest.
Add a flag only when a build actually fails from resource pressure, and say which and why.' ;;
    esac
  done
  for arg in ${ARGS[@]+"${ARGS[@]}"}; do
    if [ "$skip" = 1 ]; then skip=0; continue; fi
    if [[ "$arg" == -* ]]; then
      case "$gradle_value_options" in *" $arg "*) skip=1 ;; esac
      continue
    fi
    tasks=$((tasks + 1))
  done
  if [ "$tasks" -gt 1 ]; then
    deny "Blocked: $tasks Gradle tasks in one invocation. This machine throttles when two heavy jobs overlap.
Run them back to back instead:

  ./gradlew assembleDebug
  ./gradlew testDebugUnitTest"
  fi
  check_build_running
}

process_list() {
  if [ -n "${CRAFT_PROCESS_LIST_FILE:-}" ]; then cat "$CRAFT_PROCESS_LIST_FILE"; else ps -Ao command= 2>/dev/null; fi
}

check_build_running() {
  process_list | grep -qE -- '-Dorg\.gradle\.appname=gradlew?( |$)|gradle-wrapper\.jar|org\.gradle\.wrapper\.GradleWrapperMain|org\.gradle\.launcher\.GradleMain|^[^ ]*xcodebuild( |$)|^[^ ]*cargo (build|test|check|clippy|bench)( |$)' \
    && deny 'Blocked: another build is already running on this machine. One build at a time, machine-wide.
Wait for it to finish, then start this one.'
  return 0
}

check_segment() {
  parse_segment "$1"
  [ -n "$CMD" ] || return 0
  check_manifest_writes
  case "$CMD" in
    rm|unlink) check_rm ;;
    find) check_find ;;
    git) check_git ;;
    gh) check_gh ;;
    sleep) deny 'Blocked: sleep. Poll for the real signal, or bound the command with a timeout.

  timeout 60 <cmd>

Nothing observable to poll? Say so, then re-run with CLAUDE_CRAFT_RULES=off as the first word.' ;;
    gradlew|gradle) check_gradle ;;
    xcodebuild) check_build_running ;;
    cargo) case "${ARGS[0]:-}" in build|test|check|clippy|bench) check_build_running ;; esac ;;
    bash|sh|zsh|dash) check_nested_shell ;;
    eval) check_command "${ARGS[*]-}" ;;
  esac
  return 0
}

check_nested_shell() {
  local i
  for ((i = 0; i < ${#ARGS[@]}; i++)); do
    if [[ "${ARGS[$i]}" =~ ^-[A-Za-z]*c[A-Za-z]*$ ]]; then
      check_command "${ARGS[$((i + 1))]:-}"
      return 0
    fi
  done
}

check_command() {
  local segment
  while IFS= read -r segment <&3; do
    check_segment "$segment"
  done 3<<< "$(printf '%s' "$1" | shell_segments)"
}

check_programmatic_delete
check_command "$cmd"
exit 0
