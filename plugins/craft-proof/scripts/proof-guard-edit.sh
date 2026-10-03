#!/bin/bash
set -uo pipefail
source "$(dirname "$0")/lib.sh"

craft_rules_off && exit 0
require_jq
source "$(dirname "$0")/proof-lib.sh"
proof_active || exit 0

target=$(input_field '.tool_input.file_path // .tool_input.notebook_path')
[ -n "$target" ] || exit 0
rel=$(rel_path "$target") || exit 0

case "$(lower "$rel")" in
  .proof/contract.json)
    is_locked || exit 0
    candidate="$STATE/candidate.$$"
    proposed_content "$rel" > "$candidate"
    problems=$(contract_errors_of "$candidate"; [ -s "$candidate" ] && "$JQ" -e . "$candidate" >/dev/null 2>&1 && extension_errors "$candidate")
    rm -f "$candidate"
    [ -z "$problems" ] && exit 0
    deny_tool "The contract is locked because a check program has run. You may only add claims or unverified items; existing claims, the goal, the kind and allowed_test_changes stay as they were.
$problems"
    ;;
  .proof/*)
    deny_tool "Only .proof/contract.json may be written under .proof/."
    ;;
esac

is_ignored_path "$rel" && exit 0

new_text=$(input_field '.tool_input.content // .tool_input.new_string // .tool_input.new_source // ([.tool_input.edits[]?.new_string] | join("\n"))')

if { is_test_path "$rel" || is_test_config "$rel"; } && matches "$SKIP_MARKER_RE" "$new_text"; then
  deny_tool "Skipping, focusing or marking a test as expected-to-fail is not allowed. Fix the code, or name the claim as unverified."
fi

if is_protected "$rel" && ! allowed_test_change "$rel"; then
  deny_tool "$rel is an existing test, a test setting, or a script a check runs, so it is read-only. Put new tests in a new file and make the code satisfy the existing ones. If this file truly must change, list it in allowed_test_changes with a reason before any check runs. A failing test is evidence about the code (craft-proof:testing-best-practices)."
fi

if ! contract_valid_file "$(active_contract)"; then
  deny_tool "No valid contract yet, so this edit is blocked. Code changes and deliverables (documents, plans, reports, data files, and any file outside a git repository) need a contract first.
$(contract_errors_of "$(active_contract)")
$CONTRACT_GUIDE"
fi

claims=$(claim_count "$(active_contract)")
if [ -z "$(input_field .agent_id)" ] && [ "$claims" -ge "$TASKS_NEEDED_AT" ] && [ "$(session_tasks "$(input_field .session_id)" | "$JQ" 'length')" = 0 ]; then
  deny_tool "The contract has $claims claims, so break the work into a todo list before editing: one TaskCreate per claim, with the claim id in the subject (for example \"C2: ...\"). If TaskCreate shows only as a deferred name, load it with ToolSearch \"select:TaskCreate,TaskUpdate,TaskList,TaskGet\". Mark an item completed only once its claim is proven; the hooks refuse it otherwise."
fi

exit 0
