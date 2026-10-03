#!/bin/bash
set -uo pipefail
source "$(dirname "$0")/lib.sh"

craft_rules_off && exit 0
require_jq
source "$(dirname "$0")/proof-lib.sh"
proof_active || exit 0

contract=$(active_contract)
contract_valid_file "$contract" || exit 0

text="$(input_field .task_subject)
$(input_field .task_description)"
ids=$(claims_named_in "$contract" "$text")
[ -n "$ids" ] || exit 0

states=$(claim_states "$contract" "$(snapshot)")
reasons=""
while IFS= read -r id; do
  [ -n "$id" ] || continue
  reason=$(claim_problem_now "$contract" "$id" "$states") || reasons="$reasons- $id: $reason
"
done <<< "$ids"
[ -z "$reasons" ] && exit 0

printf 'This todo item cannot be marked completed yet, because a claim it covers is not proven:\n%sRun the claim'"'"'s check, or fix the content, then mark it completed. If it truly cannot be done, leave it open and add a line to its description: Blocked: <the reason>.\n' "$reasons" >&2
exit 2
