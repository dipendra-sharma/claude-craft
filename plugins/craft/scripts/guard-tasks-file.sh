#!/bin/bash
set -uo pipefail
source "$(dirname "$0")/lib.sh"

craft_rules_off && exit 0
require_jq

input=$(cat)
cmd=$(jq -r '.tool_input.command // empty' <<< "$input")
cwd=$(jq -r '.cwd // "."' <<< "$input")
[[ "$cmd" =~ ^[[:space:]]*CLAUDE_CRAFT_RULES=off[[:space:]] ]] && exit 0

git_prefix='^[[:space:]]*git([[:space:]]+-C[[:space:]]+([^[:space:]]+))?[[:space:]]+'
tasks_file_re="(^|/|')TASKS\.md'?$"

deny() {
  printf 'Blocked: this would %s TASKS.md. It is a working file and is never committed.\n\nStage paths by name instead of -A or ., and unstage it if needed: git restore --staged TASKS.md\nTo keep git from offering it again: echo TASKS.md >> .git/info/exclude\n' "$1" >&2
  exit 2
}

repo_of() {
  case "$1" in
    "") printf '%s' "$cwd" ;;
    /*) printf '%s' "$1" ;;
    *) printf '%s/%s' "$cwd" "$1" ;;
  esac
}

segments=${cmd//&&/$'\n'}
segments=${segments//||/$'\n'}
segments=${segments//;/$'\n'}

while IFS= read -r segment; do
  if [[ "$segment" =~ ${git_prefix}add[[:space:]]+(.*)$ ]]; then
    repo=$(repo_of "${BASH_REMATCH[2]}")
    read -ra add_args <<< "${BASH_REMATCH[3]}"
    would_add=$(git -C "$repo" add --dry-run "${add_args[@]}" 2>/dev/null)
    grep -qE "$tasks_file_re" <<< "$would_add" && deny "stage"
  elif [[ "$segment" =~ ${git_prefix}commit([[:space:]].*)?$ ]]; then
    repo=$(repo_of "${BASH_REMATCH[2]}")
    git -C "$repo" diff --cached --name-only 2>/dev/null | grep -qE "$tasks_file_re" && deny "commit"
    if [[ "${BASH_REMATCH[3]}" =~ (^|[[:space:]])(-[a-zA-Z]*a[a-zA-Z]*|--all)([[:space:]]|$) ]]; then
      git -C "$repo" diff --name-only 2>/dev/null | grep -qE "$tasks_file_re" && deny "commit"
    fi
  fi
done <<< "$segments"
exit 0
