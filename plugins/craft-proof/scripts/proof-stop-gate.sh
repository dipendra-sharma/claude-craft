#!/bin/bash
set -uo pipefail
source "$(dirname "$0")/lib.sh"

craft_rules_off && exit 0
require_jq
source "$(dirname "$0")/proof-lib.sh"
is_git || exit 0

[ -f "$BASELINE" ] || exit 0

changed=$(changed_files)
[ -n "$changed" ] || exit 0

code_changed=$(printf '%s\n' "$changed" | "$GREP" -Ev "$DOC_PATH_RE" || true)
[ -n "$code_changed" ] || exit 0

problems=""
add_problem() {
  problems="$problems- $1
"
}

contract_problems=$(contract_errors)
if [ -n "$contract_problems" ]; then
  add_problem "Code changed but there is no usable contract:
$contract_problems
$CONTRACT_GUIDE"
else
  if [ -f "$LOCK" ] && [ "$(cat "$LOCK")" != "$(file_hash "$CONTRACT")" ]; then
    add_problem "The contract changed after it was locked. Restore the original claims; changing them after seeing results is not allowed."
  fi

  while IFS= read -r protected; do
    [ -n "$protected" ] || continue
    allowed_test_change "$protected" && continue
    if drops_original_lines "$protected" "$ROOT/$protected"; then
      add_problem "$protected is an existing test and some of its original lines were changed or removed. Restore them and make the code satisfy them; adding new tests is fine."
    fi
  done <<< "$(protected_files)"

  while IFS=$'\t' read -r id state check; do
    [ -n "$id" ] || continue
    case "$state" in
      never-run) add_problem "$id has no proof. Run exactly: $check" ;;
      failing)   add_problem "$id is failing. Its last run of \`$check\` did not pass. Treat the failure as evidence about the code, not the test (craft-proof:testing-best-practices)." ;;
      stale)     add_problem "$id is stale: code changed after its last passing run. Run again: $check" ;;
      needs-red) add_problem "$id needs red-then-green proof: \`$check\` has never been seen failing. Show it failing without the fix, then passing with it. A test that has never failed is unproven (craft-proof:testing-best-practices)." ;;
    esac
  done <<< "$(claim_states)"

  unverified_count=$("$JQ" -r '(.unverified // []) | length' "$CONTRACT")
  final_message=$(input_field .last_assistant_message)
  if [ "$unverified_count" -gt 0 ] && ! "$GREP" -Eiq "unverified|not verified|could not verify|couldn.t verify|cannot verify|can.t verify|not tested|untested|could not test|couldn.t test|cannot test|can.t test|was not run|wasn.t run|not run in" <<< "$final_message"; then
    add_problem "The contract lists unverified items, but your final reply does not say so. Name each unverified item in your final reply: $("$JQ" -r '(.unverified // []) | join("; ")' "$CONTRACT")"
  fi
fi

if [ -z "$problems" ]; then
  printf 'proven\n' > "$OUTCOME"
  : > "$GATE_MEMORY"
  exit 0
fi

signature=$(printf '%s' "$problems" | shasum -a 256 | cut -d' ' -f1)
if [ "$(input_field .stop_hook_active)" = true ] && [ "$(cat "$GATE_MEMORY" 2>/dev/null)" = "$signature" ]; then
  printf 'unverified\n' > "$OUTCOME"
  "$JQ" -n --arg m "proof: stopping with unproven work. Nothing changed since the last block:
$problems" '{systemMessage: $m}'
  exit 0
fi

printf '%s' "$signature" > "$GATE_MEMORY"
"$JQ" -n --arg r "proof: you cannot finish yet.
$problems
If something here truly cannot be proven in this session, say so plainly in your final reply instead of claiming it is done." '{decision: "block", reason: $r}'
