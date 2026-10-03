#!/bin/bash
set -uo pipefail
source "$(dirname "$0")/lib.sh"

craft_rules_off && exit 0
require_jq
source "$(dirname "$0")/proof-lib.sh"
proof_active || exit 0

GIVE_UP_AFTER=3

if is_git && [ ! -f "$BASELINE" ]; then
  [ -z "$(git -C "$ROOT" status --porcelain -- . ':(exclude).proof')" ] && exit 0
  "$JQ" -n '{decision: "block", reason: "proof: the records for this session are missing (they live in .git/craft-proof and only the hooks write them) while the work tree has changes, so nothing can be proven. Say plainly in your final reply that this work is unverified."}'
  exit 0
fi

snap=$(snapshot)
changed=$(changed_paths "$snap")
delivered=$(touched_deliverables)
reply=$(input_field .last_assistant_message)
contract=$(active_contract)

unverified_note() {
  [ -f "$contract" ] || return 0
  "$JQ" -r '(.unverified // []) | if length > 0 then "Not verified: " + join("; ") else empty end' "$contract" 2>/dev/null
}

if [ -z "$changed" ] && [ -z "$delivered" ]; then
  : > "$GATE_MEMORY"
  exit 0
fi

problems=""
add_problem() {
  problems="$problems- $1
"
}

if ! contract_valid_file "$contract"; then
  add_problem "Work changed but there is no usable contract at $ROOT_PHYSICAL/.proof/contract.json:
$(contract_errors_of "$contract")
$CONTRACT_GUIDE"
else
  lock_contract
  contract=$(active_contract)
  if contract_tampered; then
    add_problem ".proof/contract.json was removed or changed after the lock in a way that is not allowed. The locked contract is being used. Restore it, adding claims only."
  fi

  while IFS=$'\t' read -r expected path; do
    [ -n "$path" ] || continue
    allowed_test_change "$path" && continue
    if [ "$(current_hash_of "$path")" != "$expected" ]; then
      add_problem "$path is read-only during this task (an existing test, a test setting, or a script a check runs) and it was changed or deleted. Restore it and put new tests in new files."
    fi
  done <<< "$(protected_entries | sort -u)"

  if ! states=$(claim_states "$contract" "$snap"); then
    add_problem "The proof records could not be read, so nothing counts as proven. Run every check again."
    states=""
  fi
  while IFS=$'\t' read -r id state check; do
    [ -n "$id" ] || continue
    case "$state" in
      never-run) add_problem "$id has no proof. Run exactly, from the project root: $check" ;;
      failing)   add_problem "$id is failing. Its last run of \`$check\` did not pass. Treat the failure as evidence about the code, not the test (craft-proof:testing-best-practices)." ;;
      stale)     add_problem "$id is stale: code changed after its last passing run. Run again: $check" ;;
      needs-red) add_problem "$id needs red-then-green proof: \`$check\` must be seen failing on the unfixed code and passing after the fix, with the same test files both times. A test that has never failed is unproven (craft-proof:testing-best-practices)." ;;
    esac
  done <<< "$states"

  while IFS= read -r path; do
    [ -n "$path" ] || continue
    add_problem "$path was written in this task but no file, rubric or source claim names it. Add a claim that proves what it must contain."
  done <<< "$(uncovered_deliverables "$contract")"

  tasks=$(session_tasks "$(input_field .session_id)")
  if [ "$(claim_count "$contract")" -ge "$TASKS_NEEDED_AT" ]; then
    task_text=$("$JQ" -r '.[] | "\(.subject)\n\(.description // "")"' <<< "$tasks")
    named=$(claims_named_in "$contract" "$task_text")
    while IFS= read -r id; do
      [ -n "$id" ] || continue
      "$GREP" -Fxq -- "$id" <<< "$named" || add_problem "$id is not named by any todo item. Add one with TaskCreate, with \"$id\" in the subject."
    done <<< "$("$JQ" -r '.claims[].id' "$contract")"
  fi
  while IFS= read -r item; do
    [ -n "$item" ] || continue
    add_problem "Todo item still open: $item. Finish it, or add a line to its description with TaskUpdate: Blocked: <the reason>."
  done <<< "$("$JQ" -r '.[] | select(.status == "pending" or .status == "in_progress") | select((.description // "") | test("(^|\\n)[[:space:]]*blocked:"; "i") | not) | "#\(.id) [\(.status)] \(.subject)"' <<< "$tasks")"

  rubrics=""
  while IFS= read -r claim; do
    [ -n "$claim" ] || continue
    id=$("$JQ" -r '.id' <<< "$claim")
    reason=""
    if "$JQ" -e '.source != null' <<< "$claim" >/dev/null; then
      reason=$(verify_source "$("$JQ" -r '.source.location' <<< "$claim")" "$("$JQ" -r '.source.quote' <<< "$claim")") || add_problem "$id (source): $reason"
    elif "$JQ" -e '.calc != null' <<< "$claim" >/dev/null; then
      reason=$(verify_calc "$("$JQ" -r '.calc.expression' <<< "$claim")" "$("$JQ" -r '.calc.result | tostring' <<< "$claim")") || add_problem "$id (calc): $reason. Recompute it with craft-proof:calculator."
    elif "$JQ" -e '.file != null' <<< "$claim" >/dev/null; then
      reason=$(verify_file "$("$JQ" -r '.file.path' <<< "$claim")" "$("$JQ" -r '.file.contains[]' <<< "$claim")") || add_problem "$id (file): $reason"
    else
      rubrics="$rubrics$claim
"
    fi
  done <<< "$(deliverable_claims "$contract")"

  if [ -z "$problems" ]; then
    while IFS= read -r claim; do
      [ -n "$claim" ] || continue
      id=$("$JQ" -r '.id' <<< "$claim")
      reason=$(verify_rubric "$("$JQ" -r '.rubric.target' <<< "$claim")" "$("$JQ" -r '.rubric.criteria' <<< "$claim")" "$reply") || add_problem "$id (rubric): $reason"
    done <<< "$rubrics"
  fi
fi

unverified=$(unverified_note)

if [ -z "$problems" ]; then
  printf 'proven\n' > "$OUTCOME"
  : > "$GATE_MEMORY"
  total=$("$JQ" -r '.claims | length' "$contract")
  message="proof: all $total claims proven on the final code."
  [ -n "$unverified" ] && message="$message $unverified"
  "$JQ" -n --arg m "$message" '{systemMessage: $m}'
  exit 0
fi

signature=$(sha256 <<< "$problems")
read -r last_signature repeats 2>/dev/null < "$GATE_MEMORY" || { last_signature=""; repeats=0; }
if [ "$last_signature" = "$signature" ]; then repeats=$((repeats + 1)); else repeats=1; fi
printf '%s %s\n' "$signature" "$repeats" > "$GATE_MEMORY"

if [ "$repeats" -ge "$GIVE_UP_AFTER" ]; then
  printf 'unverified\n' > "$OUTCOME"
  "$JQ" -n --arg m "proof: stopping with unproven work after $repeats tries with no progress:
$problems${unverified:+$unverified}" '{systemMessage: $m}'
  exit 0
fi

"$JQ" -n --arg r "proof: you cannot finish yet.
$problems
If something here truly cannot be proven in this session, add it to \"unverified\" in the contract and say so plainly in your final reply." '{decision: "block", reason: $r}'
