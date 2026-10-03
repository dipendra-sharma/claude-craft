#!/bin/bash
set -uo pipefail
source "$(dirname "$0")/lib.sh"

craft_rules_off && exit 0
require_jq
source "$(dirname "$0")/proof-lib.sh"
is_git || exit 0

archive_previous_task() {
  local dest="$STATE/archive/$(date +%Y%m%dT%H%M%S)"
  mkdir -p "$dest"
  for entry in "$STATE"/*; do
    [ "$(basename "$entry")" = archive ] || mv "$entry" "$dest/"
  done
}

exclude_state_from_git() {
  local exclude
  exclude=$(git -C "$ROOT" rev-parse --git-path info/exclude 2>/dev/null) || return 0
  case "$exclude" in /*) ;; *) exclude="$ROOT/$exclude" ;; esac
  mkdir -p "$(dirname "$exclude")"
  "$GREP" -qx '.proof/' "$exclude" 2>/dev/null || printf '.proof/\n' >> "$exclude"
}

session_source=$(input_field .source)
if [ "$session_source" = startup ] && [ -f "$BASELINE" ]; then
  archive_previous_task
fi
mkdir -p "$STATE"
is_git && exclude_state_from_git
if [ ! -f "$BASELINE" ]; then
  snapshot > "$BASELINE"
  save_protected_copies
fi

rules="The craft-proof plugin is active in this project. Before you change code, write a contract. Before you finish, every claim in it must have passing proof on the current code, recorded by hooks when you run its check.
$CONTRACT_GUIDE"

if contract_valid; then
  rules="$rules

Active contract (.proof/contract.json):
$(cat "$CONTRACT")

Claim status (id, state, check):
$(claim_states)"
fi

emit_context SessionStart "$rules"
