#!/bin/bash
set -uo pipefail
source "$(dirname "$0")/lib.sh"

craft_rules_off && exit 0
require_jq

input=$(cat)
cmd=$(jq -r '.tool_input.command // empty' <<< "$input")
cwd=$(jq -r '.cwd // "."' <<< "$input")
[[ "$cmd" =~ ^[[:space:]]*CLAUDE_CRAFT_RULES=off[[:space:]] ]] && exit 0

types='feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert'
branch_re="^($types)/[a-z0-9]+(-[a-z0-9]+)*$"
subject_re="^($types)(\([a-z0-9][a-z0-9._/-]*\))?!?: [^[:space:]]"
generated_re='^(Merge |Revert "|fixup! |squash! |amend! )'
git_prefix='git([[:space:]]+-C[[:space:]]+[^[:space:]]+)?[[:space:]]+'
name_chars='[^[:space:];|&]+'

deny() {
  printf 'Blocked: %s\n\nTypes: %s.\nGenuine exception? Say why, then re-run with CLAUDE_CRAFT_RULES=off as the first word.\n' "$1" "${types//|/, }" >&2
  exit 2
}

check_branch() {
  [[ ${#1} -le 50 && "$1" =~ $branch_re ]] && return 0
  deny "branch name \"$1\". Use <type>/<scope>-<description>: lowercase, hyphenated, 50 characters at most.
Example: feat/auth-refresh-token"
}

check_subject() {
  [ -n "$2" ] || return 0
  [[ "$2" =~ $generated_re || "$2" =~ $subject_re ]] && return 0
  deny "$1 \"$2\". Use <type>(<scope>): <description>.
Example: fix(auth): refresh the token before it expires"
}

flag_value() {
  if [[ "$1" =~ (^|[[:space:]])($2)[[:space:]=]+\"([^\"]*) ]] || [[ "$1" =~ (^|[[:space:]])($2)[[:space:]=]+\'([^\']*) ]] \
    || [[ "$1" =~ (^|[[:space:]])($2)[[:space:]=]+([^[:space:]\"\';|&]+) ]]; then
    printf '%s' "${BASH_REMATCH[3]}"
  fi
}

heredoc_first_line() { awk 'found && NF { sub(/^[ \t]+/, ""); print; exit } /<</ { found = 1 }' <<< "$1"; }

if [[ "$cmd" =~ ${git_prefix}(checkout|switch)[[:space:]]+(.*[[:space:]])?(-[bBcC]|--create|--orphan)[[:space:]=]+($name_chars) ]]; then
  check_branch "${BASH_REMATCH[5]}"
fi
if [[ "$cmd" =~ ${git_prefix}branch[[:space:]]+(-[mM][[:space:]]+([^-][^[:space:];|&]*[[:space:]]+)?)?([^-[:space:];|&][^[:space:];|&]*) ]]; then
  check_branch "${BASH_REMATCH[4]}"
fi

if [[ "$cmd" =~ ${git_prefix}commit([[:space:]].*)?$ ]]; then
  rest=${BASH_REMATCH[2]}
  file=$(flag_value "$rest" '-[a-zA-Z]*F|--file')
  if [[ "$rest" == *"<<"* ]]; then subject=$(heredoc_first_line "$rest")
  elif [ -n "$file" ] && [ "$file" != "-" ]; then
    case "$file" in /*) ;; *) file="$cwd/$file" ;; esac
    subject=$(head -n 1 "$file" 2>/dev/null)
  else subject=$(flag_value "$rest" '-[a-zA-Z]*m|--message' | head -n 1)
  fi
  check_subject "commit subject" "$subject"
fi

if [[ "$cmd" =~ gh[[:space:]]+pr[[:space:]]+(create|edit)([[:space:]].*)?$ ]]; then
  check_subject "pull request title" "$(flag_value "${BASH_REMATCH[2]}" '-t|--title')"
fi
exit 0
