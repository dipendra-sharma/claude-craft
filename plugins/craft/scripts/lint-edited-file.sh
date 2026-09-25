#!/bin/bash
set -uo pipefail
source "$(dirname "$0")/lib.sh"

craft_rules_off && exit 0
require_jq

input=$(cat)
file=$(jq -r '.tool_input.file_path // empty' <<< "$input")
[ -f "$file" ] || exit 0
cd "$(jq -r '.cwd // "."' <<< "$input")" 2>/dev/null || exit 0

project_bin() { [ -x "node_modules/.bin/$1" ] && printf '%s' "node_modules/.bin/$1"; }
venv_or_path() { if [ -x ".venv/bin/$1" ]; then printf '%s' ".venv/bin/$1"; else command -v "$1"; fi; }

case "$file" in
  */tsconfig*.json|*/jsconfig*.json|*/.vscode/*.json) ;;
  *.json) set -- jq empty "$file" ;;
  *.py) tool=$(venv_or_path ruff) && set -- "$tool" check --quiet "$file" ;;
  *.js|*.jsx|*.ts|*.tsx|*.mjs|*.cjs|*.vue|*.svelte)
    if tool=$(project_bin biome); then set -- "$tool" lint "$file"
    elif tool=$(project_bin eslint); then set -- "$tool" "$file"
    fi ;;
  *.sh|*.bash) tool=$(command -v shellcheck) && set -- "$tool" "$file" ;;
  *.go) tool=$(command -v go) && set -- "$tool" -C "$(dirname "$file")" vet . ;;
  *.dart) tool=$(command -v dart) && set -- "$tool" analyze "$file" ;;
  *.kt|*.kts) tool=$(command -v ktlint) && set -- "$tool" "$file" ;;
  *.swift) tool=$(command -v swiftlint) && set -- "$tool" lint --quiet "$file" ;;
  *.rb) tool=$(command -v rubocop) && set -- "$tool" "$file" ;;
esac
[ $# -gt 0 ] || exit 0

output=$("$@" 2>&1) && exit 0
jq -n --arg reason "$(printf '%s found problems in %s:\n\n%s' "${1##*/}" "${file##*/}" "$(head -n 30 <<< "$output")")" \
  '{decision: "block", reason: $reason}'
